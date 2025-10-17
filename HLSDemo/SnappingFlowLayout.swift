import SwiftUI
import UIKit
import AVFoundation

// MARK: - Snapping FlowLayout (центрирование элемента)
final class SnappingFlowLayout: UICollectionViewFlowLayout {
    override func targetContentOffset(forProposedContentOffset proposed: CGPoint,
                                      withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let cv = collectionView else { return super.targetContentOffset(forProposedContentOffset: proposed) }
        let bounds = cv.bounds
        let midY   = proposed.y + bounds.size.height / 2.0

        guard let attrs = layoutAttributesForElements(in: CGRect(x: 0, y: proposed.y, width: bounds.width, height: bounds.height))
        else { return super.targetContentOffset(forProposedContentOffset: proposed) }

        var closest: UICollectionViewLayoutAttributes?
        var minDist = CGFloat.greatestFiniteMagnitude
        for a in attrs where a.representedElementCategory == .cell {
            let dist = abs(a.center.y - midY)
            if dist < minDist {
                minDist = dist
                closest = a
            }
        }
        guard let target = closest else { return super.targetContentOffset(forProposedContentOffset: proposed) }
        let newOffsetY = target.center.y - bounds.size.height / 2.0
        return CGPoint(x: proposed.x, y: newOffsetY)
    }
}

// MARK: - Cell
final class ReelCell: UICollectionViewCell {
    static let reuseID = "ReelCell"

    private let preview = UIImageView()
    private let titleLabel = UILabel()
    private var playerLayer: AVPlayerLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.clipsToBounds = true
        contentView.layer.cornerRadius = 16

        preview.contentMode = .scaleAspectFill
        preview.clipsToBounds = true
        preview.backgroundColor = .black
        preview.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.textColor = .white
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOpacity = 0.6
        titleLabel.layer.shadowRadius = 3

        contentView.addSubview(preview)
        contentView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: contentView.topAnchor),
            preview.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            preview.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])

        contentView.layer.borderColor = UIColor(white: 1, alpha: 0.08).cgColor
        contentView.layer.borderWidth = 1
        backgroundColor = .black
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        detachPlayer()
        preview.image = nil
        titleLabel.text = nil
    }

    func configure(title: String, previewURL: URL?, showPlayer: Bool, sharedPlayer: AVPlayer) {
        titleLabel.text = title
        if showPlayer {
            attachPlayer(player: sharedPlayer)
        } else {
            detachPlayer()
        }
        if let url = previewURL {
            loadPreview(from: url)
        } else {
            preview.backgroundColor = .black
        }
    }

    private func attachPlayer(player: AVPlayer) {
        if playerLayer?.player !== player {
            detachPlayer()
            let layer = AVPlayerLayer(player: player)
            layer.videoGravity = .resizeAspectFill
            layer.frame = contentView.bounds
            contentView.layer.insertSublayer(layer, above: preview.layer)
            playerLayer = layer
        }
        playerLayer?.frame = contentView.bounds
    }

    private func detachPlayer() {
        playerLayer?.player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = contentView.bounds
    }

    private func loadPreview(from url: URL) {
        let req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
        if let cached = URLCache.shared.cachedResponse(for: req)?.data, let img = UIImage(data: cached) {
            self.preview.image = img
            return
        }
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            guard let d = data, let img = UIImage(data: d) else { return }
            if let resp { URLCache.shared.storeCachedResponse(CachedURLResponse(response: resp, data: d), for: req) }
            DispatchQueue.main.async { [weak self] in self?.preview.image = img }
        }.resume()
    }
}

