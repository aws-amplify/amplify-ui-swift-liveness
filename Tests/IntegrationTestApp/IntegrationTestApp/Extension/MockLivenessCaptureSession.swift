//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import UIKit
import AVFoundation
@testable import FaceLiveness

final class MockLivenessCaptureSession: LivenessCaptureSession {
    private var videoRenderView: VideoRenderView?
    private var displayLink: CADisplayLink?
    private var playerItemOutput: AVPlayerItemVideoOutput?
    private let videoFileReadingQueue = DispatchQueue(label: "com.amazonaws.faceliveness.cameracapturequeue")
    private var videoFileFrameDuration = CMTime.invalid
    private let inputFile: URL
    
    init(captureDevice: LivenessCaptureDevice,
         outputDelegate: OutputSampleBufferCapturer,
         inputFile: URL
    ) {
        self.inputFile = inputFile
        super.init(captureDevice: captureDevice, outputDelegate: outputDelegate)
    }
    
    override func stopRunning() {
        videoRenderView?.player?.pause()
        displayLink?.invalidate()
    }
    
    override func configureCamera(frame: CGRect) throws -> CALayer {
        videoRenderView = VideoRenderView(frame: frame)
        let asset = AVAsset(url: inputFile)
        // Setup display link
        let displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))
        displayLink.preferredFramesPerSecond = 0
        displayLink.isPaused = true
        displayLink.add(to: RunLoop.current, forMode: .default)
        captureSession = AVCaptureSession()
        guard let track = asset.tracks(withMediaType: .video).first else {
            throw LivenessCaptureSessionError.captureSessionInputUnavailable
        }
        
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        let settings = [
            String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: settings)
        playerItem.add(output)
        player.actionAtItemEnd = .pause
        player.play()

        self.displayLink = displayLink
        self.playerItemOutput = output
        self.videoRenderView?.player = player
        
        videoFileFrameDuration = track.minFrameDuration
        displayLink.isPaused = false
        guard let previewLayer = videoRenderView?.layer else {
            throw LivenessCaptureSessionError.captureSessionOutputUnavailable
        }
        return previewLayer
    }
    
    @objc
    private func handleDisplayLink(_ displayLink: CADisplayLink) {
        guard let output = playerItemOutput else {
            return
        }
        
        videoFileReadingQueue.async {
            let nextTimeStamp = displayLink.timestamp + displayLink.duration
            let itemTime = output.itemTime(forHostTime: nextTimeStamp)
            guard output.hasNewPixelBuffer(forItemTime: itemTime) else {
                return
            }
            guard let pixelBuffer = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) else {
                return
            }
            
            var sampleBuffer: CMSampleBuffer?
            var formatDescription: CMVideoFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDescription)
            let duration = self.videoFileFrameDuration
            var timingInfo = CMSampleTimingInfo(duration: duration, presentationTimeStamp: itemTime, decodeTimeStamp: itemTime)
            CMSampleBufferCreateForImageBuffer(allocator: nil,
                                               imageBuffer: pixelBuffer,
                                               dataReady: true,
                                               makeDataReadyCallback: nil,
                                               refcon: nil,
                                               formatDescription: formatDescription!,
                                               sampleTiming: &timingInfo,
                                               sampleBufferOut: &sampleBuffer)
            if let sampleBuffer = sampleBuffer {
                self.outputSampleBufferCapturer?.videoChunker.consume(sampleBuffer)
                guard let imageBuffer = sampleBuffer.imageBuffer
                else { return }
                self.outputSampleBufferCapturer?.faceDetector.detectFaces(from: imageBuffer)
            }
        }
    }
}

class VideoRenderView: UIView {
    private var renderLayer: AVPlayerLayer!
    
    var player: AVPlayer? {
        get {
            return renderLayer.player
        }
        set {
            renderLayer.player = newValue
        }
    }
    
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        renderLayer = layer as? AVPlayerLayer
        renderLayer.videoGravity = .resizeAspect
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


