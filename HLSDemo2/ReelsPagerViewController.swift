//
//  ReelsPagerViewController.swift
//  HLSDemo2
//
//  Created by Niiaz Khasanov on 10/17/25.
//

import UIKit
import AVKit
import AVFoundation

final class ReelsPagerViewController: UIViewController,
                                      UICollectionViewDataSource,
                                      UICollectionViewDelegate,
                                      UIScrollViewDelegate {

    // UI
    private let layout = SnappingFlowLayout()
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

    // Layout
    private let hPad: CGFloat = 24
    private let vPad: CGFloat = 24

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 16
        layout.sectionInset = .init(top: vPad, left: hPad, bottom: vPad, right: hPad)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .black
        collectionView.decelerationRate = .fast
        collectionView.showsVerticalScrollIndicator = false
        collectionView.isPrefetchingEnabled = false
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
        layout.itemSize = CGSize(width: view.bounds.width - 2*hPad,
                                 height: view.bounds.height - 2*vPad)
        if let host = currentHostCell { playerVC.view.frame = host.contentView.bounds }
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
                self.notifyActive(index: 0) // VM активирует 0-ю
            }
        }
    }

    func setActiveVideoID(_ id: Int?) {
        // не скроллим, только обновляем и приклеиваем, если видно
        self.activeID = id

        // если id сброшен — обязательно оторвём плеер
        guard let id = id,
              let idx = items.firstIndex(where: { $0.video_id == id }) else {
            detachPlayer()
            return
        }

        let ip = IndexPath(item: idx, section: 0)
        if let cell = collectionView.cellForItem(at: ip) as? ReelCell {
            attachPlayer(to: cell) // приклеиваем ТОЛЬКО после публикации нового activeID
        } else {
            // Новая активная ячейка ещё не видна — не держим плеер на старой
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
        // клеим только если уже знаем, что именно ЭТА ячейка активна
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

    // MARK: - Scroll events
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { updateActiveIfNeeded(force: true) }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { updateActiveIfNeeded(force: true) }
    }
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { updateActiveIfNeeded(force: true) }

    private func updateActiveIfNeeded(force: Bool) {
        guard !items.isEmpty else { return }
        guard let index = dominantVisibleIndex() else { return }

        if force || currentCenteredIndex != index {
            currentCenteredIndex = index
            // ВАЖНО: только сообщаем VM. Никаких attach здесь!
            notifyActive(index: index)
        }
    }

    /// Выбираем ячейку, которая больше всего перекрывает видимую область (устойчиво к «чуть видна снизу»).
    private func dominantVisibleIndex() -> Int? {
        guard let cv = collectionView else { return nil }
        let visibleRect = CGRect(origin: cv.contentOffset, size: cv.bounds.size)

        var bestIndex: Int?
        var bestOverlap: CGFloat = -1

        for ip in cv.indexPathsForVisibleItems {
            guard let frame = cv.layoutAttributesForItem(at: ip)?.frame else { continue }
            let overlap = frame.intersection(visibleRect).height
            if overlap > bestOverlap {
                bestOverlap = overlap
                bestIndex = ip.item
            }
        }
        return bestIndex
    }

    private func notifyActive(index: Int) { onActiveIndexChanged?(index) }

    private func scrollTo(index: Int, animated: Bool) {
        collectionView.scrollToItem(at: IndexPath(item: index, section: 0),
                                    at: .centeredVertically,
                                    animated: animated)
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
