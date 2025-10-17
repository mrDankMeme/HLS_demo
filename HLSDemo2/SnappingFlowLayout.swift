//
//  SnappingFlowLayout.swift
//  HLSDemo2
//
//  Created by Niiaz Khasanov on 10/17/25.
//

import UIKit

// Единственный источник снапа — центрируем ближайшую карточку.
final class SnappingFlowLayout: UICollectionViewFlowLayout {
    override func targetContentOffset(forProposedContentOffset proposed: CGPoint,
                                      withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let cv = collectionView else { return proposed }
        let midY = proposed.y + cv.bounds.height / 2
        let rect = CGRect(x: 0, y: proposed.y, width: cv.bounds.width, height: cv.bounds.height)
        guard let attrs = layoutAttributesForElements(in: rect) else { return proposed }
        var best: UICollectionViewLayoutAttributes?
        var minDist = CGFloat.greatestFiniteMagnitude
        for a in attrs where a.representedElementCategory == .cell {
            let d = abs(a.center.y - midY)
            if d < minDist { minDist = d; best = a }
        }
        guard let target = best else { return proposed }
        return CGPoint(x: proposed.x, y: target.center.y - cv.bounds.height / 2)
    }
}
