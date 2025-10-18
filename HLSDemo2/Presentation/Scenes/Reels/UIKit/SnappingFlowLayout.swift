//
//  SnappingFlowLayout.swift
//  HLSDemo2
//
//  Created by Niiaz Khasanov on 10/17/25.
//

import UIKit


final class SnappingFlowLayout: UICollectionViewFlowLayout {

    /// Порог скорости для принудительного перехода на соседа.
    private let velocityThreshold: CGFloat = 0.18

    override func targetContentOffset(forProposedContentOffset proposed: CGPoint,
                                      withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let cv = collectionView else { return proposed }

        let bounds = cv.bounds
        let proposedMidY = proposed.y + bounds.height / 2

        
        let proposedRect = CGRect(x: 0, y: proposed.y, width: bounds.width, height: bounds.height)
        let attrsInProposed = layoutAttributesForElements(in: proposedRect)?
            .filter { $0.representedElementCategory == .cell } ?? []

        var target = attrsInProposed.min {
            abs($0.center.y - proposedMidY) < abs($1.center.y - proposedMidY)
        }

        
        if abs(velocity.y) > velocityThreshold {
            let currentMidY = cv.contentOffset.y + bounds.height / 2
            let currentRect = CGRect(x: 0, y: cv.contentOffset.y, width: bounds.width, height: bounds.height)
            let attrsInCurrent = layoutAttributesForElements(in: currentRect)?
                .filter { $0.representedElementCategory == .cell } ?? []

            if let current = attrsInCurrent.min(by: { abs($0.center.y - currentMidY) < abs($1.center.y - currentMidY) }) {
                let step = velocity.y > 0 ? 1 : -1
                let section = current.indexPath.section
                let itemsCount = cv.numberOfItems(inSection: section)
                let nextRaw = current.indexPath.item + step
                let nextClamped = max(0, min(itemsCount - 1, nextRaw))
                if nextClamped != current.indexPath.item,
                   let nextAttr = layoutAttributesForItem(at: IndexPath(item: nextClamped, section: section)) {
                    target = nextAttr
                }
            }
        }

        guard let t = target else { return proposed }
        return CGPoint(x: proposed.x, y: t.center.y - bounds.height / 2)
    }
}
