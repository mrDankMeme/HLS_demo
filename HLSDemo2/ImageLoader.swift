//
//  ImageLoader.swift
//  HLSDemo2
//
//  Created by Niiaz Khasanov on 10/17/25.
//


//
//  ImageLoader.swift
//  HLSDemo2
//
//  Created by Niiaz Khasanov on 10/17/25.
//

import UIKit

final class ImageLoader {
    static let shared = ImageLoader()

    private let cache = NSCache<NSURL, UIImage>()
    private let session: URLSession = .shared

    func setImage(on imageView: UIImageView, url: URL?) {
        guard let url else {
            imageView.image = nil
            imageView.backgroundColor = UIColor(white: 0.15, alpha: 1)
            return
        }
        if let cached = cache.object(forKey: url as NSURL) {
            imageView.image = cached
            return
        }
        imageView.image = nil
        imageView.backgroundColor = UIColor(white: 0.15, alpha: 1)

        session.dataTask(with: url) { [weak self] data, _, _ in
            guard
                let self,
                let data,
                let img = UIImage(data: data)
            else { return }
            self.cache.setObject(img, forKey: url as NSURL)
            DispatchQueue.main.async { imageView.image = img }
        }.resume()
    }
}
