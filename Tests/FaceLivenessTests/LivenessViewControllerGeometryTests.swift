//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import UIKit
@testable import FaceLiveness

/// Drives `_LivenessViewController`'s layout path with an injected preview layer, so the refit
/// on resize is exercised through UIKit's real `viewDidLayoutSubviews` rather than by calling
/// the view model directly.
///
/// The layer is installed before the view loads, which makes `setupAVLayer` a no-op (it only
/// runs when no layer exists), so no capture session is needed.
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
        // the controller registers itself as the presenter in `init`; observe draws instead
        viewModel.livenessViewControllerDelegate = presenter

        // what `setupAVLayer` does off the pre-layout, screen-sized view
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
    /// Then: Nothing changes and nothing is drawn; the common layout pass is a no-op
    func testLayoutAtTheSameSizeIsANoOp() {
        beginRecordingAndDisplayOval()
        let drawnOval = viewModel.ovalRect

        layout(to: screen)

        assertRect(previewLayer.frame, LivenessPreviewGeometry.previewRect(fittingIn: screen))
        assertRect(viewModel.cameraViewRect, LivenessPreviewGeometry.previewRect(fittingIn: screen))
        XCTAssertEqual(viewModel.ovalRect, drawnOval)
        XCTAssertEqual(presenter.drawnOvalRects.count, 1)
    }

    /// Given: A controller whose layer and camera rect were sized from the 820x1180 screen in
    ///        `viewDidLoad`, hosted in a 640x904 window, with the oval already drawn
    /// When: The first layout pass at the window's real size runs
    /// Then: The layer, the camera rect and the oval are all refitted to the window. Previously
    ///       the layer kept its 820pt width and was only re-centred, overhanging the window by
    ///       90pt per side and 94.67pt top and bottom
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
    /// Then: The empty pass leaves the layer, the camera rect and the oval exactly as they were,
    ///       and the following real pass is picked up normally. Previously the empty pass wrote
    ///       an empty camera rect and drew an empty oval, and no later pass could recover
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
    /// Then: The layer and the camera rect follow the new size, but no oval is drawn; the first
    ///       draw is left to `drawOval` once recording starts
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
}
