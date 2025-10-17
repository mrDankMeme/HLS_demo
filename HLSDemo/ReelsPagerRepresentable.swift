import SwiftUI
import UIKit
import AVKit
import AVFoundation

// MARK: - Snapping (центр)
final class SnappingFlowLayout: UICollectionViewFlowLayout {
    override func targetContentOffset(forProposedContentOffset proposed: CGPoint,
                                      withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let cv = collectionView else { return proposed }
        let midY = proposed.y + cv.bounds.height/2
        let rect = CGRect(x: 0, y: proposed.y, width: cv.bounds.width, height: cv.bounds.height)
        guard let attrs = layoutAttributesForElements(in: rect) else { return proposed }

        var closest: UICollectionViewLayoutAttributes?
        var minDist = CGFloat.greatestFiniteMagnitude
        for a in attrs where a.representedElementCategory == .cell {
            let d = abs(a.center.y - midY)
            if d < minDist { minDist = d; closest = a }
        }
        guard let target = closest else { return proposed }
        return CGPoint(x: proposed.x, y: target.center.y - cv.bounds.height/2)
    }
}

// MARK: - Cell
final class ReelCell: UICollectionViewCell {
    static let reuseID = "ReelCell"
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.clipsToBounds = true
        contentView.layer.cornerRadius = 16
        contentView.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        contentView.layer.borderColor = UIColor(white: 1, alpha: 0.08).cgColor
        contentView.layer.borderWidth = 1

        titleLabel.textColor = .white
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOpacity = 0.65
        titleLabel.layer.shadowRadius = 3

        contentView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String) { titleLabel.text = title }
}

