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
    private let configurationQueue = DispatchQueue(label: "com.amazonaws.faceliveness.sessionconfiguration", qos: .userInitiated)
    let outputDelegate: AVCaptureVideoDataOutputSampleBufferDelegate
    var captureSession: AVCaptureSession?
    private var deviceInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
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
        self.previewLayer = previewLayer
        return previewLayer
    }
    
    func startSession() throws {
        teardownCurrentSession()
        guard let camera = captureDevice.avCaptureDevice
        else { throw LivenessCaptureSessionError.cameraUnavailable }
        captureSession = AVCaptureSession()
        deviceInput = try AVCaptureDeviceInput(device: camera)
        videoOutput = AVCaptureVideoDataOutput()

        guard let captureSession = captureSession else {
            throw LivenessCaptureSessionError.captureSessionUnavailable
        }
        guard let input = deviceInput, captureSession.canAddInput(input) else {
            throw LivenessCaptureSessionError.captureSessionInputUnavailable
        }
        guard let output = videoOutput, captureSession.canAddOutput(output) else {
            throw LivenessCaptureSessionError.captureSessionOutputUnavailable
        }
        try captureDevice.configure()
        
        configureOutput(output)
        
        configurationQueue.async {
            captureSession.beginConfiguration()
            captureSession.sessionPreset = self.captureDevice.preset
            captureSession.addInput(input)
            captureSession.addOutput(output)
            captureSession.commitConfiguration()
            captureSession.startRunning()
        }
    }

    func stopRunning() {
        teardownCurrentSession()
    }
    
    private func configureOutput(_ output: AVCaptureVideoDataOutput) {
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        output.connections
            .filter(\.isVideoOrientationSupported)
            .forEach {
                $0.videoOrientation = .portrait
            }
        
        output.setSampleBufferDelegate(
            outputDelegate,
            queue: captureQueue
        )
    }

    private func teardownCurrentSession() {
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
        
        if let output = videoOutput {
            captureSession?.removeOutput(output)
            videoOutput = nil
        }
        if let input = deviceInput {
            captureSession?.removeInput(input)
            deviceInput = nil
        }
    
        previewLayer?.removeFromSuperlayer()
        previewLayer?.session = nil
        previewLayer = nil
        captureSession = nil
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
