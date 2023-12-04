//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import UIKit
import AVFoundation

class LivenessCaptureSession {
    let captureDevice: LivenessCaptureDevice
    private let captureQueue = DispatchQueue(label: "com.amazonaws.faceliveness.cameracapturequeue")
    let outputDelegate: AVCaptureVideoDataOutputSampleBufferDelegate
    var captureSession: AVCaptureSession?
    
    var outputSampleBufferCapturer: OutputSampleBufferCapturer? {
        return outputDelegate as? OutputSampleBufferCapturer
    }

    init(captureDevice: LivenessCaptureDevice, outputDelegate: AVCaptureVideoDataOutputSampleBufferDelegate) {
        self.captureDevice = captureDevice
        self.outputDelegate = outputDelegate
    }

    func startSession(frame: CGRect) throws -> CALayer {
        try startSession()

        guard let captureSession = captureSession else {
            throw LivenessCaptureSessionError.captureSessionUnavailable
        }
        
        let previewLayer = previewLayer(
            frame: frame,
            for: captureSession
        )

        return previewLayer
    }
    
    func startSession() throws {
        guard let camera = captureDevice.avCaptureDevice
        else { throw LivenessCaptureSessionError.cameraUnavailable }

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

        try captureDevice.configure()

        DispatchQueue.global().async {
            captureSession.startRunning()
        }

        videoOutput.setSampleBufferDelegate(
            outputDelegate,
            queue: captureQueue
        )
    }

    func stopRunning() {
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
    }

    private func teardownExistingSession(input: AVCaptureDeviceInput) {
        stopRunning()
        captureSession?.removeInput(input)
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
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        } else {
            throw LivenessCaptureSessionError.captureSessionOutputUnavailable
        }
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        output.connections
            .filter(\.isVideoOrientationSupported)
            .forEach {
                $0.videoOrientation = .portrait
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
