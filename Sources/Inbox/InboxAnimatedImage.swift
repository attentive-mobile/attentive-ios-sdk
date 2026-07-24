//
//  InboxAnimatedImage.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 7/23/26.
//

import ImageIO
import UIKit

/// Decodes animated GIF data into a playable `UIImage` using only ImageIO/UIKit — the SDK
/// must stay dependency-free, so no SDWebImage/Kingfisher. Non-GIF data is rejected so
/// callers can fall back to `UIImage(data:)`.
enum InboxAnimatedImage {
    /// Frames larger than this on their longest side are downsampled while decoding.
    static let defaultMaxPixelSize: CGFloat = 720
    /// Hard cap on unique decoded frames, independent of the byte budget.
    static let defaultMaxFrameCount = 120
    /// Budget for total decoded bitmap bytes per GIF. Combined with the frame cap this
    /// bounds the memory one GIF can pin; GIFs over budget are frame-sampled to fit.
    static let defaultMaxDecodedBytes = 64 * 1024 * 1024

    /// Entries in the expanded `UIImage.animatedImage` frame array are references to the
    /// unique decoded frames, so this caps array length, not bitmap memory.
    private static let maxExpandedFrameEntries = 1_024

    static func isGIF(_ data: Data) -> Bool {
        guard data.count >= 6 else { return false }
        let header = [UInt8](data.prefix(6))
        // "GIF87a" / "GIF89a"
        return header[0...3].elementsEqual([0x47, 0x49, 0x46, 0x38])
            && (header[4] == 0x37 || header[4] == 0x39)
            && header[5] == 0x61
    }

    static func image(
        from data: Data,
        maxPixelSize: CGFloat = defaultMaxPixelSize,
        maxFrameCount: Int = defaultMaxFrameCount,
        maxDecodedBytes: Int = defaultMaxDecodedBytes
    ) -> UIImage? {
        guard isGIF(data), let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 1 else {
            return decodeFrame(source, at: 0, maxPixelSize: maxPixelSize).map { UIImage(cgImage: $0) }
        }

        let delays = (0..<frameCount).map { frameDelay(source, at: $0) }
        let stride = frameStride(
            source,
            frameCount: frameCount,
            maxPixelSize: maxPixelSize,
            maxFrameCount: maxFrameCount,
            maxDecodedBytes: maxDecodedBytes
        )

        var frames: [UIImage] = []
        var frameDelays: [TimeInterval] = []
        var index = 0
        while index < frameCount {
            if let cgImage = decodeFrame(source, at: index, maxPixelSize: maxPixelSize) {
                frames.append(UIImage(cgImage: cgImage))
                // Fold the delays of any skipped frames into the kept one so sampling
                // preserves the GIF's overall duration.
                frameDelays.append(delays[index..<min(index + stride, frameCount)].reduce(0, +))
            }
            index += stride
        }

        guard frames.count > 1 else { return frames.first }
        return animatedImage(frames: frames, delays: frameDelays)
    }

    // MARK: - Private

    /// Every `stride`-th frame is decoded so the unique-frame count fits both the frame
    /// cap and the byte budget.
    private static func frameStride(
        _ source: CGImageSource,
        frameCount: Int,
        maxPixelSize: CGFloat,
        maxFrameCount: Int,
        maxDecodedBytes: Int
    ) -> Int {
        let bytesPerFrame = estimatedBytesPerFrame(source, maxPixelSize: maxPixelSize)
        let allowedFrames = max(1, min(maxFrameCount, maxDecodedBytes / bytesPerFrame))
        return max(1, Int((Double(frameCount) / Double(allowedFrames)).rounded(.up)))
    }

    private static func estimatedBytesPerFrame(_ source: CGImageSource, maxPixelSize: CGFloat) -> Int {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              width > 0, height > 0 else {
            return max(1, Int(maxPixelSize * maxPixelSize) * 4)
        }
        let scale = min(1, maxPixelSize / max(width, height))
        return max(1, Int(width * scale * height * scale) * 4)
    }

    private static func decodeFrame(_ source: CGImageSource, at index: Int, maxPixelSize: CGFloat) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary)
    }

    private static func frameDelay(_ source: CGImageSource, at index: Int) -> TimeInterval {
        let defaultDelay = 0.1
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return defaultDelay
        }
        let delay = (gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? TimeInterval)
            ?? (gifProperties[kCGImagePropertyGIFDelayTime] as? TimeInterval)
            ?? defaultDelay
        // Browsers render near-zero delays at 100ms; match that so such GIFs don't spin.
        return delay < 0.011 ? defaultDelay : delay
    }

    /// `UIImage.animatedImage(with:duration:)` spaces frames evenly, but GIF frames carry
    /// individual delays. GIF delays are centisecond-based, so expanding frames onto their
    /// common centisecond grid reproduces per-frame timing exactly — repeated entries
    /// reference the same decoded frame, costing pointers rather than bitmaps.
    private static func animatedImage(frames: [UIImage], delays: [TimeInterval]) -> UIImage? {
        let centiseconds = delays.map { max(1, Int(($0 * 100).rounded())) }
        let totalDuration = Double(centiseconds.reduce(0, +)) / 100
        let unit = centiseconds.reduce(centiseconds[0], gcd)
        let expandedCount = centiseconds.reduce(0) { $0 + $1 / unit }
        guard expandedCount <= maxExpandedFrameEntries else {
            // Pathological delay mix; give up per-frame timing and space frames evenly.
            return UIImage.animatedImage(with: frames, duration: totalDuration)
        }

        var expanded: [UIImage] = []
        expanded.reserveCapacity(expandedCount)
        for (frame, duration) in zip(frames, centiseconds) {
            expanded.append(contentsOf: repeatElement(frame, count: duration / unit))
        }
        return UIImage.animatedImage(with: expanded, duration: totalDuration)
    }

    private static func gcd(_ lhs: Int, _ rhs: Int) -> Int {
        var (first, second) = (lhs, rhs)
        while second != 0 {
            (first, second) = (second, first % second)
        }
        return first
    }
}
