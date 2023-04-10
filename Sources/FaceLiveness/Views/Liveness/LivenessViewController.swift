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
    var previewLayer: AVCaptureVideoPreviewLayer!

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
                face.normalize(width: self.view.frame.width, height: self.view.frame.width / 3 * 4)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        layoutSubviews()
    }

    override func viewDidAppear(_ animated: Bool) {
        setupAVLayer()
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

    private func setupAVLayer() {
        let x = view.frame.minX
        let y = view.frame.minY
        let width = view.frame.width
        let height = width / 3 * 4
        let cameraFrame = CGRect(x: x, y: y, width: width, height: height)

        guard let avLayer = viewModel.startCamera(withinFrame: cameraFrame) else {
            DispatchQueue.main.async {
                self.viewModel.livenessState
                    .unrecoverableStateEncountered(.missingVideoPermission)
            }
            return
        }

        avLayer.position = view.center
        self.previewLayer = avLayer
        viewModel.cameraViewRect = previewLayer.frame

        DispatchQueue.main.async {
            self.view.layer.insertSublayer(avLayer, at: 0)
            self.view.layoutIfNeeded()
        }
    }



    func convert(rect: CGRect) -> CGRect {
        let box = previewLayer.layerRectConverted(fromMetadataOutputRect: rect)
        return box
    }

    var runningFreshness = false
    var hasSentClientInformationEvent = false
    var challengeID = UUID().uuidString
    var initialFace: FaceDetection?
    var videoStartTimeStamp: UInt64?
    var faceMatchStartTime: UInt64?
    var faceGuideRect: CGRect?
    var freshnessEventsComplete = false
    var videoSentCount = 0
    var hasSentFinalEvent = false
    var hasSentEmptyFinalVideoEvent = false
    var ovalView: OvalView?


    required init?(coder: NSCoder) { fatalError() }
}

extension _LivenessViewController: FaceLivenessViewControllerPresenter {
    func displaySingleFrame(uiImage: UIImage) {
        DispatchQueue.main.async {
            let imageView = UIImageView(image: uiImage)
            imageView.frame = self.previewLayer.frame
            self.view.addSubview(imageView)
            self.previewLayer.removeFromSuperlayer()
            self.viewModel.stopRecording()
        }
    }

    func displayFreshness(colorSequences: [FaceLivenessSession.DisplayColor]) {
        self.ovalView?.setNeedsDisplay()
        DispatchQueue.main.async {
            self.viewModel.livenessState.displayingFreshness()
        }
        self.freshness.showColorSequences(
            colorSequences,
            width: UIScreen.main.bounds.width,
            height: UIScreen.main.bounds.height,
            view: self.freshnessView,
            onNewColor: { [weak self] colorEvent in
                self?.viewModel.sendColorDisplayedEvent(colorEvent)
            },
            onComplete: { [weak self] in
                guard let self else { return }
                self.freshnessView.removeFromSuperview()

                self.viewModel.handleFreshnessComplete(
                    faceGuide: self.faceGuideRect!
                )
            }
        )
    }

    func drawOvalInCanvas(_ ovalRect: CGRect) {
        DispatchQueue.main.async {
            self.faceGuideRect = ovalRect

            let ovalView = OvalView(
                frame: self.previewLayer.frame,
                ovalFrame: ovalRect
            )
            self.ovalView = ovalView
            ovalView.center = self.previewLayer.position
            self.view.insertSubview(
                ovalView,
                belowSubview: self.freshnessView
            )

            self.ovalRect = ovalRect
            self.ovalExists = true
        }
    }
}


//    func drawOval(with ovalChallenge: FaceLivenessSession.OvalMatchChallenge.Oval) {
//        DispatchQueue.main.async {
////            let _rect = CGRect(
////                x: CGFloat(parameters.centerX - parameters.width / 2),
////                y: CGFloat(parameters.centerY - parameters.height / 2),
////                width: CGFloat(parameters.width),
////                height: CGFloat(parameters.height)
////            )
//
//            let _rect = CGRect(
//                x: ovalChallenge.boundingBox.x,
//                y: ovalChallenge.boundingBox.y,
//                width: ovalChallenge.boundingBox.width,
//                height: ovalChallenge.boundingBox.height
//            )
//
//            let rect = self.normalizeOvalToDisplaySize(_rect)
//
//            self.faceGuideRect = rect
//
//            let ovalView = OvalView(
//                frame: self.previewLayer.frame,
//                ovalFrame: rect
//            )
//            self.ovalView = ovalView
//            ovalView.center = self.previewLayer.position
//
//            self.view.insertSubview(
//                ovalView,
//                belowSubview: self.freshnessView
//            )
//
//            self.ovalRect = rect
//            self.ovalExists = true
//        }
//    }
//    func normalizeOvalToDisplaySize(_ ovalRect: CGRect) -> CGRect {
//        let scaleRatio = viewModel.cameraViewRect.width / 480
//
//        let normalizedOvalRect = CGRect(
//            x: ovalRect.minX * scaleRatio,
//            y: ovalRect.minY * scaleRatio,
//            width: ovalRect.width * scaleRatio,
//            height: ovalRect.height * scaleRatio
//        )
//        return normalizedOvalRect
//    }
//    private func addFaceBoxView() {
//        view.addSubview(faceBoxView)
//        let x = view.frame.minX
//        let y = view.frame.minY
//        let width = view.frame.width
//        let height = width / 3 * 4
//        faceBoxView.frame = CGRect(x: x, y: y, width: width, height: height)
//        faceBoxView.center = view.center
//        faceBoxView.backgroundColor = .clear
//    }
