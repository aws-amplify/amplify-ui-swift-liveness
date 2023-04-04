//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import UIKit
import AVFoundation

final class LivenessCaptureSession {
    private let captureQueue = DispatchQueue(label: "com.amazonaws.faceliveness.cameracapturequeue")
    private let captureDevice: LivenessCaptureDevice
    private let outputDelegate: OutputSampleBufferCapturer
    private var captureSession: AVCaptureSession?

    init(captureDevice: LivenessCaptureDevice, outputDelegate: OutputSampleBufferCapturer) {
        self.captureDevice = captureDevice
        self.outputDelegate = outputDelegate
    }

    func startSession(frame: CGRect) throws -> AVCaptureVideoPreviewLayer {
        let camera = captureDevice()
        let cameraInput = try AVCaptureDeviceInput(device: camera)

        teardownExistingSession(input: cameraInput)
        captureSession = AVCaptureSession()

        guard let captureSession = captureSession else {
            throw LivenessCaptureSessionError.captureSessionUnavailable
        }

        try setupInput(cameraInput, for: captureSession)
        captureSession.sessionPreset = captureDevice.preset

        let videoOutput = AVCaptureVideoDataOutput()
        try setupOutput(videoOutput, for: captureSession)

        captureDevice.configure()

        DispatchQueue.global().async {
            captureSession.startRunning()
        }

        let previewLayer = previewLayer(
            frame: frame,
            for: captureSession
        )

        videoOutput.setSampleBufferDelegate(
            outputDelegate,
            queue: captureQueue
        )

        return previewLayer
    }

    private func teardownExistingSession(input: AVCaptureDeviceInput) {
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
            captureSession?.removeInput(input)
        }
    }

    private func setupInput(
        _ input: AVCaptureDeviceInput,
        for captureSession: AVCaptureSession
    ) throws {
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        } else {
            throw LivenessCaptureSessionError.captureSessionInputUnavailable
        }
    }

    private func setupOutput(
        _ output: AVCaptureVideoDataOutput,
        for captureSession: AVCaptureSession
    ) throws {
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        output.connections
            .filter(\.isVideoOrientationSupported)
            .forEach {
                $0.videoOrientation = .portrait
        }

        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        } else {
            throw LivenessCaptureSessionError.captureSessionOutputUnavailable
        }
    }

    private func previewLayer(
        frame: CGRect,
        for captureSession: AVCaptureSession
    ) -> AVCaptureVideoPreviewLayer {
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        previewLayer.frame = frame
        return previewLayer
    }
}
