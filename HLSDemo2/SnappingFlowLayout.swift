//
//  SnappingFlowLayout.swift
//  HLSDemo2
//
//  Маленькие карточки + уверенный снап по центру.
//  Работает без isPagingEnabled, поддерживает зазор между карточками.
//

import UIKit

final class SnappingFlowLayout: UICollectionViewFlowLayout {

    /// Чем меньше — тем легче «перелистнуть» на соседнюю (0.05…0.2).
    var velocityThreshold: CGFloat = 0.12

    override func prepare() {
        super.prepare()
        scrollDirection = .vertical
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        // При поворотах/изменениях размера пересчитываем центры
        return true
    }

    // Снап к ближайшему центру карточки (как «Фото», но с произвольной высотой/зазором).
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint,
                                      withScrollingVelocity velocity: CGPoint) -> CGPoint {

        guard let cv = collectionView else { return super.targetContentOffset(forProposedContentOffset: proposedContentOffset, withScrollingVelocity: velocity) }

        // Видимая область на момент окончания жеста
        let bounds = cv.bounds
        let targetRect = CGRect(x: 0, y: proposedContentOffset.y, width: bounds.width, height: bounds.height)
        guard let attrs = super.layoutAttributesForElements(in: targetRect), !attrs.isEmpty else {
            return super.targetContentOffset(forProposedContentOffset: proposedContentOffset, withScrollingVelocity: velocity)
        }

        // Центр экрана относительно proposedContentOffset
        let screenMidY = proposedContentOffset.y + bounds.height / 2

        // Находим ближайший к screenMidY item
        var closest = attrs.first!
        var minDist = CGFloat.greatestFiniteMagnitude
        for a in attrs where a.representedElementCategory == .cell {
            let dist = abs(a.center.y - screenMidY)
            if dist < minDist {
                minDist = dist
                closest = a
            }
        }

        var targetIndex = closest.indexPath.item

        // Если пользователь «толкнул» жестом — переезжаем на соседа по направлению свайпа
        if abs(velocity.y) > velocityThreshold {
            targetIndex += (velocity.y > 0 ? 1 : -1)
            targetIndex = max(0, min(targetIndex, cv.numberOfItems(inSection: 0) - 1))
        }

        // Центр целевого айтема
        guard let targetAttr = layoutAttributesForItem(at: IndexPath(item: targetIndex, section: 0)) else {
            return CGPoint(x: proposedContentOffset.x, y: proposedContentOffset.y)
        }

        // Смещаем так, чтобы целевой оказался по центру экрана
        let targetOffsetY = targetAttr.center.y - bounds.height / 2

        // Ограничим в пределах контента
        let minY = -cv.adjustedContentInset.top
        let maxY = cv.contentSize.height - bounds.height + cv.adjustedContentInset.bottom
        let clampedY = min(max(targetOffsetY, minY), maxY)

        return CGPoint(x: proposedContentOffset.x, y: clampedY)
    }
}
