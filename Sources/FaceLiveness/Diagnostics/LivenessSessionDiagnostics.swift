//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import CoreVideo
import Amplify
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

/// One session's diagnostic lines, none per frame. Hooks arrive on several queues, so state is
/// behind one lock and logging happens outside it.
final class LivenessSessionDiagnostics: @unchecked Sendable {
    /// Runs `work` after `delay`, never synchronously, and returns a handle that cancels it.
    typealias Scheduler = (_ delay: TimeInterval, _ work: @escaping () -> Void) -> () -> Void

    static let logCategory = "Liveness"
    static let faceDetectionWatchdogTimeout: TimeInterval = 10
    /// How many frames a new face count or oval position must hold before it is logged.
    static let debounceFrames = 3
    static let distanceReportDelta: Float = 0.05
    static let targetFrameWidth = 480
    static let targetFrameHeight = 640

    static let mainQueueScheduler: Scheduler = { delay, work in
        let item = DispatchWorkItem(block: work)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        return { item.cancel() }
    }

    let sessionID: String
    private let region: String?
    private let deviceInfo: LivenessDeviceInfo
    private let logger: () -> Logger
    private let clock: () -> Int
    private let scheduler: Scheduler
    private let lock = NSLock()
    private var state = State()

    init(
        sessionID: String,
        region: String? = nil,
        deviceInfo: LivenessDeviceInfo,
        // looked up when logging rather than cached, as Amplify asks
        logger: @escaping () -> Logger = { Amplify.Logging.logger(forCategory: LivenessSessionDiagnostics.logCategory) },
        clock: @escaping () -> Int = { Int(ProcessInfo.processInfo.systemUptime * 1_000) },
        scheduler: @escaping Scheduler = LivenessSessionDiagnostics.mainQueueScheduler
    ) {
        self.sessionID = sessionID
        self.region = region
        self.deviceInfo = deviceInfo
        self.logger = logger
        self.clock = clock
        self.scheduler = scheduler
    }

    // MARK: - Session lifecycle

    /// `attempt` is nil when the session couldn't be started, so no attempt was counted.
    func onSessionStartRequested(attempt: Int?, codec: String, preCheckEnabled: Bool) {
        record { _ in
            [.sessionStarting(
                sessionID: sessionID,
                attempt: attempt,
                deviceInfo: deviceInfo,
                codec: codec,
                preCheckEnabled: preCheckEnabled,
                region: region
            )]
        }
    }

    func onSessionReady(_ configuration: FaceLivenessSession.SessionConfiguration, challengeID: String) {
        let challengeType = configuration.colorChallenge == nil ? "FaceMovementChallenge" : "FaceMovementAndLightChallenge"
        let ovalMatchChallenge = configuration.ovalMatchChallenge

        record { state in
            state.faceDetectionThreshold = Float(ovalMatchChallenge.faceDetectionThreshold)
            state.faceDistanceThreshold = Float(ovalMatchChallenge.face.distanceThreshold)
            return [.sessionReady(
                sessionID: sessionID,
                challengeType: challengeType,
                challengeID: challengeID,
                faceDetectionThreshold: Float(ovalMatchChallenge.faceDetectionThreshold),
                targetIouThreshold: Float(ovalMatchChallenge.oval.iouThreshold),
                ovalFitTimeout: ovalMatchChallenge.oval.ovalFitTimeout
            )]
        }
    }

    func onCameraBound(facing: String) {
        record { state in
            guard !state.cameraBoundLogged else { return [] }
            state.cameraBoundLogged = true
            return [.cameraBound(sessionID: sessionID, facing: facing)]
        }
    }

    func onCameraPermissionDenied(status: String) {
        record { state in
            guard !state.cameraPermissionDeniedLogged else { return [] }
            state.cameraPermissionDeniedLogged = true
            return [.cameraPermissionDenied(sessionID: sessionID, status: status)]
        }
    }

    /// The check has taken over the camera. Starts the watchdog, so a camera that never delivers a
    /// frame is reported too.
    func onCheckStarted() {
        record { state in
            if state.checkStartedAt == nil {
                state.checkStartedAt = clock()
            }
            startWatchdogIfNeeded(&state)
            return []
        }
    }

