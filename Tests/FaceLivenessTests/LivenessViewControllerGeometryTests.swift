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

/// Captures the extent handed to `showColorSequences` without running any color timers.
private final class SpyFreshness: Freshness {
    var capturedSize: CGSize?

    override func showColorSequences(
        _ colorSequences: [FaceLivenessSession.DisplayColor],
        width: CGFloat,
        height: CGFloat,
        view: FreshnessView,
        onNewColor: @escaping (Freshness.ColorEvent) -> Void,
        onComplete: @escaping () -> Void
    ) {
        capturedSize = CGSize(width: width, height: height)
    }
}

/// Drives `_LivenessViewController`'s layout path through `viewDidLayoutSubviews` with an
/// injected preview layer, which makes `setupAVLayer` a no-op so no capture session is needed.
@MainActor
final class LivenessViewControllerGeometryTests: XCTestCase {
    private var viewModel: FaceLivenessDetectionViewModel!
    private var presenter: MockLivenessViewControllerPresenter!
    private var viewController: _LivenessViewController!
    private var previewLayer: CALayer!

    private let screen = CGSize(width: 820, height: 1180)
    private let window = CGSize(width: 640, height: 904)

    override func setUp() {
        presenter = MockLivenessViewControllerPresenter()
        viewModel = LivenessGeometryFixture.makeViewModel(presenter: presenter)

        viewController = _LivenessViewController(viewModel: viewModel)
        // the controller registers itself as the presenter in `init`
        viewModel.livenessViewControllerDelegate = presenter

        // what `setupAVLayer` does off the pre-layout frame
        let initialFrame = LivenessPreviewGeometry.previewRect(fittingIn: screen)
        previewLayer = CALayer()
        previewLayer.frame = initialFrame
        viewController.previewLayer = previewLayer
        viewModel.cameraViewRect = initialFrame

        viewController.view.frame = CGRect(origin: .zero, size: screen)
        viewController.view.layoutIfNeeded()
    }

    override func tearDown() {
        viewController = nil
        previewLayer = nil
        viewModel = nil
        presenter = nil
    }

    private func layout(to size: CGSize) {
        viewController.view.frame = CGRect(origin: .zero, size: size)
        viewController.view.layoutIfNeeded()
    }

    private func beginRecordingAndDisplayOval() {
        viewModel.livenessState.beginRecording()
        drawOvalAndWaitUntilDisplayed(viewModel)
    }

    /// Given: A controller whose layer and camera rect were sized from the screen before layout
    /// When: The view is laid out at that same size
    /// Then: Nothing changes and nothing is drawn
    func testLayoutAtTheSameSizeIsANoOp() {
        beginRecordingAndDisplayOval()
        let drawnOval = viewModel.ovalRect

        layout(to: screen)

        assertRect(previewLayer.frame, LivenessPreviewGeometry.previewRect(fittingIn: screen))
        assertRect(viewModel.cameraViewRect, LivenessPreviewGeometry.previewRect(fittingIn: screen))
        XCTAssertEqual(viewModel.ovalRect, drawnOval)
        XCTAssertEqual(presenter.drawnOvalRects.count, 1)
    }

    /// Given: A layer and camera rect sized from the 820x1180 screen, in a 640x904 window
    /// When: The first layout pass at the window's real size runs
    /// Then: The layer, the camera rect and the oval are all refitted to the window
    func testStaleScreenSizedInitialFrameIsCorrectedOnFirstLayoutPass() {
        beginRecordingAndDisplayOval()
        assertRect(viewModel.ovalRect, LivenessGeometryFixture.expectedOval(forPreviewWidth: 820))

        layout(to: window)

        let fitted = LivenessPreviewGeometry.previewRect(fittingIn: window)
        assertRect(previewLayer.frame, fitted)
        assertRect(viewModel.cameraViewRect, fitted)
        XCTAssertGreaterThanOrEqual(previewLayer.frame.minX, 0)
        XCTAssertGreaterThanOrEqual(previewLayer.frame.minY, 0)
        XCTAssertLessThanOrEqual(previewLayer.frame.maxX, window.width)
        XCTAssertLessThanOrEqual(previewLayer.frame.maxY, window.height)

        let expectedOval = LivenessGeometryFixture.expectedOval(forPreviewWidth: 640)
        XCTAssertEqual(presenter.drawnOvalRects.count, 2)
        assertRect(viewModel.ovalRect, expectedOval)
        assertRect(presenter.drawnOvalRects[1], expectedOval)
    }

