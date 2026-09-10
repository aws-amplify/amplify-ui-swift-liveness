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

@MainActor
final class FaceLivenessDetectionViewModelGeometryTests: XCTestCase {
    private var viewModel: FaceLivenessDetectionViewModel!
    private var presenter: MockLivenessViewControllerPresenter!

    private let videoOval = LivenessGeometryFixture.videoOval
    private let videoSize = LivenessGeometryFixture.videoSize

    override func setUp() {
        resetFixture()
    }

    /// Fresh view model and presenter for tests that walk several scenarios.
    private func resetFixture() {
        presenter = MockLivenessViewControllerPresenter()
        viewModel = LivenessGeometryFixture.makeViewModel(presenter: presenter)
    }

    override func tearDown() {
        viewModel = nil
        presenter = nil
    }

    private func expectedOval(forPreviewWidth width: CGFloat) -> CGRect {
        LivenessGeometryFixture.expectedOval(forPreviewWidth: width)
    }

    // MARK: - First draw

    /// Given: A view model whose camera rect was fitted to a phone-portrait viewport
    /// When: The oval is drawn
    /// Then: The oval is scaled by the preview-to-video width ratio
    func testDrawOvalOnPhonePortrait() {
        let previewRect = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 393, height: 852))
        viewModel.cameraViewRect = previewRect
        viewModel.livenessState.beginRecording()

        drawOvalAndWaitUntilDisplayed(viewModel)

        let expected = expectedOval(forPreviewWidth: previewRect.width)
        assertRect(viewModel.ovalRect, expected)
        XCTAssertEqual(presenter.drawnOvalRects.count, 1)
        assertRect(presenter.drawnOvalRects[0], expected)
    }

    /// Given: A view model whose camera rect was fitted to the near-square 904x640 viewport
    /// When: The oval is drawn
    /// Then: The oval is unscaled and fits inside the viewport
    func testDrawOvalOnNearSquareViewportFitsTheViewport() {
        let viewport = CGSize(width: 904, height: 640)
        viewModel.cameraViewRect = LivenessPreviewGeometry.previewRect(fittingIn: viewport)
        viewModel.livenessState.beginRecording()

        drawOvalAndWaitUntilDisplayed(viewModel)

        assertRect(viewModel.ovalRect, videoOval)
        XCTAssertLessThanOrEqual(viewModel.ovalRect.maxY, viewport.height)
    }

    /// Given: A view model whose camera rect is empty
    /// When: The oval is drawn, and again once a real rect exists
    /// Then: Nothing is drawn and the state stays `.recording(ovalDisplayed: false)` until the
    ///       real rect arrives
    func testDrawOvalIsDeferredUntilGeometryExists() {
        viewModel.cameraViewRect = .zero
        viewModel.livenessState.beginRecording()

        viewModel.drawOval(onComplete: { XCTFail("must not complete without geometry") })

        XCTAssertEqual(viewModel.ovalRect, .zero)
        XCTAssertTrue(presenter.drawnOvalRects.isEmpty)
        XCTAssertEqual(viewModel.livenessState.state, .recording(ovalDisplayed: false))

        // a layout pass supplies a rect, and the next detection draws
        let previewRect = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 640, height: 904))
        viewModel.cameraViewRect = previewRect
        drawOvalAndWaitUntilDisplayed(viewModel)

        assertRect(viewModel.ovalRect, expectedOval(forPreviewWidth: previewRect.width))
        XCTAssertEqual(presenter.drawnOvalRects.count, 1)
    }

    // MARK: - Redraw on resize

    /// Given: An oval already drawn for a phone-portrait viewport
    /// When: The camera rect changes
    /// Then: The oval is recomputed for the new rect and redrawn
    func testRedrawAfterResize() {
        let before = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 393, height: 852))
        viewModel.cameraViewRect = before
        viewModel.livenessState.beginRecording()
        drawOvalAndWaitUntilDisplayed(viewModel)
        assertRect(viewModel.ovalRect, expectedOval(forPreviewWidth: before.width))

        let after = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 904, height: 640))
        viewModel.cameraViewRect = after
        viewModel.redrawOvalForCurrentCameraViewRect()

        let expected = expectedOval(forPreviewWidth: after.width)
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
        drawOvalAndWaitUntilDisplayed(viewModel)

        viewModel.redrawOvalForCurrentCameraViewRect()

        XCTAssertEqual(presenter.drawnOvalRects.count, 1)
    }

    /// Given: A camera rect sized from the 820x1180 screen, hosted in a 640x904 window
    /// When: The first layout pass supplies the real size
    /// Then: The oval is rebuilt for the real size
    func testStaleInitialFrameIsCorrectedOnFirstLayoutPass() {
        // setupAVLayer, off the pre-layout frame
        let atViewDidLoad = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 820, height: 1180))
        viewModel.cameraViewRect = atViewDidLoad
        viewModel.livenessState.beginRecording()
        drawOvalAndWaitUntilDisplayed(viewModel)
        assertRect(viewModel.ovalRect, expectedOval(forPreviewWidth: 820))

        // first real layout pass
        let atFirstLayout = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 640, height: 904))
        viewModel.cameraViewRect = atFirstLayout
        viewModel.redrawOvalForCurrentCameraViewRect()

        assertRect(viewModel.ovalRect, expectedOval(forPreviewWidth: 640))
        XCTAssertEqual(presenter.drawnOvalRects.count, 2)
        XCTAssertLessThanOrEqual(atFirstLayout.maxX, 640)
        XCTAssertLessThanOrEqual(atFirstLayout.maxY, 904)
    }

    /// Given: A 640x904 window with a camera rect seeded from a stale screen width, 820 or 1180
    /// When: The oval is drawn through the stale rect, then the rect is refitted and redrawn
    /// Then: The 1180pt rect overhangs the sides before the refit; both fit the window after it
    func testSideClippingFromAStaleWidthIsRemovedByTheRefit() {
        let window = CGSize(width: 640, height: 904)

        func onScreenOval() -> CGRect {
            viewModel.ovalRect.offsetBy(dx: viewModel.cameraViewRect.minX, dy: viewModel.cameraViewRect.minY)
        }
        func sideOverhang(_ rect: CGRect) -> CGFloat {
            max(0, -rect.minX) + max(0, rect.maxX - window.width)
        }

        for staleWidth: CGFloat in [820, 1180] {
            resetFixture()
            let label = "stale width \(Int(staleWidth))"

            // seeded from the screen, re-centered in the window
            let staleHeight = staleWidth / 3 * 4
            viewModel.cameraViewRect = CGRect(
                x: (window.width - staleWidth) / 2,
                y: (window.height - staleHeight) / 2,
                width: staleWidth,
                height: staleHeight
            )
            viewModel.livenessState.beginRecording()
            drawOvalAndWaitUntilDisplayed(viewModel)

            if staleWidth > 820 {
                XCTAssertGreaterThan(sideOverhang(onScreenOval()), 0, "\(label) must overhang the sides before the refit")
            } else {
                XCTAssertEqual(sideOverhang(onScreenOval()), 0, accuracy: 0.0001, "\(label) must not overhang the sides")
            }

            // first real layout pass
            viewModel.cameraViewRect = LivenessPreviewGeometry.previewRect(fittingIn: window)
            viewModel.redrawOvalForCurrentCameraViewRect()

            let oval = onScreenOval()
            XCTAssertEqual(presenter.drawnOvalRects.count, 2, "\(label) must redraw once")
            XCTAssertEqual(sideOverhang(oval), 0, accuracy: 0.0001, "\(label) must not overhang after the refit")
            XCTAssertGreaterThanOrEqual(oval.minY, 0, "\(label) must not overhang the top")
            XCTAssertLessThanOrEqual(oval.maxY, window.height, "\(label) must not overhang the bottom")
            assertRect(viewModel.ovalRect, expectedOval(forPreviewWidth: 640), label)
        }
    }

    // MARK: - When a redraw must be refused

    /// Given: A view model that has not displayed an oval yet
    /// When: The camera rect changes
    /// Then: Nothing is drawn; the first draw belongs to `drawOval`
    func testRedrawIsRefusedBeforeTheOvalIsDisplayed() {
        viewModel.cameraViewRect = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 904, height: 640))

        viewModel.redrawOvalForCurrentCameraViewRect()

        XCTAssertEqual(viewModel.ovalRect, .zero)
        XCTAssertTrue(presenter.drawnOvalRects.isEmpty)

        viewModel.livenessState.beginRecording()
        viewModel.cameraViewRect = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 640, height: 904))

        viewModel.redrawOvalForCurrentCameraViewRect()

        XCTAssertEqual(viewModel.livenessState.state, .recording(ovalDisplayed: false))
        XCTAssertEqual(viewModel.ovalRect, .zero)
        XCTAssertTrue(presenter.drawnOvalRects.isEmpty)
    }

    /// Given: An oval on screen and a check in each terminal or post-challenge state
    /// When: The camera rect changes
    /// Then: Nothing is redrawn and the oval rect is left alone
    func testRedrawIsRefusedInTerminalStates() {
        let terminalStates: [LivenessStateMachine.State] = [
            .completedDisplayingFreshness,
            .completedNoLightCheck,
            .awaitingDisconnectEvent,
            .disconnectEventReceived,
            .completed,
            .encounteredUnrecoverableError(.userCancelled),
            .encounteredUnrecoverableError(.viewResignation)
        ]

        for state in terminalStates {
            resetFixture()
            let before = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 393, height: 852))
            viewModel.cameraViewRect = before
            viewModel.livenessState.beginRecording()
            drawOvalAndWaitUntilDisplayed(viewModel)
            let drawnOval = viewModel.ovalRect

            viewModel.livenessState = LivenessStateMachine(state: state)
            viewModel.cameraViewRect = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 904, height: 640))
            viewModel.redrawOvalForCurrentCameraViewRect()

            XCTAssertEqual(presenter.drawnOvalRects.count, 1, "\(state) must not redraw")
            XCTAssertEqual(viewModel.ovalRect, drawnOval, "\(state) must leave the oval rect alone")
        }
    }

    /// Given: An oval on screen and an empty camera rect
    /// When: A redraw is requested for the empty rect, then again for a real rect
    /// Then: The empty rect draws nothing and keeps the oval; the real rect is redrawn
    func testRedrawWithAnEmptyCameraRectKeepsTheOvalAndRecovers() {
        let before = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 640, height: 904))
        viewModel.cameraViewRect = before
        viewModel.livenessState.beginRecording()
        drawOvalAndWaitUntilDisplayed(viewModel)
        let drawnOval = viewModel.ovalRect

        viewModel.cameraViewRect = .zero
        viewModel.redrawOvalForCurrentCameraViewRect()

        XCTAssertEqual(presenter.drawnOvalRects.count, 1, "an empty rect must not draw")
        XCTAssertEqual(viewModel.ovalRect, drawnOval, "the oval on screen must be kept")
        XCTAssertNotEqual(viewModel.ovalRect, .zero)

        let after = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 904, height: 640))
        viewModel.cameraViewRect = after
        viewModel.redrawOvalForCurrentCameraViewRect()

        let expected = expectedOval(forPreviewWidth: after.width)
        XCTAssertEqual(presenter.drawnOvalRects.count, 2, "the next real rect must be drawn")
        assertRect(viewModel.ovalRect, expected)
        assertRect(presenter.drawnOvalRects[1], expected)
    }
}