    func onInitialFaceDetectedSent() {
        record { state in
            guard !state.initialFaceDetectedLogged else { return [] }
            state.initialFaceDetectedLogged = true
            state.phase = max(state.phase, .ovalFit)
            let now = clock()
            return [.initialFaceDetected(
                sessionID: sessionID,
                elapsedSinceFirstFrameMs: state.firstFrameAt.map { now - $0 } ?? 0,
                elapsedSinceCheckStartMs: state.checkStartedAt.map { now - $0 }
            )]
        }
    }

    /// Called for every color displayed; only the first is logged.
    func onColorDisplayed() {
        record { state in
            state.phase = .colorSequence
            guard !state.colorSequenceStartedLogged else { return [] }
            state.colorSequenceStartedLogged = true
            return [.colorSequenceStarted(sessionID: sessionID)]
        }
    }

    /// Frames analyzed after the challenge no longer count.
    func onChallengeCompleted() {
        record { state in
            guard !state.challengeCompletedLogged else { return [] }
            state.challengeCompletedLogged = true
            return [.challengeCompleted(sessionID: sessionID, framesAnalyzed: state.framesAnalyzed, phase: state.phase)]
        }
    }

    /// The detector was removed. Ends a session the check didn't finish; covering the detector with
    /// another screen counts as removal, since that stops its camera.
    func onTeardown() {
        record { state in endSession(&state) }
    }

    /// Logs the session summary once; nothing is recorded after it.
    private func endSession(_ state: inout State) -> [LivenessDiagnosticEvent] {
        state.destroyed = true
        cancelWatchdog(&state)
        let iouSamples = state.iouSamples
        return [.sessionEnded(
            sessionID: sessionID,
            framesAnalyzed: state.framesAnalyzed,
            faceEverDetected: state.faceEverDetected,
            ovalEverMatched: state.ovalEverMatched,
            ovalPositionChanges: state.ovalPositionChanges,
            // derived rather than counted, so it can't drift from the sample count
            challengeFrames: state.ovalEverMatched ? state.framesAnalyzed - state.framesAnalyzedAtFirstMatch + 1 : 0,
            challengeFramesWithFace: iouSamples,
            challengeMinIou: iouSamples == 0 ? 0 : Float(state.lowestIou),
            challengeMeanIou: iouSamples == 0 ? 0 : Float(state.iouSum / Double(iouSamples)),
            analyzeErrors: state.analyzeErrors,
            // the first error says why the session ended
            closeCode: state.terminalCloseCode ?? (state.completed ? "NORMAL" : "DISPOSED"),
            framesDropped: state.framesDropped
        )]
    }

    // MARK: - Errors

    /// Records what caused `error`, for the SessionError reported if the check ends with it.
    func noteCause(_ cause: Error, for error: LivenessStateMachine.LivenessError) {
        noteCause(Self.describeCauses(cause), for: error)
    }

    func noteCause(_ cause: String?, for error: LivenessStateMachine.LivenessError) {
        guard let cause else { return }
        record { state in
            if state.pendingCauses[error.code] == nil {
                state.pendingCauses[error.code] = cause
            }
            return []
        }
    }

    /// Called with every check state before observers see it, so an error is logged before the
    /// host's completion handler runs. A final state ends the session.
    func onCheckStateChanged(_ checkState: LivenessStateMachine.State) {
        switch checkState {
        case .completed:
            record { state in
                state.completed = true
                return endSession(&state)
            }
        case .encounteredUnrecoverableError(let error):
            record { state in
                let cause = state.pendingCauses[error.code]
                let events = sessionError(
                    &state,
                    hostError: error.hostError,
                    cause: cause,
                    closeCode: error.diagnosticCloseCode,
                    reason: error.diagnosticName
                )
                return events + endSession(&state)
            }
        default:
            return
        }
    }

    /// Wraps the service's exception handler, so the error is logged before the host gets it.
    func recordingServiceExceptions(
        forwardingTo host: @escaping (FaceLivenessSessionError) -> Void
    ) -> (FaceLivenessSessionError) -> Void {
        return { [weak self] error in
            self?.onServiceException(error)
            host(error)
        }
    }

    func onServiceException(_ error: FaceLivenessSessionError) {
        let reason = "service.\(error.diagnosticName)"
        record { state in
            guard state.reportedErrors.insert(reason).inserted else { return [] }
            // the service closes the socket with a runtime error before reporting it
            return sessionError(
                &state,
                hostError: .hostError(for: error),
                cause: nil,
                closeCode: "RUNTIME_ERROR",
                reason: reason
            )
        }
    }

