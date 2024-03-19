//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SwiftUI
import AVFoundation

fileprivate let videoSize: CGSize = .init(width: 480, height: 640)
fileprivate let defaultNoFitTimeoutInterval: TimeInterval = 7

@MainActor
class FaceLivenessDetectionViewModel: ObservableObject {
    @Published var readyForOval = false
    @Published var isRecording = false
    @Published var livenessState: LivenessStateMachine

    weak var livenessViewControllerDelegate: FaceLivenessViewControllerPresenter?
    let captureSession: LivenessCaptureSession
    var closeButtonAction: () -> Void
    let sessionID: String
    let faceDetector: FaceDetector
    let challengeID: String = UUID().uuidString
    var hasSentFinalVideoEvent = false
    var hasSentFirstVideo = false
    var layerRectConverted: (CGRect) -> CGRect = { $0 }
    var normalizeFace: (DetectedFace) -> DetectedFace = { $0 }
    var provideSingleFrame: ((UIImage) -> Void)?
    var cameraViewRect = CGRect.zero
    var ovalRect = CGRect.zero
    var faceGuideRect: CGRect!
    var faceMatchedTimestamp: UInt64?
    
    init(
        faceDetector: FaceDetector,
        captureSession: LivenessCaptureSession,
        stateMachine: LivenessStateMachine = .init(state: .initial),
        closeButtonAction: @escaping () -> Void,
        sessionID: String
    ) {
        self.closeButtonAction = closeButtonAction
        self.livenessState = stateMachine
        self.sessionID = sessionID
        self.captureSession = captureSession
        self.faceDetector = faceDetector

        self.closeButtonAction = { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                self.stopRecording()
                self.livenessState.unrecoverableStateEncountered(.userCancelled)
            }
        }

        faceDetector.setResultHandler(detectionResultHandler: self)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willResignActive),
            name: UIScene.willDeactivateNotification, object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func willResignActive(_ notification: Notification) {
        guard self.livenessState.state != .initial else { return }
        DispatchQueue.main.async {
            self.stopRecording()
            self.livenessState.unrecoverableStateEncountered(.viewResignation)
        }
    }


    func stopRecording() {
        captureSession.stopRunning()
    }

    func startCamera(withinFrame frame: CGRect) -> CALayer? {
        do {
            let avLayer = try captureSession.startSession(frame: frame)
            DispatchQueue.main.async {
                self.livenessState.checkIsFacePrepared()
            }
            return avLayer
        } catch {
            DispatchQueue.main.async {
                self.livenessState.unrecoverableStateEncountered(
                    self.generateLivenessError(from: error)
                )
            }
            return nil
        }
    }

    func boundingBox(for cgRect: CGRect, relativeTo canvas: CGRect) -> BoundingBox {
        .init(
            x: cgRect.minX / cameraViewRect.width,
            y: cgRect.minY / cameraViewRect.height,
            width: cgRect.width / cameraViewRect.width,
            height: cgRect.height / cameraViewRect.height
        )
    }

    private func generateLivenessError(from captureSessionError: Error) -> LivenessStateMachine.LivenessError {
        guard let captureSessionError = captureSessionError as? LivenessCaptureSessionError else { return .unknown }

        let livenessError: LivenessStateMachine.LivenessError

        switch captureSessionError {
        case LivenessCaptureSessionError.cameraUnavailable,
            LivenessCaptureSessionError.deviceInputUnavailable:

            livenessError = .missingVideoPermission
        case LivenessCaptureSessionError.captureSessionOutputUnavailable,
            LivenessCaptureSessionError.captureSessionInputUnavailable:

            livenessError = .errorWithUnderlyingOSFramework
        default:
            livenessError = .unknown
        }

        return livenessError
    }

    func chunk(initial: Data, current: Data) -> Data {
        let data: Data
        if hasSentFirstVideo {
            data = current
        } else {
            data = initial + current
            hasSentFirstVideo = true
        }
        return data
    }
}

public struct BoundingBox: Codable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(
        x: Double,
        y: Double,
        width: Double,
        height: Double
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}
