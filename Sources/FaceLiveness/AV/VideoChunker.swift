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
    /// Test-only seam (not for production use). Default `nil` = no-op, so the shipped append path
    /// is unchanged. A regression test installs a closure to deterministically park a frame that
    /// has already passed every guard — inside the critical section, holding `writerLock` — so it
    /// can drive `finish(_:)` against an in-flight append and prove the serialization fix for #275.
    /// Kept as a per-instance property (not a global) so each test drives its own chunker.
    var onAppendWillStart: (() -> Void)?

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

    /// Serializes the pixel-buffer append in `consume(_:)` (capture queue) with the writer
    /// shutdown in `finish(_:)` (main actor). Without it, a late frame that already passed the
    /// guards can reach `pixelBufferAdaptor.append(...)` while `finishWriting(...)` is in flight;
    /// the writer's session has ended by then, and AVFoundation raises
    /// `NSInternalInconsistencyException` ("Must start a session … before appending pixel
    /// buffers"), crashing the app (#275). The lock also removes the data race on `state` between
    /// those two contexts.
    ///
    /// A lock, not a serial queue, so `finish(_:)` keeps running synchronously on its caller and
    /// `onFinished` keeps its existing threading. The lock is never held across `startWriting()`
    /// (that stays on `writerQueue`), so the first 0.5–0.8 s start never blocks capture frames.
    private let writerLock = NSLock()
    /// Set under `writerLock` the moment `finish(_:)` begins, and read there in `consume(_:)`.
    /// `finishWriting(...)` is asynchronous and `assetWriter.status` still reads `.writing` during
    /// the window before its completion fires, so a status check alone can't close the race;
    /// dropping every frame once finish has begun does. Only touched under `writerLock`.
    private var finishInitiated = false

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
        writerLock.lock()
        self.provideSingleFrame = singleFrame
        state = .awaitingSingleFrame
        // Close the append window before `finishWriting` starts: once set, any frame still
        // arriving on the capture queue is dropped by `consume(_:)` rather than appended. Holding
        // the lock here guarantees no append is in progress when `finishWriting` is called —
        // exactly Apple's contract ("finish only after every append has returned").
        finishInitiated = true

        // explicitly calling `endSession` is unnecessary
        let isWriting = assetWriter.status == .writing
        if isWriting {
            // `finishWriting(completionHandler:)` returns immediately and runs `onFinished` later
            // on the writer's queue; the delegate's segment callback never touches `writerLock`,
            // so calling it inside the critical section can't deadlock.
            assetWriter.finishWriting(completionHandler: onFinished)
        }
        writerLock.unlock()

        if !isWriting {
            onFinished()
        }
    }

    func consume(_ buffer: CMSampleBuffer) {
        writerLock.lock()
        defer { writerLock.unlock() }

        if state == .awaitingSingleFrame {
            guard let imageBuffer = buffer.imageBuffer else { return }
            let singleFrame = singleFrame(from: imageBuffer)
            provideSingleFrame?(singleFrame)
            state = .complete
        }

        guard state == .writing else { return }

        // Drop the frame once `finish(_:)` has begun, and re-check the writer's own status inside
        // the critical section. `finishInitiated` closes the in-flight `finishWriting` window that
        // a `status == .writing` check alone leaves open (see #275).
        guard !finishInitiated,
              assetWriter.status == .writing,
              assetWriterInput.isReadyForMoreMediaData
        else { return }

        // Test-only seam: runs after every guard passed, inside the critical section, before any
        // append work. No-op in production (nil by default).
        onAppendWillStart?()

        let timestamp = CMSampleBufferGetPresentationTimeStamp(buffer).seconds
        if startTimeSeconds == nil { startTimeSeconds = timestamp }
        guard let startTimeSeconds else {
            return
        }
        let presentationTime = CMTime(seconds: timestamp - startTimeSeconds, preferredTimescale: 600)
        guard let imageBuffer = buffer.imageBuffer else { return }

        // A `false` return means the writer couldn't take the frame (shutting down or failed);
        // dropping it is correct and never crashes, unlike an unchecked append onto an ended
        // session.
        _ = pixelBufferAdaptor.append(
            imageBuffer,
            withPresentationTime: presentationTime
        )
    }

    private func singleFrame(from buffer: CVPixelBuffer) -> UIImage {
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let uiImage = UIImage(ciImage: ciImage)
        return uiImage
    }
}