// MARK: - ViewController + Representable
final class ReelsPagerViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private let layout = SnappingFlowLayout()
    private var collectionView: UICollectionView!
    private var items: [VideoRecommendation] = []
    private var activeID: Int?
    private var horizontalPadding: CGFloat = 24     // чуть меньше карточка
    private var verticalPadding: CGFloat = 24

    // контроль обновлений
    private var didSetInitial = false
    private var lastItemsSignature: String?

    // внешние зависимости
    var onActiveIndexChanged: ((Int) -> Void)?
    var sharedPlayer: AVPlayer!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 16
        layout.sectionInset = .init(top: verticalPadding, left: horizontalPadding, bottom: verticalPadding, right: horizontalPadding)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .black
        collectionView.decelerationRate = .fast       // для резкого снапа
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(ReelCell.self, forCellWithReuseIdentifier: ReelCell.reuseID)
        collectionView.dataSource = self
        collectionView.delegate = self

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
        let w = view.bounds.width - 2 * horizontalPadding
        let h = view.bounds.height - 2 * verticalPadding
        layout.itemSize = CGSize(width: w, height: h)
        layout.invalidateLayout()
    }

    // обновляем только если реально изменился набор
    func setItems(_ newItems: [VideoRecommendation]) {
        let sig = newItems.map { "\($0.video_id)" }.joined(separator: ",")
        guard sig != lastItemsSignature else { return }
        lastItemsSignature = sig

        self.items = newItems
        collectionView?.reloadData()

        // выставим активный 0 только один раз
        if !didSetInitial, !newItems.isEmpty {
            didSetInitial = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.scrollTo(index: 0, animated: false)
                self.notifyActive(index: 0)
            }
        }
    }

    func setActiveVideoID(_ id: Int?) {
        self.activeID = id
        // обновить только видимые
        for cell in collectionView.visibleCells {
            guard let idx = collectionView.indexPath(for: cell)?.item else { continue }
            let item = items[idx]
            let showPlayer = (item.video_id == id)
            (cell as? ReelCell)?.configure(
                title: item.title,
                previewURL: URL(string: item.preview_image ?? ""),
                showPlayer: showPlayer,
                sharedPlayer: sharedPlayer
            )
        }
    }

    private func scrollTo(index: Int, animated: Bool) {
        guard index >= 0, index < items.count else { return }
        collectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredVertically, animated: animated)
    }

    private func notifyActive(index: Int) {
        onActiveIndexChanged?(index)
    }

    // MARK: - DataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ReelCell.reuseID, for: indexPath) as! ReelCell
        let item = items[indexPath.item]
        let showPlayer = (item.video_id == activeID)
        cell.configure(
            title: item.title,
            previewURL: URL(string: item.preview_image ?? ""),
            showPlayer: showPlayer,
            sharedPlayer: sharedPlayer
        )
        return cell
    }

    // MARK: - Delegate (агрессивный снап на лёгкий свайп)
    func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                   withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard !items.isEmpty else { return }

        // текущий центр
        let midY = scrollView.contentOffset.y + scrollView.bounds.height / 2
        // ближайшая к центру сейчас
        let visible = collectionView.indexPathsForVisibleItems
        let currentIndex: Int = {
            let target = visible.min { lhs, rhs in
                let f1 = collectionView.layoutAttributesForItem(at: lhs)?.frame ?? .zero
                let f2 = collectionView.layoutAttributesForItem(at: rhs)?.frame ?? .zero
                let d1 = abs(f1.midY - midY)
                let d2 = abs(f2.midY - midY)
                return d1 < d2
            }
            return target?.item ?? 0
        }()

        // решаем, куда листнуть:
        // - если есть ощутимая скорость — на соседнюю в направлении
        // - иначе, по смещению от идеального центра больше порога
        let threshold: CGFloat = 10 // достаточно «чуть-чуть»
        var targetIndex = currentIndex

        if abs(velocity.y) > 0.1 {
            targetIndex = currentIndex + (velocity.y > 0 ? 1 : -1)
        } else {
            if let curFrame = collectionView.layoutAttributesForItem(at: IndexPath(item: currentIndex, section: 0))?.frame {
                let delta = curFrame.midY - midY
                if delta < -threshold { targetIndex = min(currentIndex + 1, items.count - 1) }
                else if delta > threshold { targetIndex = max(currentIndex - 1, 0) }
            }
        }
        targetIndex = max(0, min(items.count - 1, targetIndex))

        // вычислим центр целевой карточки
        if let attr = collectionView.layoutAttributesForItem(at: IndexPath(item: targetIndex, section: 0)) {
            let newOffsetY = attr.center.y - scrollView.bounds.height / 2
            targetContentOffset.pointee = CGPoint(x: targetContentOffset.pointee.x, y: newOffsetY)
            // заранее сообщим активный — так быстрее запустится видео
            notifyActive(index: targetIndex)
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        centerSnapAndActivate()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { centerSnapAndActivate() }
    }

    private func centerSnapAndActivate() {
        let center = CGPoint(x: collectionView.bounds.midX,
                             y: collectionView.contentOffset.y + collectionView.bounds.midY)
        if let indexPath = collectionView.indexPathForItem(at: center) {
            notifyActive(index: indexPath.item)
        }
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
        ui.setItems(items)               // обновим только если реально поменялись
        ui.setActiveVideoID(activeID)    // пересоберём видимые, чтобы player был только в активной
    }
}
