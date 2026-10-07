//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import AVFoundation
import CoreImage
import UIKit

final class VideoChunker {
    var state = State.pending
    let assetWriter: AVAssetWriter
    let assetWriterDelegate: AssetWriterDelegate
    let assetWriterInput: AVAssetWriterInput
    let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
    var startTimeSeconds: Double?
    var provideSingleFrame: ((UIImage) -> Void)?
    /// Runs `startWriting()` for `prepare()` and `start()`, so it runs once whichever gets there
    /// first. `hasStartedWriting` is only touched on this queue.
    private let writerQueue = DispatchQueue(label: "com.amazonaws.faceliveness.videowriter")
    private var hasStartedWriting = false

    init(
        assetWriter: AVAssetWriter,
        assetWriterDelegate: AssetWriterDelegate,
        assetWriterInput: AVAssetWriterInput
    ) {
        self.assetWriter = assetWriter
        self.assetWriterDelegate = assetWriterDelegate
        self.assetWriterInput = assetWriterInput
        self.pixelBufferAdaptor = .init(assetWriterInput: assetWriterInput)
        self.assetWriterInput.expectsMediaDataInRealTime = true
        self.assetWriter.delegate = assetWriterDelegate
        self.assetWriter.add(assetWriterInput)
    }

    /// Starts the writer ahead of recording. The first `startWriting()` after launch takes about
    /// 0.5–0.8 s; left to `start()`, it blocks the main thread and drops the frames captured
    /// meanwhile, so the video starts that much later than the video start time sent to the
    /// service and every color of the light challenge lands at the wrong point in the video.
    func prepare() {
        writerQueue.async { [weak self] in
            self?.startWritingIfNeeded()
        }
    }

    func start() {
        guard state == .pending else { return }
        // immediate once `prepare()` has run; otherwise waits for it, or starts the writer here
        writerQueue.sync { startWritingIfNeeded() }
        assetWriter.startSession(atSourceTime: .zero)
        state = .writing
    }

    private func startWritingIfNeeded() {
        guard !hasStartedWriting else { return }
        hasStartedWriting = true
        assetWriter.startWriting()
    }

    /// Stops recording. The writer hands the partial last segment to its delegate before it
    /// finishes, so `onFinished` runs once all of the video has been delivered. It runs on the
    /// writer's own queue (or the caller's, if the writer isn't writing), hence `@Sendable`.
    func finish(
        singleFrame: @escaping (UIImage) -> Void,
        onFinished: @escaping @Sendable () -> Void
    ) {
        self.provideSingleFrame = singleFrame
        state = .awaitingSingleFrame

        // explicitly calling `endSession` is unnecessary
        if assetWriter.status == .writing {
            assetWriter.finishWriting(completionHandler: onFinished)
        } else {
            onFinished()
        }
    }

    func consume(_ buffer: CMSampleBuffer) {
        if state == .awaitingSingleFrame {
            guard let imageBuffer = buffer.imageBuffer else { return }
            let singleFrame = singleFrame(from: imageBuffer)
            provideSingleFrame?(singleFrame)
            state = .complete
        }

        guard state == .writing else { return }

        if assetWriterInput.isReadyForMoreMediaData {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(buffer).seconds
            if startTimeSeconds == nil { startTimeSeconds = timestamp }
            guard let startTimeSeconds else {
                return
            }
            let presentationTime = CMTime(seconds: timestamp - startTimeSeconds, preferredTimescale: 600)
            guard let imageBuffer = buffer.imageBuffer else { return }

            pixelBufferAdaptor.append(
                imageBuffer,
                withPresentationTime: presentationTime
            )
        }
    }

    private func singleFrame(from buffer: CVPixelBuffer) -> UIImage {
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let uiImage = UIImage(ciImage: ciImage)
        return uiImage
    }
}
