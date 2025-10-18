//
//  ReelCell.swift
//  HLSDemo2
//
//  Created by Niiaz Khasanov on 10/17/25.
//

import UIKit

final class ReelCell: UICollectionViewCell {
    static let reuseID = "ReelCell"

    // MARK: - Views

    private let posterView = UIImageView()

    // Верх
    private let avatarWrap = UIView()
    private let avatarView = UIImageView()
    private let liveBadge  = PaddingLabel(insets: .init(top: 4, left: 10, bottom: 4, right: 10))
    private let usernameLabel = UILabel()
    private let verifiedIcon  = UIImageView()
    let titleLabel = UILabel()

    // Хэштеги теперь UICollectionView
    private var hashtags: [String] = []
    private var hashtagsCollection: UICollectionView!

    // Нижний блок
    private let locationStack = UIStackView()
    private let viewsStack = UIStackView()
    private let likeButton = UIButton(type: .system)
    private let likeCountLabel = UILabel()

    // Градиенты
    private let topGradientLayer = CAGradientLayer()
    private let bottomGradientLayer = CAGradientLayer()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.clipsToBounds = true
        contentView.layer.cornerRadius = 20
        contentView.layer.borderColor = UIColor(white: 1, alpha: 0.08).cgColor
        contentView.layer.borderWidth = 1
        contentView.backgroundColor = .black

        posterView.translatesAutoresizingMaskIntoConstraints = false
        posterView.contentMode = .scaleAspectFill
        posterView.clipsToBounds = true
        contentView.addSubview(posterView)

        // --- Верх ---
        avatarWrap.translatesAutoresizingMaskIntoConstraints = false
        avatarWrap.layer.cornerRadius = 22
        avatarWrap.layer.borderWidth  = 3
        avatarWrap.layer.borderColor  = UIColor.white.withAlphaComponent(0.95).cgColor
        avatarWrap.clipsToBounds = true

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarWrap.addSubview(avatarView)

        liveBadge.translatesAutoresizingMaskIntoConstraints = false
        liveBadge.text = "Live"
        liveBadge.font = .boldSystemFont(ofSize: 14)
        liveBadge.textColor = .white
        liveBadge.backgroundColor = UIColor(red: 1.00, green: 0.30, blue: 0.22, alpha: 1)
        liveBadge.layer.cornerRadius = 8
        liveBadge.clipsToBounds = true

        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        usernameLabel.textColor = .white
        usernameLabel.font = .systemFont(ofSize: 22, weight: .semibold)

        verifiedIcon.translatesAutoresizingMaskIntoConstraints = false
        verifiedIcon.contentMode = .scaleAspectFit
        verifiedIcon.tintColor = UIColor(red: 0.27, green: 0.56, blue: 1.0, alpha: 1)
        verifiedIcon.image = UIImage(systemName: "checkmark.seal.fill")

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.numberOfLines = 3
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOpacity = 0.6
        titleLabel.layer.shadowRadius = 3

        contentView.addSubview(avatarWrap)
        contentView.addSubview(liveBadge)
        contentView.addSubview(usernameLabel)
        contentView.addSubview(verifiedIcon)
        contentView.addSubview(titleLabel)

        // --- Хэштеги (горизонтальный scroll) ---
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        hashtagsCollection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        hashtagsCollection.backgroundColor = .clear
        hashtagsCollection.showsHorizontalScrollIndicator = false
        hashtagsCollection.dataSource = self
        hashtagsCollection.delegate = self
        hashtagsCollection.translatesAutoresizingMaskIntoConstraints = false
        hashtagsCollection.register(HashtagCell.self, forCellWithReuseIdentifier: HashtagCell.reuseID)
        contentView.addSubview(hashtagsCollection)

        // --- Нижний блок ---
        locationStack.axis = .horizontal
        locationStack.spacing = 8
        locationStack.alignment = .center
        locationStack.translatesAutoresizingMaskIntoConstraints = false