    // MARK: - Frames

    /// Every camera frame, including the get ready screen's; only the first is logged.
    func onCameraFrame(_ buffer: CVPixelBuffer) {
        record { state in
            guard !state.firstFrameLogged else { return [] }
            state.firstFrameLogged = true
            state.firstFrameAt = clock()
            let width = CVPixelBufferGetWidth(buffer)
            return [.firstFrame(
                sessionID: sessionID,
                width: width,
                height: CVPixelBufferGetHeight(buffer),
                targetWidth: Self.targetFrameWidth,
                targetHeight: Self.targetFrameHeight,
                rowStride: CVPixelBufferGetBytesPerRow(buffer),
                // the check asks for 32-bit BGRA
                expectedRowStride: width * 4,
                format: Self.fourCharCode(CVPixelBufferGetPixelFormatType(buffer))
            )]
        }
    }

    /// A frame reached the check, rather than the get ready screen.
    func onCheckFrameDelivered() {
        record { state in
            guard !state.perFrameClosed else { return [] }
            state.framesDelivered += 1
            return []
        }
    }

    /// A dropped frame is missing from the video too, since detection and recording share a queue.
    func onFrameDropped() {
        record { state in
            guard !state.perFrameClosed else { return [] }
            state.framesDropped += 1
            return []
        }
    }

    func onFrameReport(_ report: FaceDetectionFrameReport) {
        if let failure = report.failure {
            onAnalyzeError(failure)
        } else if !report.usedSessionThreshold {
            onFrameBeforeSessionReady()
        } else {
            onFrameAnalyzed(faceCount: report.faceCount, topScore: report.topScore)
        }
    }

    /// A frame scored before the detector had the session's threshold. Not counted, so it can't
    /// start the watchdog.
    func onFrameBeforeSessionReady() {
        record { state in
            guard !state.perFrameClosed else { return [] }
            state.detectorHasSessionThreshold = false
            guard !state.frameBeforeSessionReadyLogged else { return [] }
            state.frameBeforeSessionReadyLogged = true
            return [.frameBeforeSessionReady]
        }
    }

    /// A face count change is logged once the new count holds for `debounceFrames` frames, so a
    /// score hovering at the threshold doesn't log every frame.
    func onFrameAnalyzed(faceCount: Int, topScore: Float) {
        record { state in
            guard !state.perFrameClosed else { return [] }
            state.detectorHasSessionThreshold = true
            state.framesAnalyzed += 1
            if topScore > state.maxDetectionScore {
                state.maxDetectionScore = topScore
            }
            if faceCount >= 1 {
                state.faceEverDetected = true
                cancelWatchdog(&state)
            } else {
                startWatchdogIfNeeded(&state)
            }

            // the first frame is the baseline
            guard let previous = state.lastFaceCount else {
                state.lastFaceCount = faceCount
                return []
            }
            guard faceCount != previous else {
                state.candidateFaceCount = nil
                state.candidateFaceCountFrames = 0
                return []
            }
            if faceCount == state.candidateFaceCount {
                state.candidateFaceCountFrames += 1
            } else {
                state.candidateFaceCount = faceCount
                state.candidateFaceCountFrames = 1
            }
            guard state.candidateFaceCountFrames >= Self.debounceFrames else { return [] }

            state.lastFaceCount = faceCount
            state.candidateFaceCount = nil
            state.candidateFaceCountFrames = 0
            return [.faceCountChanged(
                sessionID: sessionID,
                from: previous,
                to: faceCount,
                framesAnalyzed: state.framesAnalyzed,
                topScore: topScore,
                phase: state.phase
            )]
        }
    }

    func onAnalyzeError(_ failure: FrameAnalysisFailure) {
        let isFirst = withState { state -> Bool in
            guard !state.perFrameClosed else { return false }
            state.analyzeErrors += 1
            // a device failing on every frame would otherwise log one line per frame
            defer { state.firstAnalyzeErrorLogged = true }
            return !state.firstAnalyzeErrorLogged
        } ?? false
        // built outside the lock, since describing the cause calls into Foundation
        if isFirst {
            emit([.analyzeFailed(sessionID: sessionID, failure: failure)])
        }
    }

