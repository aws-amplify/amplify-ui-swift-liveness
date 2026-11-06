//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import AVFoundation
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

extension FaceLivenessDetectionViewModel {
    /// Ends the check with `error`, recording `cause` for the error's SessionError line.
    func fail(_ error: LivenessStateMachine.LivenessError, cause: Error) {
        fail(error, cause: LivenessSessionDiagnostics.describeCauses(cause))
    }

    func fail(_ error: LivenessStateMachine.LivenessError, cause: String?) {
        diagnostics.noteCause(cause, for: error)
        livenessState.unrecoverableStateEncountered(error)
    }

    /// `attempt` is nil when the session couldn't be started, so no attempt was counted.
    func logSessionStarting(attempt: Int?) {
        diagnostics.onSessionStartRequested(
            attempt: attempt,
            codec: LivenessSessionDiagnostics.codecName(videoChunker.assetWriterInput.outputSettings?[AVVideoCodecKey]),
            preCheckEnabled: isPreviewScreenEnabled
        )
    }

    /// Measures a single face for diagnostics, in every state, without touching the check.
    /// Called on the capture queue, like `process(newResult:)`.
    func recordFaceDiagnostics(
        face: DetectedFace,
        normalizedFace: DetectedFace,
        ovalMatchChallenge: FaceLivenessSession.OvalMatchChallenge
    ) {
        diagnostics.onFaceDistance(Float(face.faceDistance))

        let ovalRect = self.ovalRect
        guard !ovalRect.isEmpty else { return }
        let measurement = faceInOvalMatching.measure(
            face: normalizedFace.boundingBox,
            in: ovalRect,
            challengeConfig: ovalMatchChallenge
        )
        diagnostics.onOvalMeasurement(measurement)
    }

    /// The conditions the check needs to find a face, for the face detection watchdog.
    func diagnosticsGateSnapshot() -> GateSnapshot {
        GateSnapshot(
            readyForOval: sessionConfiguration != nil,
            initialFaceDistanceCheckPassed: livenessState.state.hasPassedPreCheck,
            checkState: livenessState.state.diagnosticName,
            captureRunning: captureSession?.captureSession?.isRunning ?? false
        )
    }
}
