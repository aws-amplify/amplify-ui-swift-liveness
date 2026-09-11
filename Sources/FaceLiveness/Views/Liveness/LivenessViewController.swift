//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import UIKit
import AVFoundation
import Vision
import Amplify
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

final class _LivenessViewController: UIViewController {
    let viewModel: FaceLivenessDetectionViewModel
    var previewLayer: CALayer?

    let faceShapeLayer = CAShapeLayer()
    var ovalExists = false
    var ovalRect: CGRect?
    var freshness = Freshness()
    let freshnessView = FreshnessView()
    var readyForOval = false

    init(
        viewModel: FaceLivenessDetectionViewModel
    ) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        viewModel.livenessViewControllerDelegate = self
        viewModel.normalizeFace = { [weak self] face in
            guard let self = self else { return face }
            return DispatchQueue.main.sync {
                // Normalise against the same (capped) rect the preview and oval use, so the detected
                // face box and the oval never drift apart on wide windows. `cameraViewRect` is set in
                // `setupAVLayer()` before the session (and thus face detection) starts.
                let rect = self.viewModel.cameraViewRect
                return face.normalize(width: rect.width, height: rect.height)
            }
        }
    }
    
    deinit {
        guard let previewLayer = self.previewLayer else { return }
        previewLayer.removeFromSuperlayer()
        (previewLayer as? AVCaptureVideoPreviewLayer)?.session = nil
        self.previewLayer = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        layoutSubviews()
        setupAVLayer()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Re-size/centre the preview against the current bounds — but only before the oval is drawn, so an
        // in-progress check's oval never desyncs from the preview.
        if ovalView == nil {
            updatePreviewFrame()
        }
    }

    private func layoutSubviews() {
        freshnessView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(freshnessView)
        NSLayoutConstraint.activate([
            freshnessView.topAnchor.constraint(equalTo: view.topAnchor),
            freshnessView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            freshnessView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            freshnessView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        freshnessView.clearColors()
    }

    /// The portrait rect for the camera preview, in the view's own (bounds) coordinate space.
    ///
    /// This matches the upstream full-bleed layout — a 3:4 column centred in the view, with the REC/close
    /// controls overlaid on top of it. `_FaceLivenessDetectionView` centres and 3:4-fits the SwiftUI chrome
    /// the same way, so the controls sit over the top of the preview and the preview stays vertically centred.
    /// The only iOS 27 change is capping the width for wide/short windows: the smallest of the view width,
    /// the width that keeps the 3:4 column within the view height, and `.livenessMaxViewportWidth` (540,
    /// a readable-width cap). On a phone the width binds, so the preview is full width and centred
    /// exactly as upstream; only wide/short windows get a narrower centred column.
    private func captureFrame() -> CGRect {
        let width = min(view.bounds.width, view.bounds.height * 3 / 4, .livenessMaxViewportWidth)
        let height = width / 3 * 4
        let origin = CGPoint(x: view.bounds.midX - width / 2, y: view.bounds.midY - height / 2)
        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }

    private func setupAVLayer() {
        guard previewLayer == nil else { return }
        let cameraFrame = captureFrame()

        guard let avLayer = viewModel.configureCamera(withinFrame: cameraFrame) else {
            DispatchQueue.main.async { [weak self] in
                self?.viewModel.livenessState
                    .unrecoverableStateEncountered(.missingVideoPermission)
            }
            return
        }

        avLayer.frame = cameraFrame
        self.previewLayer = avLayer
        viewModel.cameraViewRect = cameraFrame

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.view.layer.insertSublayer(avLayer, at: 0)
            self.view.layoutIfNeeded()

            self.viewModel.startSession()
        }
    }

    /// Re-applies `captureFrame()` to the live preview layer (and `cameraViewRect`) when the bounds change
    /// (e.g. bounds settling after `viewDidLoad`, or a window resize). Guarded to before the oval is drawn
    /// (see `viewDidLayoutSubviews`) so an in-progress check's oval never desyncs.
    private func updatePreviewFrame() {
        guard let previewLayer else { return }
        let cameraFrame = captureFrame()
        guard cameraFrame != previewLayer.frame else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = cameraFrame
        CATransaction.commit()
        viewModel.cameraViewRect = cameraFrame
    }

    var runningFreshness = false
    var hasSentClientInformationEvent = false
    var challengeID = UUID().uuidString
    var initialFace: FaceDetection?
    var videoStartTimeStamp: UInt64?
    var faceMatchStartTime: UInt64?
    var freshnessEventsComplete = false
    var videoSentCount = 0
    var hasSentFinalEvent = false
    var hasSentEmptyFinalVideoEvent = false
    var ovalView: OvalView?


    required init?(coder: NSCoder) { fatalError() }
}

extension _LivenessViewController: FaceLivenessViewControllerPresenter {
    func displaySingleFrame(uiImage: UIImage) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let previewLayer = self.previewLayer else { return }
            let imageView = UIImageView(image: uiImage)
            imageView.frame = previewLayer.frame
            self.view.addSubview(imageView)
            (previewLayer as? AVCaptureVideoPreviewLayer)?.session = nil
            previewLayer.removeFromSuperlayer()
            self.viewModel.stopRecording()
        }
    }

    func displayFreshness(colorSequences: [FaceLivenessSession.DisplayColor]) {
        self.ovalView?.setNeedsDisplay()
        DispatchQueue.main.async { [weak self] in
            self?.viewModel.livenessState.displayingFreshness()
        }
        self.freshness.showColorSequences(
            colorSequences,
            // Size the colour flash to the app window, not the whole physical screen — on a resized
            // iOS 27 window `UIScreen.main.bounds` overshoots the window. `freshnessView` is pinned to
            // the view edges, so `view.bounds` is the correct extent.
            width: view.bounds.width,
            height: view.bounds.height,
            view: self.freshnessView,
            onNewColor: { [weak self] colorEvent in
                self?.viewModel.sendColorDisplayedEvent(colorEvent)
            },
            onComplete: { [weak self] in
                guard let self else { return }
                self.freshnessView.removeFromSuperview()

                self.viewModel.handleFreshnessComplete()
            }
        )
    }

    func stopFreshness() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.freshness.cancel()
            // Clear the colors but leave the view in the hierarchy so that, if the face
            // returns and re-matches, `displayFreshness(colorSequences:)` can restart the
            // flash on the same view.
            self.freshnessView.clearColors()
        }
    }

    func drawOvalInCanvas(_ ovalRect: CGRect) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let previewLayer = self.previewLayer else { return }

            let ovalView = OvalView(
                frame: previewLayer.frame,
                ovalFrame: ovalRect
            )
            self.ovalView = ovalView
            ovalView.center = previewLayer.position
            self.view.insertSubview(
                ovalView,
                belowSubview: self.freshnessView
            )

            self.ovalRect = ovalRect
            self.ovalExists = true
        }
    }
    
    func completeNoLightCheck() {
        self.viewModel.completeNoLightCheck()
    }
}