// MARK: - VC
final class ReelsPagerViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private let layout = SnappingFlowLayout()
    private var collectionView: UICollectionView!
    private var items: [VideoRecommendation] = []
    private var activeID: Int?
    private var currentCenteredIndex: Int?
    private var didSetInitial = false
    private var lastItemsSignature: String?

    var onActiveIndexChanged: ((Int) -> Void)?
    var sharedPlayer: AVPlayer!

    /// Текущий контроллер, «приклеенный» к активной ячейке
    private weak var currentHostCell: ReelCell?
    private var currentPlayerVC: AVPlayerViewController?

    private let hPad: CGFloat = 24
    private let vPad: CGFloat = 24

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemYellow

        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 16
        layout.sectionInset = .init(top: vPad, left: hPad, bottom: vPad, right: hPad)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemYellow
        collectionView.decelerationRate = .fast
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(ReelCell.self, forCellWithReuseIdentifier: ReelCell.reuseID)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isPrefetchingEnabled = false

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layout.itemSize = CGSize(width: view.bounds.width - 2*hPad,
                                 height: view.bounds.height - 2*vPad)
        if let host = currentHostCell { currentPlayerVC?.view.frame = host.contentView.bounds }
    }

    // MARK: API из Representable

    func setItems(_ newItems: [VideoRecommendation]) {
        let sig = newItems.map { "\($0.video_id)" }.joined(separator: ",")
        guard sig != lastItemsSignature else { return }
        lastItemsSignature = sig

        items = newItems
        collectionView.reloadData()

        guard !items.isEmpty else { return }
        if !didSetInitial {
            didSetInitial = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.scrollTo(index: 0, animated: false)
                self.collectionView.layoutIfNeeded()
                if let cell = self.collectionView.cellForItem(at: IndexPath(item: 0, section: 0)) as? ReelCell {
                    self.attachPlayerVC(to: cell)
                }
                self.notifyActive(index: 0)
            }
        }
    }

    func setActiveVideoID(_ id: Int?) {
        activeID = id
        guard let id else { return }
        // пытаемся приклеить к текущей центр-ячейке (если видима)
        if let cell = visibleCell(forVideoID: id) {
            attachPlayerVC(to: cell)
        }
    }

    // MARK: DataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ReelCell.reuseID, for: indexPath) as! ReelCell
        cell.configure(title: items[indexPath.item].title)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard indexPath.item < items.count else { return }
        if items[indexPath.item].video_id == activeID, let rc = cell as? ReelCell {
            attachPlayerVC(to: rc)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if currentHostCell === (cell as? ReelCell) { detachPlayerVC() }
    }

    // MARK: Снап + активация

    func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                   withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard !items.isEmpty else { return }
        let midY = scrollView.contentOffset.y + scrollView.bounds.height/2
        let visible = collectionView.indexPathsForVisibleItems
        let currentIndex: Int = {
            let t = visible.min {
                let f1 = collectionView.layoutAttributesForItem(at: $0)?.frame ?? .zero
                let f2 = collectionView.layoutAttributesForItem(at: $1)?.frame ?? .zero
                return abs(f1.midY - midY) < abs(f2.midY - midY)
            }
            return t?.item ?? 0
        }()

        var targetIndex = currentIndex
        let threshold: CGFloat = 8

        if abs(velocity.y) > 0.08 {
            targetIndex = currentIndex + (velocity.y > 0 ? 1 : -1)
        } else if let frame = collectionView.layoutAttributesForItem(at: IndexPath(item: currentIndex, section: 0))?.frame {
            let delta = frame.midY - midY
            if      delta < -threshold { targetIndex = min(currentIndex + 1, items.count - 1) }
            else if delta >  threshold { targetIndex = max(currentIndex - 1, 0) }
        }

        targetIndex = max(0, min(items.count - 1, targetIndex))
        if let attr = collectionView.layoutAttributesForItem(at: IndexPath(item: targetIndex, section: 0)) {
            targetContentOffset.pointee.y = attr.center.y - scrollView.bounds.height/2
            notifyActive(index: targetIndex)
            if let cell = collectionView.cellForItem(at: IndexPath(item: targetIndex, section: 0)) as? ReelCell {
                attachPlayerVC(to: cell)
            }
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) { updateActiveIfNeeded(force: false) }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { updateActiveIfNeeded(force: true) }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { updateActiveIfNeeded(force: true) }
    }

    private func updateActiveIfNeeded(force: Bool) {
        guard !items.isEmpty else { return }
        let center = CGPoint(x: collectionView.bounds.midX,
                             y: collectionView.contentOffset.y + collectionView.bounds.midY)
        let idx: Int? = {
            if let ip = collectionView.indexPathForItem(at: center) { return ip.item }
            let vis = collectionView.indexPathsForVisibleItems
            let t = vis.min {
                let f1 = collectionView.layoutAttributesForItem(at: $0)?.frame ?? .zero
                let f2 = collectionView.layoutAttributesForItem(at: $1)?.frame ?? .zero
                return abs(f1.midY - center.y) < abs(f2.midY - center.y)
            }
            return t?.item
        }()
        guard let index = idx else { return }
        if force || currentCenteredIndex != index {
            currentCenteredIndex = index
            notifyActive(index: index)
            if let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? ReelCell {
                attachPlayerVC(to: cell)
            }
        }
    }

    private func notifyActive(index: Int) { onActiveIndexChanged?(index) }
    private func scrollTo(index: Int, animated: Bool) {
        collectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredVertically, animated: animated)
    }

    // MARK: Работа с player VC

    private func attachPlayerVC(to cell: ReelCell) {
        guard currentHostCell !== cell else { return }
        detachPlayerVC()

        let vc = AVPlayerViewController()
        vc.player = sharedPlayer
        vc.showsPlaybackControls = true
        vc.videoGravity = .resizeAspectFill
        vc.allowsPictureInPicturePlayback = true
        vc.canStartPictureInPictureAutomaticallyFromInline = true
        vc.updatesNowPlayingInfoCenter = false

        addChild(vc)
        vc.view.frame = cell.contentView.bounds
        vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        cell.contentView.insertSubview(vc.view, at: 0) // под заголовок
        vc.didMove(toParent: self)

        currentPlayerVC = vc
        currentHostCell = cell

        // гарантируем сразу видимую картинку
        sharedPlayer.playImmediately(atRate: 1.0)
        vc.view.setNeedsLayout()
        vc.view.layoutIfNeeded()
    }

    private func detachPlayerVC() {
        guard let vc = currentPlayerVC else { return }
        vc.willMove(toParent: nil)
        vc.view.removeFromSuperview()
        vc.removeFromParent()
        currentPlayerVC = nil
        currentHostCell = nil
    }

    private func visibleCell(forVideoID id: Int) -> ReelCell? {
        for c in collectionView.visibleCells {
            guard let idx = collectionView.indexPath(for: c)?.item else { continue }
            if items[idx].video_id == id { return c as? ReelCell }
        }
        return nil
    }
}

// MARK: - SwiftUI wrapper
struct ReelsPagerRepresentable: UIViewControllerRepresentable {
    let items: [VideoRecommendation]
    let activeID: Int?
    let player: AVPlayer
    let onActiveIndexChanged: (Int) -> Void

    func makeUIViewController(context: Context) -> ReelsPagerViewController {
        let vc = ReelsPagerViewController()
        vc.sharedPlayer = player
        vc.onActiveIndexChanged = onActiveIndexChanged
        return vc
    }

    func updateUIViewController(_ ui: ReelsPagerViewController, context: Context) {
        ui.sharedPlayer = player
        ui.setItems(items)
        ui.setActiveVideoID(activeID)
    }
}
