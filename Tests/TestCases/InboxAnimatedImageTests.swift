//
//  InboxAnimatedImageTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Umair Sharif on 7/23/26.
//

import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import ATTNSDKFramework

final class InboxAnimatedImageTests: XCTestCase {

    // MARK: - GIF detection

    func testIsGIFAcceptsBothGIFHeaderVersions() {
        XCTAssertTrue(InboxAnimatedImage.isGIF(Data("GIF89a".utf8)))
        XCTAssertTrue(InboxAnimatedImage.isGIF(Data("GIF87a".utf8)))
    }

    func testIsGIFAcceptsGeneratedGIFData() {
        XCTAssertTrue(InboxAnimatedImage.isGIF(makeGIFData(frameDelays: [0.1, 0.1])))
    }

    func testIsGIFRejectsNonGIFData() {
        XCTAssertFalse(InboxAnimatedImage.isGIF(Data()))
        XCTAssertFalse(InboxAnimatedImage.isGIF(Data("GIF89".utf8)))
        XCTAssertFalse(InboxAnimatedImage.isGIF(Data("GIF99a".utf8)))
        XCTAssertFalse(InboxAnimatedImage.isGIF(makePNGData()))
    }

    // MARK: - Decoding

    func testDecodesMultiFrameGIFAsAnimatedImage() throws {
        let image = try XCTUnwrap(InboxAnimatedImage.image(from: makeGIFData(frameDelays: [0.1, 0.1, 0.1])))
        XCTAssertNotNil(image.images)
        XCTAssertEqual(uniqueFrameCount(of: image), 3)
        XCTAssertEqual(image.duration, 0.3, accuracy: 0.001)
    }

    func testDecodesSingleFrameGIFAsStaticImage() throws {
        let image = try XCTUnwrap(InboxAnimatedImage.image(from: makeGIFData(frameDelays: [0.1])))
        XCTAssertNil(image.images)
    }

    func testVariableFrameDelaysPreserveRelativeTiming() throws {
        let image = try XCTUnwrap(InboxAnimatedImage.image(from: makeGIFData(frameDelays: [0.1, 0.2])))
        // Delays expand onto their common 0.1s grid: one entry for the first frame, two
        // (references to the same decoded frame) for the second.
        XCTAssertEqual(image.images?.count, 3)
        XCTAssertEqual(uniqueFrameCount(of: image), 2)
        XCTAssertEqual(image.duration, 0.3, accuracy: 0.001)
    }

    func testFrameCapSamplesFramesAndPreservesDuration() throws {
        let data = makeGIFData(frameDelays: Array(repeating: 0.1, count: 20))
        let image = try XCTUnwrap(InboxAnimatedImage.image(from: data, maxFrameCount: 5))
        XCTAssertLessThanOrEqual(uniqueFrameCount(of: image), 5)
        XCTAssertEqual(image.duration, 2.0, accuracy: 0.001)
    }

    func testByteBudgetSamplesFrames() throws {
        // 10×10 RGBA frames are 400 bytes each; a 1KB budget allows at most 2 of the 8.
        let data = makeGIFData(frameDelays: Array(repeating: 0.1, count: 8))
        let image = try XCTUnwrap(InboxAnimatedImage.image(from: data, maxDecodedBytes: 1_024))
        XCTAssertLessThanOrEqual(uniqueFrameCount(of: image), 2)
        XCTAssertEqual(image.duration, 0.8, accuracy: 0.001)
    }

    func testOversizedFramesAreDownsampled() throws {
        let data = makeGIFData(frameDelays: [0.1, 0.1], size: CGSize(width: 100, height: 100))
        let image = try XCTUnwrap(InboxAnimatedImage.image(from: data, maxPixelSize: 50))
        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height), 50)
    }

    func testSmallFramesAreNotUpsampled() throws {
        let data = makeGIFData(frameDelays: [0.1, 0.1], size: CGSize(width: 10, height: 10))
        let image = try XCTUnwrap(InboxAnimatedImage.image(from: data))
        XCTAssertEqual(max(image.size.width, image.size.height), 10)
    }

    func testDecodeRejectsNonGIFData() {
        XCTAssertNil(InboxAnimatedImage.image(from: makePNGData()))
        XCTAssertNil(InboxAnimatedImage.image(from: Data()))
    }

    func testDecodeReturnsNilForCorruptGIFData() {
        XCTAssertNil(InboxAnimatedImage.image(from: Data("GIF89a".utf8) + Data(repeating: 0xFF, count: 32)))
    }

    // MARK: - Loader decode routing

    func testLoaderDecodesGIFAsAnimatedAndPNGAsStatic() async throws {
        let decodedGIF = await InboxImageLoader.decode(makeGIFData(frameDelays: [0.1, 0.1]))
        let gif = try XCTUnwrap(decodedGIF)
        XCTAssertNotNil(gif.images)

        let decodedPNG = await InboxImageLoader.decode(makePNGData())
        let png = try XCTUnwrap(decodedPNG)
        XCTAssertNil(png.images)
    }

    // MARK: - Helpers

    private func makeGIFData(frameDelays: [TimeInterval], size: CGSize = CGSize(width: 10, height: 10)) -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.gif.identifier as CFString,
            frameDelays.count,
            nil
        ) else {
            XCTFail("Failed to create GIF destination")
            return Data()
        }
        for delay in frameDelays {
            let properties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary
            CGImageDestinationAddImage(destination, makeCGImage(size: size), properties)
        }
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    private func makeCGImage(size: CGSize) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        guard let cgImage = image.cgImage else {
            XCTFail("Failed to render CGImage")
            return UIGraphicsImageRenderer(size: size, format: format).image { _ in }.cgImage!
        }
        return cgImage
    }

    private func makePNGData() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10), format: format).pngData { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
    }

    /// Animated images repeat frame references to express per-frame delays; count the
    /// distinct decoded bitmaps.
    private func uniqueFrameCount(of image: UIImage) -> Int {
        guard let frames = image.images else { return 1 }
        return Set(frames.map(ObjectIdentifier.init)).count
    }
}