    /// Logged once it moves at least `distanceReportDelta` from the last logged value.
    func onFaceDistance(_ distance: Float) {
        guard distance.isFinite else { return }
        record { state in
            guard !state.perFrameClosed else { return [] }
            if let last = state.lastEmittedDistance, abs(distance - last) < Self.distanceReportDelta {
                return []
            }
            state.lastEmittedDistance = distance
            return [.faceDistanceChanged(
                sessionID: sessionID,
                distance: distance,
                faceDistanceThreshold: state.faceDistanceThreshold,
                phase: state.phase
            )]
        }
    }

    /// The face measured against the oval on this frame, which can differ from the instruction
    /// shown. Ignored until the initial face is sent, when the oval fit starts.
    func onOvalMeasurement(_ measurement: OvalMeasurement) {
        record { state in
            guard state.phase >= .ovalFit else { return [] }
            let events = ovalPositionChanged(measurement.position, &state)
            faceIou(measurement.iou, &state)
            return events
        }
    }

    /// Logs a position once it holds for `debounceFrames` frames, since a face on the
    /// match boundary flips on frame-to-frame noise; every change is still counted.
    private func ovalPositionChanged(_ position: FaceOvalPosition, _ state: inout State) -> [LivenessDiagnosticEvent] {
        guard !state.perFrameClosed else { return [] }
        var events: [LivenessDiagnosticEvent] = []
        if position == .matched {
            state.ovalEverMatched = true
            if !state.firstOvalMatchLogged {
                state.firstOvalMatchLogged = true
                state.framesAnalyzedAtFirstMatch = state.framesAnalyzed
                events.append(.firstOvalMatch(sessionID: sessionID, framesAnalyzed: state.framesAnalyzed, phase: state.phase))
            }
        }

        if position != state.lastObservedOvalPosition {
            if state.lastObservedOvalPosition != nil {
                state.ovalPositionChanges += 1
            }
            state.lastObservedOvalPosition = position
        }

        if position == state.lastOvalPosition {
            state.candidateOvalPosition = nil
            state.candidateOvalPositionFrames = 0
            return events
        }

        if position == state.candidateOvalPosition {
            state.candidateOvalPositionFrames += 1
        } else {
            state.candidateOvalPosition = position
            state.candidateOvalPositionFrames = 1
        }
        guard state.candidateOvalPositionFrames >= Self.debounceFrames else { return events }

        let previous = state.lastOvalPosition
        state.lastOvalPosition = position
        state.candidateOvalPosition = nil
        state.candidateOvalPositionFrames = 0
        events.append(.ovalPositionChanged(sessionID: sessionID, from: previous, to: position, phase: state.phase))
        return events
    }

    /// Accumulated for SessionEnded from the first match on; before it the user is still lining up.
    private func faceIou(_ iou: Double, _ state: inout State) {
        guard iou.isFinite, !state.perFrameClosed, state.ovalEverMatched else { return }
        state.iouSum += iou
        state.iouSamples += 1
        state.lowestIou = min(state.lowestIou, iou)
    }

    // MARK: - Watchdog

    /// `provider` is called on the scheduler's queue, main by default.
    func registerGateProvider(_ provider: @escaping () -> GateSnapshot?) {
        _ = withState { state in state.gateProvider = provider }
    }

    /// Logs one snapshot if no face has been found since the watchdog started. Also how tests fire it.
    func emitWatchdogSnapshot() {
        let canFire = withState { state in state.canFireWatchdog } ?? false
        guard canFire else { return }

        // read outside the lock, since it calls into the view model
        let gates = withState { state in state.gateProvider }??()
        record { state in
            guard state.canFireWatchdog else { return [] }
            state.watchdogFired = true
            let now = clock()
            return [.faceDetectionWatchdog(
                sessionID: sessionID,
                elapsedMs: state.watchdogStartedAt.map { now - $0 } ?? Int(Self.faceDetectionWatchdogTimeout * 1_000),
                framesAnalyzed: state.framesAnalyzed,
                maxDetectionScore: state.maxDetectionScore,
                faceDetectionThreshold: state.faceDetectionThreshold,
                analyzeErrors: state.analyzeErrors,
                detectorHasSessionThreshold: state.detectorHasSessionThreshold,
                gates: gates,
                framesDelivered: state.framesDelivered
            )]
        }
    }

