//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import AVFoundation
@testable import FaceLiveness
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

/// Waits for `videoChunker`'s writer to reach `status`, which `prepare()` changes off the
/// calling thread.
func waitForWriter(
    of videoChunker: VideoChunker,
    toReach status: AVAssetWriter.Status,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let reached = XCTNSPredicateExpectation(
        predicate: NSPredicate { _, _ in videoChunker.assetWriter.status == status },
        object: nil
    )
    let result = XCTWaiter.wait(for: [reached], timeout: 5)
    XCTAssertEqual(result, .completed, "writer status is \(videoChunker.assetWriter.status.rawValue)", file: file, line: line)
}

/// A 480x640 BGRA frame presented at `seconds`, the format the camera delivers.
func makeFrame(at seconds: Double) throws -> CMSampleBuffer {
    var pixelBuffer: CVPixelBuffer?
    CVPixelBufferCreate(
        kCFAllocatorDefault,
        480,
        640,
        kCVPixelFormatType_32BGRA,
        [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary,
        &pixelBuffer
    )
    let imageBuffer = try XCTUnwrap(pixelBuffer)

    var formatDescription: CMVideoFormatDescription?
    CMVideoFormatDescriptionCreateForImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: imageBuffer,
        formatDescriptionOut: &formatDescription
    )

    var timing = CMSampleTimingInfo(
        duration: CMTime(value: 1, timescale: 30),
        presentationTimeStamp: CMTime(seconds: seconds, preferredTimescale: 600),
        decodeTimeStamp: .invalid
    )
    var sampleBuffer: CMSampleBuffer?
    CMSampleBufferCreateReadyWithImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: imageBuffer,
        formatDescription: try XCTUnwrap(formatDescription),
        sampleTiming: &timing,
        sampleBufferOut: &sampleBuffer
    )
    return try XCTUnwrap(sampleBuffer)
}

/// Feeds `videoChunker` a third of a second of frames, less than one segment's worth.
func recordFrames(into videoChunker: VideoChunker) throws {
    for frame in 0..<10 {
        videoChunker.consume(try makeFrame(at: Double(frame) / 30))
        // give the encoder time to keep up, as it has with frames arriving from the camera
        Thread.sleep(forTimeInterval: 0.01)
    }
}

/// Events in the order they happened, appended from whichever queue the writer or the service
/// calls back on.
final class EventLog<Event>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Event] = []

    var events: [Event] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ event: Event) {
        lock.lock()
        storage.append(event)
        lock.unlock()
    }
}

/// The JSON `event` sends to the service. AWSPredictionsPlugin keeps the payload internal, so
/// it's read through reflection.
func sentJSON<T>(_ event: LivenessEvent<T>) throws -> [String: Any] {
    let payload = try XCTUnwrap(Mirror(reflecting: event).descendant("payload") as? Data)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
}

/// The first value for `key` at any depth of `json`.
func firstValue(forKey key: String, in json: Any) -> Any? {
    guard let object = json as? [String: Any] else { return nil }
    if let value = object[key] { return value }
    return object.values.lazy.compactMap { firstValue(forKey: key, in: $0) }.first
}