    /// Given: A controller laid out in a 640x904 window with the oval on screen
    /// When: A layout pass reports a view with no area, and then a real size again
    /// Then: The empty pass leaves the geometry as it was; the following real pass is applied
    func testLayoutPassWithNoAreaKeepsTheLastGeometry() {
        layout(to: window)
        beginRecordingAndDisplayOval()
        let fitted = LivenessPreviewGeometry.previewRect(fittingIn: window)
        let drawnOval = viewModel.ovalRect

        layout(to: .zero)

        assertRect(previewLayer.frame, fitted, "layer must keep its last frame")
        assertRect(viewModel.cameraViewRect, fitted, "camera rect must keep its last value")
        XCTAssertFalse(viewModel.cameraViewRect.isEmpty)
        XCTAssertEqual(viewModel.ovalRect, drawnOval, "oval must be left on screen")
        XCTAssertEqual(presenter.drawnOvalRects.count, 1, "an empty pass must not draw")

        let rotated = CGSize(width: window.height, height: window.width)
        layout(to: rotated)

        let refitted = LivenessPreviewGeometry.previewRect(fittingIn: rotated)
        assertRect(previewLayer.frame, refitted)
        assertRect(viewModel.cameraViewRect, refitted)
        XCTAssertEqual(presenter.drawnOvalRects.count, 2, "the next real pass must redraw")
        assertRect(viewModel.ovalRect, LivenessGeometryFixture.expectedOval(forPreviewWidth: refitted.width))
    }

    /// Given: A controller in a 640x904 window whose check has not yet reached recording
    /// When: The view is resized
    /// Then: The layer and the camera rect follow the new size, but no oval is drawn
    func testResizeBeforeRecordingRefitsWithoutDrawing() {
        layout(to: window)

        let rotated = CGSize(width: window.height, height: window.width)
        layout(to: rotated)

        let refitted = LivenessPreviewGeometry.previewRect(fittingIn: rotated)
        assertRect(previewLayer.frame, refitted)
        assertRect(viewModel.cameraViewRect, refitted)
        XCTAssertTrue(presenter.drawnOvalRects.isEmpty)
        XCTAssertEqual(viewModel.ovalRect, .zero)
    }

    /// Given: A controller laid out in a 640x904 window, then resized
    /// When: A face is normalized from a background queue, as the capture queue does
    /// Then: It is scaled by the fitted rect current at that moment, without blocking on main
    func testNormalizeFaceReadsTheFittedRectOffTheMainQueue() {
        let face = DetectedFace(
            boundingBox: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
            leftEye: .zero, rightEye: .zero, nose: .zero, mouth: .zero, rightEar: .zero, leftEar: .zero,
            confidence: 1
        )

        func normalizedOffMain() -> CGRect {
            var normalized = CGRect.zero
            let done = expectation(description: "normalized on the capture queue")
            let normalize = viewModel.normalizeFace
            DispatchQueue.global(qos: .userInitiated).async {
                normalized = normalize(face).boundingBox
                done.fulfill()
            }
            // the main queue keeps running; a main.sync inside `normalize` would deadlock here
            wait(for: [done], timeout: 1)
            return normalized
        }

        layout(to: window)
        let fitted = LivenessPreviewGeometry.previewRect(fittingIn: window)
        assertRect(
            normalizedOffMain(),
            CGRect(x: fitted.width / 4, y: fitted.height / 4, width: fitted.width / 2, height: fitted.height / 2)
        )

        let rotated = CGSize(width: window.height, height: window.width)
        layout(to: rotated)
        let refitted = LivenessPreviewGeometry.previewRect(fittingIn: rotated)
        assertRect(
            normalizedOffMain(),
            CGRect(x: refitted.width / 4, y: refitted.height / 4, width: refitted.width / 2, height: refitted.height / 2)
        )
    }

    // MARK: - Freshness flash extent

    /// Given: A controller laid out at a window smaller than the screen it launched on
    /// When: The freshness flash is displayed
    /// Then: The flash is sized to the view's bounds, not `UIScreen.main.bounds`
    func testFreshnessFlashIsSizedToTheViewNotTheScreen() {
        let spy = SpyFreshness()
        viewController.freshness = spy
        layout(to: window)

        viewController.displayFreshness(colorSequences: [])

        XCTAssertEqual(spy.capturedSize?.width ?? -1, window.width, accuracy: 0.0001)
        XCTAssertEqual(spy.capturedSize?.height ?? -1, window.height, accuracy: 0.0001)
        XCTAssertNotEqual(spy.capturedSize?.height ?? -1, UIScreen.main.bounds.height, accuracy: 0.0001)
    }

    /// Given: A window resized after the flash extent was first read
    /// When: The freshness flash is displayed again
    /// Then: The flash tracks the view's current bounds
    func testFreshnessFlashTracksTheCurrentBoundsAfterResize() {
        let spy = SpyFreshness()
        viewController.freshness = spy
        layout(to: window)
        viewController.displayFreshness(colorSequences: [])

        let rotated = CGSize(width: window.height, height: window.width)
        layout(to: rotated)
        viewController.displayFreshness(colorSequences: [])

        XCTAssertEqual(spy.capturedSize?.width ?? -1, rotated.width, accuracy: 0.0001)
        XCTAssertEqual(spy.capturedSize?.height ?? -1, rotated.height, accuracy: 0.0001)
    }
}
