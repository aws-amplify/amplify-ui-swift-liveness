//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import UIKit
@testable import FaceLiveness
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

/// Records the oval rects the view model asks to have drawn.
private final class MockLivenessViewControllerPresenter: FaceLivenessViewControllerPresenter {
    var drawnOvalRects: [CGRect] = []

    func drawOvalInCanvas(_ ovalRect: CGRect) {
        drawnOvalRects.append(ovalRect)
    }

    func displayFreshness(colorSequences: [FaceLivenessSession.DisplayColor]) {}
    func stopFreshness() {}
    func displaySingleFrame(uiImage: UIImage) {}
    func completeNoLightCheck() {}
}

@MainActor
final class FaceLivenessDetectionViewModelGeometryTests: XCTestCase {
    private var viewModel: FaceLivenessDetectionViewModel!
    private var presenter: MockLivenessViewControllerPresenter!

    /// The oval the service specifies, in the 480x640 video's coordinate space.
    private let videoOval = CGRect(x: 108, y: 107, width: 264, height: 427)
    private let videoWidth: CGFloat = 480

    override func setUp() {
        let presenter = MockLivenessViewControllerPresenter()
        let viewModel = FaceLivenessDetectionViewModel(
            faceDetector: MockFaceDetector(),
            faceInOvalMatching: .init(instructor: .init()),
            videoChunker: VideoChunker(
                assetWriter: LivenessAVAssetWriter(),
                assetWriterDelegate: VideoChunker.AssetWriterDelegate(),
                assetWriterInput: LivenessAVAssetWriterInput()
            ),
            closeButtonAction: {},
            sessionID: UUID().uuidString,
            isPreviewScreenEnabled: false,
            challengeOptions: .init(
                faceMovementChallengeOption: .init(camera: .front),
                faceMovementAndLightChallengeOption: .init()
            )
        )
        viewModel.livenessViewControllerDelegate = presenter
        viewModel.sessionConfiguration = .faceMovement(
            .init(
                faceDetectionThreshold: 0.7,
                face: .init(
                    distanceThreshold: 0.1,
                    distanceThresholdMax: 0.1,
                    distanceThresholdMin: 0.1,
                    iouWidthThreshold: 0.1,
                    iouHeightThreshold: 0.1
                ),
                oval: .init(
                    boundingBox: .init(
                        x: videoOval.minX,
                        y: videoOval.minY,
                        width: videoOval.width,
                        height: videoOval.height
                    ),
                    heightWidthRatio: 1.618,
                    iouThreshold: 0.1,
                    iouWidthThreshold: 0.1,
                    iouHeightThreshold: 0.1,
                    ovalFitTimeout: 1
                )
            )
        )

        self.presenter = presenter
        self.viewModel = viewModel
    }

    override func tearDown() {
        viewModel = nil
        presenter = nil
    }

    private func assertRect(
        _ rect: CGRect,
        _ expected: CGRect,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(rect.minX, expected.minX, accuracy: 0.0001, "x", file: file, line: line)
        XCTAssertEqual(rect.minY, expected.minY, accuracy: 0.0001, "y", file: file, line: line)
        XCTAssertEqual(rect.width, expected.width, accuracy: 0.0001, "width", file: file, line: line)
        XCTAssertEqual(rect.height, expected.height, accuracy: 0.0001, "height", file: file, line: line)
    }

    private func scaled(_ rect: CGRect, by scale: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX * scale,
            y: rect.minY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
    }

