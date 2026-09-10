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

    /// Fresh view model and presenter, for tests that walk several scenarios in one body.
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
    /// Then: The oval is scaled by the preview-to-video width ratio, which is the behaviour
    ///       phones already had
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
    /// Then: The oval is the service's own coordinates, and it fits inside the viewport rather
    ///       than being taller than the whole window
    func testDrawOvalOnNearSquareViewportFitsTheViewport() {
        let viewport = CGSize(width: 904, height: 640)
        viewModel.cameraViewRect = LivenessPreviewGeometry.previewRect(fittingIn: viewport)
        viewModel.livenessState.beginRecording()

        drawOvalAndWaitUntilDisplayed(viewModel)

        assertRect(viewModel.ovalRect, videoOval)
        XCTAssertLessThanOrEqual(viewModel.ovalRect.maxY, viewport.height)
    }

    /// Given: A view model whose camera rect is empty, as it is if the hosting view was laid out
    ///        with no area
    /// When: The oval is drawn
    /// Then: Nothing is drawn and the state stays at `.recording(ovalDisplayed: false)`, so the
    ///       next detection draws the oval once a real rect exists rather than latching an empty
    ///       one that would mask the whole preview
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
    /// When: The camera rect changes, as it does when the view is rotated or resized
    /// Then: The oval is recomputed for the new rect and redrawn, instead of staying sized for
    ///       the previous viewport
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

    /// Given: A view that was sized from the screen (820x1180) when the camera was configured,
    ///        while the hosting window is 640x904
    /// When: The first layout pass supplies the real size and the geometry is refitted
    /// Then: The oval is rebuilt for the real size. Previously the preview kept its 820pt width
    ///       and was only re-centred, overhanging the window by 90pt per side.
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

    /// Given: A 640x904 window whose camera rect was seeded from a stale screen width, once with
    ///        the portrait screen width (820) and once with the landscape screen width (1180),
    ///        the way the shipped code sized it before the first layout pass
    /// When: The oval is drawn through the stale rect, and then the rect is refitted to the
    ///       window and the oval redrawn
    /// Then: Through the 1180pt rect the oval overhung both sides of the window, and through the
    ///       820pt rect it did not, which is what distinguished the two stale widths on screen.
    ///       After the refit the oval is fully inside the window in both cases.
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

            // seeded from the screen, re-centred in the window: the shipped behaviour
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

    /// Given: A view model that has not displayed an oval yet, before recording and again in
    ///        `.recording(ovalDisplayed: false)` with real geometry available
    /// When: The camera rect changes
    /// Then: Nothing is drawn. The first draw belongs to `drawOval`, so the redraw path must not
    ///       pre-empt it
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

    /// Given: An oval on screen, and then a check that has moved past the challenge into each of
    ///        the terminal or post-challenge states
    /// When: The camera rect changes
    /// Then: Nothing is redrawn and the oval rect is left alone. There is nothing left to
    ///       reposition, and the freshness view the oval is inserted beneath is gone
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

    /// Given: An oval on screen and a layout pass that reports no area, so the camera rect is
    ///        empty
    /// When: A redraw is requested for the empty rect, and then again once a real rect is back
    /// Then: The empty rect draws nothing and leaves the oval on screen. The real rect is then
    ///       picked up and the oval redrawn for it. Previously the empty pass drew an empty oval,
    ///       which masked the whole preview, and the following pass mistook that empty oval for
    ///       "never drawn" and refused to redraw, so the preview stayed masked for the rest of
    ///       the check
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
