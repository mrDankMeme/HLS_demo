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

    private let layout = SnappingFlowLayout()
    private var collectionView: UICollectionView!

    private var items: [VideoRecommendation] = []
    private var activeID: Int?
    private var didSetInitial = false
    private var lastItemsSignature: String?
    private var currentCenteredIndex: Int?

    var onActiveIndexChanged: ((Int) -> Void)?
    var onTapActive: (() -> Void)?
    var sharedPlayer: AVPlayer!

    private var isDetailShown = false
    private var didForceInitialCenter = false

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

    private let hPad: CGFloat = 24
    private let vPad: CGFloat = 24

    private lazy var tapRecognizer: UITapGestureRecognizer = {
        let gr = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        gr.cancelsTouchesInView = false
        return gr
    }()

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
        collectionView.addGestureRecognizer(tapRecognizer)
        collectionView.contentInsetAdjustmentBehavior = .never

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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !didForceInitialCenter, !items.isEmpty, let id = activeID,
           let index = items.firstIndex(where: { $0.video_id == id }) {
            didForceInitialCenter = true
            centerItem(at: index)
        }
    }

    func setItems(_ newItems: [VideoRecommendation]) {
        let sig = newItems.map { "\($0.video_id)" }.joined(separator: ",")
        guard sig != lastItemsSignature else { return }
        lastItemsSignature = sig

        items = newItems
        collectionView.reloadData()
        didForceInitialCenter = false

        guard !items.isEmpty else { return }
        if !didSetInitial {
            didSetInitial = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let id = self.activeID,
                   let idx = self.items.firstIndex(where: { $0.video_id == id }) {
                    self.centerItem(at: idx)
                    self.notifyActive(index: idx)
                }
            }
        }
    }

    func setActiveVideoID(_ id: Int?) {
        self.activeID = id

        guard !isDetailShown else {
            detachPlayer()
            return
        }

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

    func setDetailShown(_ shown: Bool) {
        isDetailShown = shown
        if shown {
            detachPlayer()
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.setActiveVideoID(self.activeID)
                if self.sharedPlayer.timeControlStatus != .playing {
                    self.sharedPlayer.play()
                }
                if let id = self.activeID,
                   let idx = self.items.firstIndex(where: { $0.video_id == id }) {
                    self.centerItem(at: idx)
                }
            }
        }
    }

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
        guard !isDetailShown else { return }
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
            notifyActive(index: index)
        }
    }

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

    private func centerItem(at index: Int) {
        guard index >= 0, index < items.count else { return }
        collectionView.layoutIfNeeded()
        let ip = IndexPath(item: index, section: 0)
        guard let attrs = collectionView.layoutAttributesForItem(at: ip) else {
            scrollTo(index: index, animated: false)
            return
        }
        let mid = collectionView.bounds.height / 2
        let targetY = attrs.center.y - mid
        let minY = -collectionView.contentInset.top
        let maxY = max(minY, collectionView.contentSize.height - collectionView.bounds.height + collectionView.contentInset.bottom)
        let clampedY = min(max(targetY, minY), maxY)
        collectionView.setContentOffset(CGPoint(x: 0, y: clampedY), animated: false)
    }

    @objc private func handleTap(_ gr: UITapGestureRecognizer) {
        guard gr.state == .ended else { return }
        guard let idx = dominantVisibleIndex(),
              let activeID, items[idx].video_id == activeID else { return }
        onTapActive?()
    }

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