    /// Given: A view model whose camera rect was fitted to a phone-portrait viewport
    /// When: The oval is drawn
    /// Then: The oval is scaled by the preview-to-video width ratio, which is the behaviour
    ///       phones already had
    func testDrawOvalOnPhonePortrait() {
        let previewRect = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 393, height: 852))
        viewModel.cameraViewRect = previewRect
        viewModel.livenessState.beginRecording()

        viewModel.drawOval(onComplete: {})

        let expected = scaled(videoOval, by: previewRect.width / videoWidth)
        assertRect(viewModel.ovalRect, expected)
        XCTAssertEqual(presenter.drawnOvalRects.count, 1)
        assertRect(presenter.drawnOvalRects[0], expected)
    }

    /// Given: A view model whose camera rect was fitted to the near-square 904x640 viewport
    /// When: The oval is drawn
    /// Then: The oval is the service's own coordinates, and it fits inside the viewport rather
    ///       than being taller than the whole window
    func testDrawOvalOnNearSquareViewportFitsTheViewport() {
        let viewport = CGSize(width: 904, height: 640)
        viewModel.cameraViewRect = LivenessPreviewGeometry.previewRect(fittingIn: viewport)
        viewModel.livenessState.beginRecording()

        viewModel.drawOval(onComplete: {})

        assertRect(viewModel.ovalRect, videoOval)
        XCTAssertLessThanOrEqual(viewModel.ovalRect.maxY, viewport.height)
    }

    /// Given: An oval already drawn for a phone-portrait viewport
    /// When: The camera rect changes, as it does when the view is rotated or resized
    /// Then: The oval is recomputed for the new rect and redrawn, instead of staying sized for
    ///       the previous viewport
    func testRedrawAfterResize() {
        let before = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 393, height: 852))
        viewModel.cameraViewRect = before
        viewModel.livenessState.beginRecording()
        viewModel.drawOval(onComplete: {})
        assertRect(viewModel.ovalRect, scaled(videoOval, by: before.width / videoWidth))

        let after = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 904, height: 640))
        viewModel.cameraViewRect = after
        viewModel.redrawOvalForCurrentCameraViewRect()

        let expected = scaled(videoOval, by: after.width / videoWidth)
        assertRect(viewModel.ovalRect, expected)
        XCTAssertEqual(presenter.drawnOvalRects.count, 2)
        assertRect(presenter.drawnOvalRects[1], expected)
    }

    /// Given: An oval already drawn
    /// When: A layout pass happens without the camera rect changing
    /// Then: Nothing is redrawn
    func testRedrawIsSkippedWhenTheRectIsUnchanged() {
        viewModel.cameraViewRect = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 393, height: 852))
        viewModel.livenessState.beginRecording()
        viewModel.drawOval(onComplete: {})

        viewModel.redrawOvalForCurrentCameraViewRect()

        XCTAssertEqual(presenter.drawnOvalRects.count, 1)
    }

    /// Given: A view model that has not drawn an oval yet
    /// When: The camera rect changes
    /// Then: Nothing is drawn, because the oval only appears once the check reaches recording
    func testRedrawIsSkippedBeforeTheOvalExists() {
        viewModel.cameraViewRect = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 904, height: 640))

        viewModel.redrawOvalForCurrentCameraViewRect()

        XCTAssertEqual(viewModel.ovalRect, .zero)
        XCTAssertTrue(presenter.drawnOvalRects.isEmpty)
    }

    /// Given: A view model whose camera rect is still empty, as it is between `viewDidLoad` and
    ///        the first layout pass
    /// When: The oval is drawn
    /// Then: Nothing is drawn and the state stays at `.recording(ovalDisplayed: false)`, so the
    ///       next detection draws the oval once a real rect exists rather than latching a zero one
    func testDrawOvalIsDeferredUntilGeometryExists() {
        viewModel.cameraViewRect = .zero
        viewModel.livenessState.beginRecording()

        viewModel.drawOval(onComplete: {})

        XCTAssertEqual(viewModel.ovalRect, .zero)
        XCTAssertTrue(presenter.drawnOvalRects.isEmpty)
        XCTAssertEqual(viewModel.livenessState.state, .recording(ovalDisplayed: false))

        // the first layout pass supplies a rect, and the next detection draws
        let previewRect = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 640, height: 904))
        viewModel.cameraViewRect = previewRect
        viewModel.drawOval(onComplete: {})

        assertRect(viewModel.ovalRect, scaled(videoOval, by: previewRect.width / videoWidth))
        XCTAssertEqual(presenter.drawnOvalRects.count, 1)
    }

    /// Given: A view whose geometry was captured from the screen-sized default frame in
    ///        `viewDidLoad` (820x1180) while the hosting window is 640x904
    /// When: The first layout pass supplies the real size and the geometry is refitted
    /// Then: The oval is rebuilt for the real size. Previously the preview kept its 820pt width
    ///       and was only re-centred, overhanging the window by 90pt per side.
    func testStaleInitialFrameIsCorrectedOnFirstLayoutPass() {
        // setupAVLayer, off the pre-layout frame
        let atViewDidLoad = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 820, height: 1180))
        viewModel.cameraViewRect = atViewDidLoad
        viewModel.livenessState.beginRecording()
        viewModel.drawOval(onComplete: {})
        assertRect(viewModel.ovalRect, scaled(videoOval, by: 820 / videoWidth))

        // first real layout pass
        let atFirstLayout = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 640, height: 904))
        viewModel.cameraViewRect = atFirstLayout
        viewModel.redrawOvalForCurrentCameraViewRect()

        assertRect(viewModel.ovalRect, scaled(videoOval, by: 640 / videoWidth))
        XCTAssertEqual(presenter.drawnOvalRects.count, 2)
        XCTAssertLessThanOrEqual(atFirstLayout.maxX, 640)
        XCTAssertLessThanOrEqual(atFirstLayout.maxY, 904)
    }
}
