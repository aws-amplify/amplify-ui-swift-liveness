//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import UIKit
@testable import FaceLiveness

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

    private func drawOvalOnController(_ oval: CGRect) throws -> OvalView {
        viewController.drawOvalInCanvas(oval)
        let drawn = expectation(description: "oval view added on main")
        DispatchQueue.main.async { drawn.fulfill() }
        wait(for: [drawn], timeout: 1)
        return try XCTUnwrap(viewController.ovalView)
    }

    /// Given: A controller laid out in a 640x904 window, taller than the 3:4 preview
    /// When: The oval is drawn
    /// Then: The overlay covers the whole view and the oval sits at the same spot on screen
    ///       as before, offset by the preview's origin
    func testOvalOverlayCoversTheWholeView() throws {
        layout(to: window)
        let fitted = LivenessPreviewGeometry.previewRect(fittingIn: window)
        let oval = LivenessGeometryFixture.expectedOval(forPreviewWidth: fitted.width)

        let ovalView = try drawOvalOnController(oval)

        assertRect(ovalView.frame, CGRect(origin: .zero, size: window))
        assertRect(ovalView.ovalFrameInView, oval.offsetBy(dx: fitted.minX, dy: fitted.minY))
        XCTAssertGreaterThan(fitted.minY, 0, "the window must leave space above the preview")
    }

    /// Given: A controller laid out at 640x904 with the oval drawn
    /// When: The window grows to 640x1000, which moves the preview down without changing its
    ///       width, so the oval isn't redrawn
    /// Then: The overlay still covers the whole view and the cut-out moves with the preview
    func testOvalOverlayFollowsAResizeThatOnlyMovesThePreview() throws {
        layout(to: window)
        let fitted = LivenessPreviewGeometry.previewRect(fittingIn: window)
        let oval = LivenessGeometryFixture.expectedOval(forPreviewWidth: fitted.width)
        let ovalView = try drawOvalOnController(oval)

        let taller = CGSize(width: window.width, height: 1000)
        layout(to: taller)

        let moved = LivenessPreviewGeometry.previewRect(fittingIn: taller)
        XCTAssertEqual(moved.width, fitted.width, "the preview's width must not change")
        XCTAssertGreaterThan(moved.minY, fitted.minY, "the preview must move down")
        XCTAssertTrue(viewController.ovalView === ovalView, "the oval isn't redrawn")
        assertRect(ovalView.frame, CGRect(origin: .zero, size: taller))
        assertRect(ovalView.ovalFrameInView, oval.offsetBy(dx: moved.minX, dy: moved.minY))
    }

    /// Given: A controller whose oval is drawn during a layout pass with no area
    /// When: The view is laid out at its size again
    /// Then: The overlay covers the whole view, with the cut-out where the preview is
    func testOvalDrawnDuringALayoutPassWithNoAreaAppearsOnceTheViewHasArea() throws {
        layout(to: window)
        let fitted = LivenessPreviewGeometry.previewRect(fittingIn: window)
        let oval = LivenessGeometryFixture.expectedOval(forPreviewWidth: fitted.width)

        layout(to: .zero)
        let ovalView = try drawOvalOnController(oval)
        layout(to: window)

        assertRect(ovalView.frame, CGRect(origin: .zero, size: window))
        assertRect(ovalView.ovalFrameInView, oval.offsetBy(dx: fitted.minX, dy: fitted.minY))
    }

    /// Given: A controller showing the face guide during the freshness check
    /// When: The check completes
    /// Then: The guide is removed, so "Verifying" and the final frame show on black
    func testFaceGuideIsRemovedWhenTheCheckCompletes() throws {
        for completed in [LivenessStateMachine.State.completedDisplayingFreshness, .completedNoLightCheck] {
            layout(to: window)
            viewModel.livenessState = LivenessStateMachine(state: .displayingFreshness)
            let ovalView = try drawOvalOnController(.init(x: 100, y: 100, width: 200, height: 300))
            XCTAssertNotNil(ovalView.superview, "\(completed)")

            viewModel.livenessState = LivenessStateMachine(state: completed)
            let removed = expectation(description: "guide removed on main")
            DispatchQueue.main.async { removed.fulfill() }
            wait(for: [removed], timeout: 1)

            XCTAssertNil(viewController.ovalView, "\(completed)")
            XCTAssertNil(ovalView.superview, "\(completed)")
        }
    }
}
