//
//  InboxAsyncImageView.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 7/23/26.
//

import SwiftUI

/// Replacement for `AsyncImage` in inbox rows that additionally plays animated GIFs
/// (`AsyncImage` decodes only a GIF's first frame). Static formats render exactly as
/// before, and the placeholder shows while loading and on failure, matching
/// `AsyncImage(url:content:placeholder:)` behavior.
struct InboxAsyncImageView: View {
    let url: URL?

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                if image.images != nil {
                    InboxAnimatedImageView(image: image)
                        .aspectRatio(image.size, contentMode: .fit)
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            } else {
                Image(systemName: "photo")
                    .aspectRatio(contentMode: .fit)
            }
        }
        .task(id: url) {
            guard let url else {
                image = nil
                return
            }
            image = await InboxImageLoader.shared.image(for: url)
        }
    }
}

/// Hosts a `UIImageView` because SwiftUI's `Image` has no animation support; assigning an
/// animated `UIImage` to `UIImageView.image` plays it automatically. Sizing is left to
/// SwiftUI via the `aspectRatio`/`frame` modifiers applied by the caller.
private struct InboxAnimatedImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        // Defer to the SwiftUI-proposed size instead of the image's intrinsic size.
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        guard uiView.image !== image else { return }
        uiView.image = image
    }
}

/// Fetches and decodes inbox message images, keeping decoded results in memory so
/// scrolling doesn't re-download or re-decode (animated GIFs are expensive to decode).
final class InboxImageLoader {
    static let shared = InboxImageLoader()

    private let cache = NSCache<NSURL, UIImage>()
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        cache.totalCostLimit = 100 * 1024 * 1024
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        guard let (data, _) = try? await session.data(from: url),
              let image = await Self.decode(data) else {
            return nil
        }
        cache.setObject(image, forKey: url as NSURL, cost: Self.decodedCost(of: image))
        return image
    }

    static func decode(_ data: Data) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            InboxAnimatedImage.isGIF(data) ? InboxAnimatedImage.image(from: data) : UIImage(data: data)
        }.value
    }

    /// Approximate decoded bitmap footprint: unique frames × RGBA bytes per frame.
    private static func decodedCost(of image: UIImage) -> Int {
        let uniqueFrames = image.images.map { Set($0.map(ObjectIdentifier.init)).count } ?? 1
        let pixels = image.size.width * image.scale * image.size.height * image.scale
        return Int(pixels) * 4 * uniqueFrames
    }
}