        viewsStack.axis = .horizontal
        viewsStack.spacing = 6
        viewsStack.alignment = .center
        viewsStack.translatesAutoresizingMaskIntoConstraints = false
        let eye = makeIcon("eye")
        let viewsLabel = makeLabel("567")
        viewsStack.addArrangedSubview(eye)
        viewsStack.addArrangedSubview(viewsLabel)

        likeButton.translatesAutoresizingMaskIntoConstraints = false
        likeButton.setImage(UIImage(systemName: "heart"), for: .normal)
        likeButton.tintColor = .white
        likeButton.addTarget(self, action: #selector(didTapLike), for: .touchUpInside)

        likeCountLabel.translatesAutoresizingMaskIntoConstraints = false
        likeCountLabel.text = "1.5k"
        likeCountLabel.textColor = .white
        likeCountLabel.font = .systemFont(ofSize: 18, weight: .semibold)

        contentView.addSubview(locationStack)
        contentView.addSubview(viewsStack)
        contentView.addSubview(likeButton)
        contentView.addSubview(likeCountLabel)

        // Градиенты
        topGradientLayer.colors = [UIColor.black.withAlphaComponent(0.45).cgColor, UIColor.clear.cgColor]
        bottomGradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.55).cgColor]
        posterView.layer.addSublayer(topGradientLayer)
        posterView.layer.addSublayer(bottomGradientLayer)

        // Constraints
        NSLayoutConstraint.activate([
            posterView.topAnchor.constraint(equalTo: contentView.topAnchor),
            posterView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            posterView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            posterView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            avatarWrap.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            avatarWrap.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            avatarWrap.widthAnchor.constraint(equalToConstant: 125),
            avatarWrap.heightAnchor.constraint(equalToConstant: 152),

            avatarView.topAnchor.constraint(equalTo: avatarWrap.topAnchor),
            avatarView.leadingAnchor.constraint(equalTo: avatarWrap.leadingAnchor),
            avatarView.trailingAnchor.constraint(equalTo: avatarWrap.trailingAnchor),
            avatarView.bottomAnchor.constraint(equalTo: avatarWrap.bottomAnchor),

            liveBadge.centerXAnchor.constraint(equalTo: avatarWrap.centerXAnchor),
            liveBadge.topAnchor.constraint(equalTo: avatarWrap.bottomAnchor, constant: -16.5),

            usernameLabel.leadingAnchor.constraint(equalTo: avatarWrap.trailingAnchor, constant: 16),
            usernameLabel.topAnchor.constraint(equalTo: avatarWrap.topAnchor, constant: 6),

            verifiedIcon.leadingAnchor.constraint(equalTo: usernameLabel.trailingAnchor, constant: 8),
            verifiedIcon.centerYAnchor.constraint(equalTo: usernameLabel.centerYAnchor),
            verifiedIcon.widthAnchor.constraint(equalToConstant: 20),
            verifiedIcon.heightAnchor.constraint(equalTo: verifiedIcon.widthAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: usernameLabel.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor, constant: 10),

            hashtagsCollection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            hashtagsCollection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hashtagsCollection.heightAnchor.constraint(equalToConstant: 44),
            hashtagsCollection.bottomAnchor.constraint(equalTo: locationStack.topAnchor, constant: -10),

            locationStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            locationStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),

            viewsStack.trailingAnchor.constraint(equalTo: likeButton.leadingAnchor, constant: -16),
            viewsStack.centerYAnchor.constraint(equalTo: locationStack.centerYAnchor),

            likeButton.trailingAnchor.constraint(equalTo: likeCountLabel.leadingAnchor, constant: -6),
            likeButton.centerYAnchor.constraint(equalTo: locationStack.centerYAnchor),
            likeButton.widthAnchor.constraint(equalToConstant: 24),
            likeButton.heightAnchor.constraint(equalToConstant: 24),

            likeCountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            likeCountLabel.centerYAnchor.constraint(equalTo: likeButton.centerYAnchor)
        ])

        applyPlaceholders()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        topGradientLayer.frame = CGRect(x: 0, y: 0, width: posterView.bounds.width, height: 190)
        bottomGradientLayer.frame = CGRect(x: 0, y: posterView.bounds.height - 230,
                                           width: posterView.bounds.width, height: 230)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        posterView.image = nil
        avatarView.image = nil
        applyPlaceholders()
    }

    func configure(title: String, previewURL: URL?) {
        titleLabel.text = title
        ImageLoader.shared.setImage(on: posterView, url: previewURL)
    }

    func hostPlayerView(_ v: UIView) {
        v.translatesAutoresizingMaskIntoConstraints = false
        contentView.insertSubview(v, aboveSubview: posterView)
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: contentView.topAnchor),
            v.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            v.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            v.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        [avatarWrap, liveBadge, usernameLabel, verifiedIcon, titleLabel,
         hashtagsCollection, locationStack, viewsStack, likeButton, likeCountLabel]
            .forEach { contentView.bringSubviewToFront($0) }
    }

    // MARK: - Like tap
    @objc private func didTapLike() {
        let filled = likeButton.image(for: .normal) == UIImage(systemName: "heart.fill")
        let newImage = filled ? UIImage(systemName: "heart") : UIImage(systemName: "heart.fill")
        likeButton.setImage(newImage, for: .normal)
        likeButton.tintColor = filled ? .white : .systemPink

        UIView.animate(withDuration: 0.15,
                       animations: {
                           self.likeButton.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
                       },
                       completion: { _ in
                           UIView.animate(withDuration: 0.15) {
                               self.likeButton.transform = .identity
                           }
                       })
    }

    // MARK: - Helpers
    private func makeIcon(_ systemName: String) -> UIImageView {
        let iv = UIImageView(image: UIImage(systemName: systemName))
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        return iv
    }

    private func makeLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.textColor = .white
        l.font = .systemFont(ofSize: 18, weight: .semibold)
        return l
    }

    private func applyPlaceholders() {
        posterView.backgroundColor = UIColor(white: 0.15, alpha: 1)
        avatarView.backgroundColor = UIColor(white: 1, alpha: 0.18)
        usernameLabel.text = "@kristina"
        titleLabel.text = "Водные просторы также впечатляют своей красотой.\nВода успокаивает."

        locationStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        locationStack.addArrangedSubview(makeIcon("mappin.and.ellipse"))
        locationStack.addArrangedSubview(makeLabel("Россия, Сочи"))

        hashtags = [
            "#португалия", "#природа", "#лето", "#океан", "#пляж", "#волны",
            "#закат", "#море", "#релакс", "#спокойствие", "#вдохновение",
            "#travel", "#trip", "#sunset"
        ]
        hashtagsCollection.reloadData()
    }
}

// MARK: - UICollectionView DataSource & Delegate
extension ReelCell: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        hashtags.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HashtagCell.reuseID, for: indexPath) as! HashtagCell
        cell.configure(text: hashtags[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let text = hashtags[indexPath.item]
        let width = (text as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 18, weight: .semibold)]).width + 28
        return CGSize(width: width, height: 36)
    }
}

// MARK: - HashtagCell
private final class HashtagCell: UICollectionViewCell {
    static let reuseID = "HashtagCell"

    private let label = PaddingLabel(insets: .init(top: 8, left: 14, bottom: 8, right: 14))

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        label.backgroundColor = UIColor(white: 0.1, alpha: 0.8)
        label.layer.cornerRadius = 18
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(text: String) {
        label.text = text
    }
}

// MARK: - PaddingLabel
final class PaddingLabel: UILabel {
    private let insets: UIEdgeInsets
    init(insets: UIEdgeInsets) {
        self.insets = insets
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + insets.left + insets.right,
                      height: s.height + insets.top + insets.bottom)
    }
}
