//
//  ReelsPagerViewController.swift
//  HLSDemo2
//
//  Кастомный paging без кастомного layout:
//  - карточка меньше экрана (heightRatio)
//  - зазор между карточками interItemGap
//  - шаг страницы = itemHeight + gap
//  - быстрый свайп → строго на соседнюю страницу (±1)
//  - медленный → к ближайшей (порог ~25% страницы)
//

import UIKit
import AVKit
import AVFoundation

final class ReelsPagerViewController: UIViewController,
                                      UICollectionViewDataSource,
                                      UICollectionViewDelegate,
                                      UIScrollViewDelegate {

    // UI
    private let layout = UICollectionViewFlowLayout()
    private var collectionView: UICollectionView!

    // данные
    private var items: [VideoRecommendation] = []
    private var activeID: Int?
    private var didSetInitial = false
    private var lastItemsSignature: String?
    private var currentCenteredIndex: Int?

    // связи
    var onActiveIndexChanged: ((Int) -> Void)?
    var sharedPlayer: AVPlayer!

    // один AVPlayerViewController, который «кочует» между ячейками
    private let playerVC: AVPlayerViewController = {
        let vc = AVPlayerViewController()
        vc.showsPlaybackControls = false
        vc.videoGravity = .resizeAspectFill
        vc.allowsPictureInPicturePlayback = true
        vc.canStartPictureInPictureAutomaticallyFromInline = true
        vc.updatesNowPlayingInfoCenter = false
        vc.view.backgroundColor = .clear
        vc.view.isUserInteractionEnabled = true
        return vc
    }()
    private weak var currentHostCell: ReelCell?

    // Layout tuning
    private let hPad: CGFloat = 34
    private let interItemGap: CGFloat = 20
    private let heightRatio: CGFloat = 0.65

    // Paging чувствительность
    private let velocityTap: CGFloat = 0.02      // всё, что ниже — считаем «медленным»
    private let slowSnapThreshold: CGFloat = 0.25 // доля страницы для щёлчка к соседней

    // Вычисляемые метрики страницы
    private var itemHeight: CGFloat = 0
    private var pageHeight: CGFloat = 0
    private var insetTop: CGFloat = 0

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = interItemGap

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .black
        collectionView.showsVerticalScrollIndicator = false
        collectionView.isPrefetchingEnabled = false

        // Нативный paging выключаем — делаем свой (по размеру карточки)
        collectionView.isPagingEnabled = false
        collectionView.decelerationRate = .fast

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

        addChild(playerVC)
        playerVC.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let W = view.bounds.width
        let H = view.bounds.height

        itemHeight = floor(H * heightRatio)
        pageHeight = itemHeight + interItemGap

        layout.itemSize = CGSize(width: W - 2 * hPad, height: itemHeight)

        // чтобы текущая карточка всегда центрировалась на «странице»
        insetTop = max(0, (H - itemHeight) / 2)
        layout.sectionInset = .init(top: insetTop, left: hPad, bottom: insetTop, right: hPad)

        if let host = currentHostCell { playerVC.view.frame = host.contentView.bounds }

        // Пересчёт центра текущей страницы при смене геометрии
        if let idx = currentCenteredIndex {
            let y = offsetYToCenterItem(at: idx)
            collectionView.setContentOffset(CGPoint(x: 0, y: y), animated: false)
        }
    }

    // MARK: - Public API
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
                self.currentCenteredIndex = 0
                self.notifyActive(index: 0)
            }
        }
    }

    func setActiveVideoID(_ id: Int?) {
        self.activeID = id
        guard let id = id,
              let idx = items.firstIndex(where: { $0.video_id == id }) else {
            detachPlayer()
            return
        }

        let ip = IndexPath(item: idx, section: 0)
        if let cell = collectionView.cellForItem(at: ip) as? ReelCell {
            attachPlayer(to: cell)
        } else {
            detachPlayer()
        }
    }

    // MARK: - DataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ReelCell.reuseID, for: indexPath) as! ReelCell
        let model = items[indexPath.item]
        let previewURL = model.preview_image.flatMap { URL(string: $0) }
        cell.configure(title: model.title, previewURL: previewURL)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        guard let reel = cell as? ReelCell else { return }
        if let activeID, items[indexPath.item].video_id == activeID {
            attachPlayer(to: reel)
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        didEndDisplaying cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        if currentHostCell === (cell as? ReelCell) {
            detachPlayer()
        }
    }

    // MARK: - Кастомный paging — всегда максимум ±1 страница за жест
    func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                   withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {

        guard pageHeight > 0 else { return }

        let currentY = scrollView.contentOffset.y
        let proposedY = targetContentOffset.pointee.y

        // Текущая страница (по текущему offset)
        let currentPageRaw = (currentY + insetTop) / pageHeight
        let currentPage = Int(currentPageRaw.rounded())
        let currentPageCenterY = CGFloat(currentPage) * pageHeight

        // Направление: быстрый свайп — по знаку скорости (строго ±1),
        // медленный — по смещению от центра текущей страницы (порог 25%).
        var direction = 0
        if abs(velocity.y) > velocityTap {
            direction = velocity.y > 0 ? 1 : -1
        } else {
            let delta = proposedY - currentPageCenterY
            if delta > pageHeight * slowSnapThreshold { direction = 1 }
            else if delta < -pageHeight * slowSnapThreshold { direction = -1 }
            else { direction = 0 }
        }

        var targetIndex = currentPage + direction
        targetIndex = max(0, min(targetIndex, max(0, items.count - 1)))

        // Целевой offset — центр нужной карточки
        targetContentOffset.pointee.y = offsetYToCenterItem(at: targetIndex)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { publishActiveForCurrentPage() }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { publishActiveForCurrentPage() }
    }
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { publishActiveForCurrentPage() }

    private func publishActiveForCurrentPage() {
        guard !items.isEmpty else { return }
        let idx = centeredIndex(for: collectionView.contentOffset.y)
        if currentCenteredIndex != idx {
            currentCenteredIndex = idx
            notifyActive(index: idx)
        }
    }

    // MARK: - Индексация по оффсету/геометрии
    private func centeredIndex(for offsetY: CGFloat) -> Int {
        guard pageHeight > 0 else { return 0 }
        let raw = ((offsetY + insetTop) / pageHeight).rounded()
        return max(0, min(Int(raw), max(0, items.count - 1)))
    }

    private func offsetYToCenterItem(at index: Int) -> CGFloat {
        // центр i-й карточки = insetTop + index*pageHeight; чтобы центр экрана совпал, offset = index*pageHeight
        return CGFloat(index) * pageHeight
    }

    private func notifyActive(index: Int) { onActiveIndexChanged?(index) }

    private func scrollTo(index: Int, animated: Bool) {
        let y = offsetYToCenterItem(at: index)
        collectionView.setContentOffset(CGPoint(x: 0, y: y), animated: animated)
    }

    // MARK: - Приклейка плеера к ячейке
    private func attachPlayer(to cell: ReelCell) {
        guard currentHostCell !== cell else { return }
        detachPlayer()
        playerVC.player = sharedPlayer
        cell.hostPlayerView(playerVC.view!)
        currentHostCell = cell
    }

    private func detachPlayer() {
        guard let host = currentHostCell else { return }
        playerVC.view.removeFromSuperview()
        currentHostCell = nil
    }
}
