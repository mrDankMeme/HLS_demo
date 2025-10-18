//
//  ReelCell.swift
//  HLSDemo2
//
//  Created by Niiaz Khasanov on 10/17/25.
//

import UIKit

final class ReelCell: UICollectionViewCell {
    static let reuseID = "ReelCell"

    private let posterView = UIImageView()
    let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.clipsToBounds = true
        contentView.layer.cornerRadius = 16
        contentView.layer.borderColor = UIColor(white: 1, alpha: 0.08).cgColor
        contentView.layer.borderWidth = 1
        contentView.backgroundColor = .black

        posterView.contentMode = .scaleAspectFill
        posterView.clipsToBounds = true
        posterView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.textColor = .white
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.numberOfLines = 2
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOpacity = 0.65
        titleLabel.layer.shadowRadius = 3
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(posterView)
        contentView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            posterView.topAnchor.constraint(equalTo: contentView.topAnchor),
            posterView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            posterView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            posterView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        posterView.image = nil
    }

    func configure(title: String, previewURL: URL?) {
        titleLabel.text = title
     //   ImageLoader.shared.setImage(on: posterView, url: previewURL)
    }

    /// Размещаем playerView поверх постера и под заголовком.
    func hostPlayerView(_ v: UIView) {
        v.translatesAutoresizingMaskIntoConstraints = false
        contentView.insertSubview(v, aboveSubview: posterView)
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: contentView.topAnchor),
            v.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            v.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            v.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
}