    private func startWatchdogIfNeeded(_ state: inout State) {
        guard !state.watchdogStarted, !state.watchdogCancelled, !state.faceEverDetected else { return }
        state.watchdogStarted = true
        state.watchdogStartedAt = clock()
        state.cancelWatchdogTimer = scheduler(Self.faceDetectionWatchdogTimeout) { [weak self] in
            self?.emitWatchdogSnapshot()
        }
    }

    /// The flag, not the cancel handle, is what stops a snapshot that has already started.
    private func cancelWatchdog(_ state: inout State) {
        state.watchdogCancelled = true
        state.cancelWatchdogTimer?()
        state.cancelWatchdogTimer = nil
    }

    // MARK: - Support

    private func sessionError(
        _ state: inout State,
        hostError: FaceLivenessDetectionError,
        cause: String?,
        closeCode: String,
        reason: String
    ) -> [LivenessDiagnosticEvent] {
        cancelWatchdog(&state)
        // the first error is kept, since a later one is a consequence of it
        if state.terminalCloseCode == nil {
            state.terminalCloseCode = closeCode
        }
        return [.sessionError(
            sessionID: sessionID,
            type: hostError.diagnosticName,
            message: hostError.message,
            cause: cause,
            closeCode: closeCode,
            reason: reason
        )]
    }

    /// Runs `body` under the lock, unless the session has ended.
    private func withState<T>(_ body: (inout State) -> T) -> T? {
        lock.lock()
        defer { lock.unlock() }
        return state.destroyed ? nil : body(&state)
    }

    /// Updates the state under the lock, then logs the events it returns outside it.
    private func record(_ update: (inout State) -> [LivenessDiagnosticEvent]) {
        emit(withState(update) ?? [])
    }

    private func emit(_ events: [LivenessDiagnosticEvent]) {
        guard !events.isEmpty else { return }
        let logger = logger()
        for event in events {
            switch event.level {
            case .error: logger.error("Liveness \(event)")
            case .warn: logger.warn("Liveness \(event)")
            case .info: logger.info("Liveness \(event)")
            case .debug: logger.debug("Liveness \(event)")
            case .verbose: logger.verbose("Liveness \(event)")
            case .none: break
            }
        }
    }

    private struct State {
        var destroyed = false
        var completed = false

        var firstFrameLogged = false
        var frameBeforeSessionReadyLogged = false
        var firstAnalyzeErrorLogged = false
        var cameraBoundLogged = false
        var cameraPermissionDeniedLogged = false
        var initialFaceDetectedLogged = false
        var colorSequenceStartedLogged = false
        var challengeCompletedLogged = false
        var firstOvalMatchLogged = false

        var faceDetectionThreshold: Float = 0
        var faceDistanceThreshold: Float = 0
        var firstFrameAt: Int?
        var checkStartedAt: Int?
        var phase = ChallengePhase.preCheck

        var framesDelivered = 0
        var framesDropped = 0
        var framesAnalyzed = 0
        var analyzeErrors = 0
        var maxDetectionScore: Float = 0
        var faceEverDetected = false
        var lastFaceCount: Int?
        var candidateFaceCount: Int?
        var candidateFaceCountFrames = 0
        /// Whether the last frame the detector scored used the session's threshold; nil before any.
        var detectorHasSessionThreshold: Bool?
        var lastEmittedDistance: Float?

        var lastOvalPosition: FaceOvalPosition?
        var lastObservedOvalPosition: FaceOvalPosition?
        var candidateOvalPosition: FaceOvalPosition?
        var candidateOvalPositionFrames = 0
        var ovalPositionChanges = 0
        var ovalEverMatched = false
        var framesAnalyzedAtFirstMatch = 0
        var iouSum: Double = 0
        var iouSamples = 0
        var lowestIou = Double.greatestFiniteMagnitude

        var terminalCloseCode: String?
        var reportedErrors: Set<String> = []
        var pendingCauses: [UInt8: String] = [:]

        var watchdogStarted = false
        var watchdogStartedAt: Int?
        var watchdogFired = false
        var watchdogCancelled = false
        var cancelWatchdogTimer: (() -> Void)?
        var gateProvider: (() -> GateSnapshot?)?

        /// After the challenge or the first error, frames no longer describe the check.
        var perFrameClosed: Bool { challengeCompletedLogged || terminalCloseCode != nil || destroyed }
        var canFireWatchdog: Bool { !(watchdogFired || watchdogCancelled || destroyed || faceEverDetected) }
    }
}
