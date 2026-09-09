//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import FaceLiveness

final class LivenessPreviewGeometryTests: XCTestCase {
    /// The preview sizing this fix replaced: full viewport width, height derived from it, and
    /// centred vertically. Kept here so the "no change on tall viewports" guarantee is asserted
    /// against the old expression rather than against hand-copied numbers.
    private func legacyPreviewRect(fittingIn viewport: CGSize) -> CGRect {
        let width = viewport.width
        let height = width / 3 * 4
        return CGRect(
            x: (viewport.width - width) / 2,
            y: (viewport.height - height) / 2,
            width: width,
            height: height
        )
    }

    private func assertRect(
        _ rect: CGRect,
        _ expected: CGRect,
        accuracy: CGFloat = 0.0001,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(rect.minX, expected.minX, accuracy: accuracy, "x. \(message)", file: file, line: line)
        XCTAssertEqual(rect.minY, expected.minY, accuracy: accuracy, "y. \(message)", file: file, line: line)
        XCTAssertEqual(rect.width, expected.width, accuracy: accuracy, "width. \(message)", file: file, line: line)
        XCTAssertEqual(rect.height, expected.height, accuracy: accuracy, "height. \(message)", file: file, line: line)
    }

    // MARK: - Tall viewports: the fix must be a no-op

    /// Given: A phone-shaped viewport, taller than 4/3 of its width (iPhone 15, portrait)
    /// When: The preview rect is fitted
    /// Then: It is unchanged from the previous sizing, and fills the viewport's full width
    func testPhonePortraitIsUnchanged() {
        let viewport = CGSize(width: 393, height: 852)
        let rect = LivenessPreviewGeometry.previewRect(fittingIn: viewport)

        assertRect(rect, CGRect(x: 0, y: 164, width: 393, height: 524))
        assertRect(rect, legacyPreviewRect(fittingIn: viewport), "must match the previous sizing")
    }

    /// Given: Every shipping iPhone size and both portrait iPad sizes
    /// When: The preview rect is fitted
    /// Then: Each one is identical to the previous sizing, so no supported portrait device moves
    func testTallViewportsAreAllUnchanged() {
        let tallViewports: [CGSize] = [
            .init(width: 320, height: 568),   // iPhone SE 1st gen
            .init(width: 375, height: 667),   // iPhone SE 2nd/3rd gen
            .init(width: 390, height: 844),   // iPhone 13/14
            .init(width: 393, height: 852),   // iPhone 15/16
            .init(width: 402, height: 874),   // iPhone 16 Pro
            .init(width: 430, height: 932),   // iPhone 15/16 Pro Max
            .init(width: 440, height: 956),   // iPhone 16 Pro Max
            .init(width: 768, height: 1024),  // iPad 5th gen, portrait
            .init(width: 820, height: 1180),  // iPad 10th gen, portrait
            .init(width: 1032, height: 1376)  // iPad Pro 13-inch, portrait
        ]

        for viewport in tallViewports {
            let rect = LivenessPreviewGeometry.previewRect(fittingIn: viewport)
            assertRect(
                rect,
                legacyPreviewRect(fittingIn: viewport),
                "\(Int(viewport.width))x\(Int(viewport.height)) must not move"
            )
            XCTAssertEqual(rect.width, viewport.width, accuracy: 0.0001)
        }
    }

    /// Given: A viewport whose height is exactly 4/3 of its width, the threshold between the two
    ///        behaviours
    /// When: The preview rect is fitted
    /// Then: It fills the viewport exactly, with no bars on any edge, and both the old and the
    ///       new expressions agree
    func testExactFourThirdsThresholdFillsTheViewport() {
        let viewport = CGSize(width: 600, height: 800)
        let rect = LivenessPreviewGeometry.previewRect(fittingIn: viewport)

        assertRect(rect, CGRect(x: 0, y: 0, width: 600, height: 800))
        assertRect(rect, legacyPreviewRect(fittingIn: viewport), "the threshold must be continuous")
    }

    /// Given: A viewport one point taller than the 4/3 threshold, and one point shorter
    /// When: The preview rect is fitted
    /// Then: The taller one still fills the width and the shorter one is already clamped, so the
    ///       two behaviours meet without a jump
    func testThresholdIsContinuous() {
        let taller = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 600, height: 801))
        let shorter = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 600, height: 799))

        XCTAssertEqual(taller.width, 600, accuracy: 0.0001)
        XCTAssertEqual(shorter.width, 599.25, accuracy: 0.0001)
        XCTAssertEqual(taller.width - shorter.width, 0.75, accuracy: 0.0001)
    }

    // MARK: - Short viewports: the case that was broken

    /// Given: A near-square 904x640 viewport
    /// When: The preview rect is fitted
    /// Then: It is letterboxed to 480x640, fits entirely inside the viewport, and no longer
    ///       overflows by the 565pt the previous sizing produced
    func testNearSquareLandscapeIsClamped() {
        let viewport = CGSize(width: 904, height: 640)
        let rect = LivenessPreviewGeometry.previewRect(fittingIn: viewport)

        assertRect(rect, CGRect(x: 212, y: 0, width: 480, height: 640))
        assertRect(
            legacyPreviewRect(fittingIn: viewport),
            CGRect(x: 0, y: -282.66667, width: 904, height: 1205.33333),
            accuracy: 0.001,
            "the previous sizing overflowed, which is what this test pins as fixed"
        )
    }

    /// Given: The same 904x640 window rotated to 640x904, which is above the 4/3 threshold
    /// When: The preview rect is fitted
    /// Then: Nothing changes, confirming only one of the two orientations was ever affected
    func testNearSquarePortraitIsUnchanged() {
        let viewport = CGSize(width: 640, height: 904)
        let rect = LivenessPreviewGeometry.previewRect(fittingIn: viewport)

        assertRect(rect, CGRect(x: 0, y: 25.33333, width: 640, height: 853.33333), accuracy: 0.001)
        assertRect(rect, legacyPreviewRect(fittingIn: viewport), accuracy: 0.001)
    }

    /// Given: An iPad 10th gen in landscape
    /// When: The preview rect is fitted
    /// Then: It is letterboxed to 615x820 instead of the 1573pt-tall rect the previous sizing
    ///       produced in an 820pt-tall window
    func testIPadLandscapeIsClamped() {
        let viewport = CGSize(width: 1180, height: 820)
        let rect = LivenessPreviewGeometry.previewRect(fittingIn: viewport)

        assertRect(rect, CGRect(x: 282.5, y: 0, width: 615, height: 820))
        XCTAssertEqual(legacyPreviewRect(fittingIn: viewport).height, 1573.33333, accuracy: 0.001)
    }

    /// Given: An iPad 5th gen in landscape, the device reported in GitHub issue #229
    /// When: The preview rect is fitted
    /// Then: It is letterboxed to 576x768 and fits the window
    func testIPad5thGenLandscapeIsClamped() {
        let rect = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 1024, height: 768))

        assertRect(rect, CGRect(x: 224, y: 0, width: 576, height: 768))
    }

    // MARK: - Invariants

    /// Given: A sweep of viewports either side of the threshold, including square and extreme ones
    /// When: The preview rect is fitted
    /// Then: It always keeps the camera's 3:4 aspect ratio, always fits inside the viewport, and
    ///       is always centred
    func testFittedRectIsAlwaysContainedCentredAndThreeByFour() {
        let viewports: [CGSize] = [
            .init(width: 393, height: 852),
            .init(width: 600, height: 800),
            .init(width: 700, height: 700),
            .init(width: 904, height: 640),
            .init(width: 1180, height: 820),
            .init(width: 1024, height: 768),
            .init(width: 1366, height: 300),
            .init(width: 300, height: 1366)
        ]

        for viewport in viewports {
            let rect = LivenessPreviewGeometry.previewRect(fittingIn: viewport)
            let label = "\(Int(viewport.width))x\(Int(viewport.height))"

            XCTAssertEqual(
                rect.width / rect.height,
                LivenessPreviewGeometry.previewAspectRatio,
                accuracy: 0.0001,
                "\(label) must stay 3:4"
            )
            XCTAssertLessThanOrEqual(rect.width, viewport.width + 0.0001, "\(label) must fit horizontally")
            XCTAssertLessThanOrEqual(rect.height, viewport.height + 0.0001, "\(label) must fit vertically")
            XCTAssertGreaterThanOrEqual(rect.minX, -0.0001, "\(label) must not start off-screen")
            XCTAssertGreaterThanOrEqual(rect.minY, -0.0001, "\(label) must not start off-screen")
            XCTAssertEqual(rect.midX, viewport.width / 2, accuracy: 0.0001, "\(label) must be centred")
            XCTAssertEqual(rect.midY, viewport.height / 2, accuracy: 0.0001, "\(label) must be centred")
        }
    }

    /// Given: A viewport with no area, which is what the view reports before its first layout pass
    /// When: The preview rect is fitted
    /// Then: It is `.zero` rather than a NaN-bearing rect
    func testEmptyViewportIsZero() {
        XCTAssertEqual(LivenessPreviewGeometry.previewRect(fittingIn: .zero), .zero)
        XCTAssertEqual(LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 393, height: 0)), .zero)
        XCTAssertEqual(LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 0, height: 852)), .zero)
        XCTAssertEqual(LivenessPreviewGeometry.previewRect(fittingIn: .init(width: -393, height: -852)), .zero)
    }

    // MARK: - Oval mapping

    /// Given: A preview rect exactly as wide as the 480pt-wide video the service is configured with
    /// When: The service's oval is mapped onto it
    /// Then: The oval is passed through unscaled
    func testOvalAtVideoScaleIsUnscaled() {
        let videoOval = CGRect(x: 108, y: 107, width: 264, height: 427)

        let rect = LivenessPreviewGeometry.ovalRect(
            forVideoOval: videoOval,
            videoSize: .init(width: 480, height: 640),
            previewRect: .init(x: 212, y: 0, width: 480, height: 640)
        )

        assertRect(rect, videoOval)
    }

    /// Given: A preview rect narrower than the video, as on a phone
    /// When: The service's oval is mapped onto it
    /// Then: Every edge is scaled by the preview-to-video width ratio
    func testOvalScalesWithPreviewWidth() {
        let videoOval = CGRect(x: 108, y: 107, width: 264, height: 427)
        let scale: CGFloat = 393.0 / 480.0

        let rect = LivenessPreviewGeometry.ovalRect(
            forVideoOval: videoOval,
            videoSize: .init(width: 480, height: 640),
            previewRect: .init(x: 0, y: 164, width: 393, height: 524)
        )

        assertRect(
            rect,
            CGRect(
                x: videoOval.minX * scale,
                y: videoOval.minY * scale,
                width: videoOval.width * scale,
                height: videoOval.height * scale
            )
        )
    }

    /// Given: The 904x640 viewport, before and after the clamp
    /// When: The service's oval is mapped onto each preview rect
    /// Then: The clamped oval fits inside the viewport's height, where the unclamped one was
    ///       taller than the whole window
    func testOvalFitsTheViewportAfterClamping() {
        let viewport = CGSize(width: 904, height: 640)
        let videoOval = CGRect(x: 108, y: 107, width: 264, height: 427)
        let videoSize = CGSize(width: 480, height: 640)

        let fixed = LivenessPreviewGeometry.ovalRect(
            forVideoOval: videoOval,
            videoSize: videoSize,
            previewRect: LivenessPreviewGeometry.previewRect(fittingIn: viewport)
        )
        let legacy = LivenessPreviewGeometry.ovalRect(
            forVideoOval: videoOval,
            videoSize: videoSize,
            previewRect: legacyPreviewRect(fittingIn: viewport)
        )

        XCTAssertLessThanOrEqual(fixed.maxY, viewport.height)
        XCTAssertGreaterThan(legacy.height, viewport.height, "the previous oval was taller than the window")
    }

    /// Given: A video size with no width, which would divide by zero
    /// When: The service's oval is mapped
    /// Then: The result is `.zero`
    func testOvalWithEmptyVideoSizeIsZero() {
        let rect = LivenessPreviewGeometry.ovalRect(
            forVideoOval: .init(x: 108, y: 107, width: 264, height: 427),
            videoSize: .init(width: 0, height: 640),
            previewRect: .init(x: 0, y: 0, width: 480, height: 640)
        )

        XCTAssertEqual(rect, .zero)
    }

    // MARK: - A 640x904 windowed viewport, and the marginal band around the threshold

    /// Given: A windowed viewport of 640 wide by 904 tall, which is ABOVE the 4/3
    ///        threshold (h/w 1.4125)
    /// When: The preview rect is fitted
    /// Then: Nothing changes. A 640pt-wide preview needs 853.33pt and the viewport supplies 904,
    ///       so 50.67pt of headroom remain and the clamp is a no-op. If the oval is misplaced at
    ///       this size the cause is NOT the static clamp.
    func testWindowedViewport640x904IsAboveThresholdAndUnchanged() {
        let viewport = CGSize(width: 640, height: 904)
        let rect = LivenessPreviewGeometry.previewRect(fittingIn: viewport)

        XCTAssertEqual(viewport.width * 4 / 3, 853.33333, accuracy: 0.001, "height the preview needs")
        XCTAssertEqual(viewport.height - viewport.width * 4 / 3, 50.66667, accuracy: 0.001, "headroom")
        assertRect(rect, CGRect(x: 0, y: 25.33333, width: 640, height: 853.33333), accuracy: 0.001)
        assertRect(rect, legacyPreviewRect(fittingIn: viewport), accuracy: 0.001, "must be a no-op")
    }

    /// Given: A 640pt-wide detector view whose height has been reduced below 853.33pt by host
    ///        chrome that consumes layout height, measured at 845.5pt for a title above the
    ///        detector
    /// When: The preview rect is fitted
    /// Then: The clamp fires with a small letterbox, the rect stays inside the view, and the
    ///       previous sizing would have overflowed by 7.83pt
    func testMarginalBandJustBelowThreshold() {
        let viewport = CGSize(width: 640, height: 845.5)
        let rect = LivenessPreviewGeometry.previewRect(fittingIn: viewport)

        assertRect(rect, CGRect(x: 2.9375, y: 0, width: 634.125, height: 845.5), accuracy: 0.001)
        XCTAssertEqual(legacyPreviewRect(fittingIn: viewport).height - viewport.height,
                       7.83333, accuracy: 0.001, "the previous sizing overflowed")
        XCTAssertGreaterThan(rect.width, 0)
        XCTAssertGreaterThan(rect.height, 0)
    }

    /// Given: Viewports one point either side of the threshold at 640pt wide
    /// When: The preview rect is fitted
    /// Then: The reduction is proportional and tiny rather than a jump to a degenerate rect: one
    ///       point of missing height costs 0.75pt of width and 0.375pt of letterbox per side
    func testMarginalBandDegradesProportionally() {
        let atThreshold = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 640, height: 853.33333))
        let onePointShort = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 640, height: 852.33333))

        XCTAssertEqual(atThreshold.width, 640, accuracy: 0.001)
        XCTAssertEqual(atThreshold.minX, 0, accuracy: 0.001)
        XCTAssertEqual(onePointShort.width, 639.25, accuracy: 0.001)
        XCTAssertEqual(onePointShort.minX, 0.375, accuracy: 0.001)
    }

    /// Given: A sweep across the marginal band, from 30pt above the threshold to 30pt below
    /// When: The preview rect is fitted and the service's oval mapped onto it
    /// Then: The oval is fully inside the view at every step, and the rect never degenerates
    func testOvalStaysFullyVisibleAcrossTheMarginalBand() {
        let videoOval = CGRect(x: 108, y: 107, width: 264, height: 427)
        let width: CGFloat = 640
        let threshold = width * 4 / 3

        for delta in stride(from: CGFloat(30), through: -30, by: -2.5) {
            let viewport = CGSize(width: width, height: threshold + delta)
            let preview = LivenessPreviewGeometry.previewRect(fittingIn: viewport)
            let oval = LivenessPreviewGeometry.ovalRect(
                forVideoOval: videoOval,
                videoSize: .init(width: 480, height: 640),
                previewRect: preview
            )
            let label = "640x\(String(format: "%.2f", viewport.height))"

            XCTAssertGreaterThan(preview.width, 0, "\(label) preview must not degenerate")
            XCTAssertGreaterThan(preview.height, 0, "\(label) preview must not degenerate")
            XCTAssertLessThanOrEqual(preview.maxY, viewport.height + 0.0001, "\(label) preview must fit")
            XCTAssertLessThanOrEqual(preview.maxX, viewport.width + 0.0001, "\(label) preview must fit")
            // the oval is in preview-local coordinates, so on-screen it is offset by the origin
            XCTAssertLessThanOrEqual(preview.minY + oval.maxY, viewport.height + 0.0001,
                                     "\(label) oval must be fully visible")
            XCTAssertLessThanOrEqual(preview.minX + oval.maxX, viewport.width + 0.0001,
                                     "\(label) oval must be fully visible")
        }
    }

    // MARK: - The resize path

    /// Given: A view sized 820x1180 (iPad 10th gen full-screen portrait) that is then resized to
    ///        640x904, both of which are above the 4/3 threshold
    /// When: The preview rect is refitted for the new size
    /// Then: It changes, so a relayout is genuinely required even though NEITHER size trips the
    ///       clamp. This is the defect a width clamp alone would not fix.
    func testResizeBetweenTwoUnclampedSizesStillChangesTheRect() {
        let before = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 820, height: 1180))
        let after = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 640, height: 904))

        assertRect(before, CGRect(x: 0, y: 43.33333, width: 820, height: 1093.33333), accuracy: 0.001)
        assertRect(after, CGRect(x: 0, y: 25.33333, width: 640, height: 853.33333), accuracy: 0.001)
        XCTAssertNotEqual(before, after)
    }

    /// Given: The previous code, in which `normalizeFace` read the view's width live on every
    ///        frame while `cameraViewRect` was captured once in `setupAVLayer`
    /// When: The view is resized from 820x1180 to 640x904
    /// Then: Those two rects disagree, so face landmarks were normalized in one coordinate space
    ///       and matched against an oval built in another. Deriving both from one function of the
    ///       current size removes the disagreement by construction.
    func testResizeNoLongerDesyncsLandmarksFromTheOval() {
        let sizeAtSetup = CGSize(width: 820, height: 1180)
        let sizeAfterResize = CGSize(width: 640, height: 904)

        let staleOvalSpace = legacyPreviewRect(fittingIn: sizeAtSetup).size
        let liveLandmarkSpace = CGSize(
            width: sizeAfterResize.width,
            height: sizeAfterResize.width / 3 * 4
        )
        XCTAssertNotEqual(staleOvalSpace, liveLandmarkSpace, "the previous code desynced on resize")

        let fitted = LivenessPreviewGeometry.previewRect(fittingIn: sizeAfterResize)
        assertRect(fitted, CGRect(x: 0, y: 25.33333, width: 640, height: 853.33333), accuracy: 0.001)
    }

    /// Given: The stale initial frame the shipped code captures in `viewDidLoad`, which is the
    ///        SCREEN size (820x1180 on an iPad 10th gen) rather than the hosting window's
    ///        640x904, measured with a lifecycle probe
    /// When: The rect is refitted for the real size on the first layout pass
    /// Then: It fits the window, where the shipped code kept the 820pt width and only re-centred,
    ///       overhanging by 90pt per side and 94.67pt top and bottom
    func testStaleScreenSizedInitialFrameIsCorrected() {
        let screen = CGSize(width: 820, height: 1180)
        let window = CGSize(width: 640, height: 904)

        // shipped: width from the screen, height derived, re-centred in the real window
        let staleWidth = screen.width
        let staleHeight = staleWidth / 3 * 4
        let staleRecentred = CGRect(
            x: window.width / 2 - staleWidth / 2,
            y: window.height / 2 - staleHeight / 2,
            width: staleWidth,
            height: staleHeight
        )
        XCTAssertEqual(staleRecentred.minX, -90, accuracy: 0.001, "overhang per side")
        XCTAssertEqual(staleRecentred.minY, -94.66667, accuracy: 0.001, "overhang top and bottom")

        // fixed: refitted to the real window on the first layout pass
        let fixed = LivenessPreviewGeometry.previewRect(fittingIn: window)
        assertRect(fixed, CGRect(x: 0, y: 25.33333, width: 640, height: 853.33333), accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(fixed.minX, 0)
        XCTAssertGreaterThanOrEqual(fixed.minY, 0)
        XCTAssertLessThanOrEqual(fixed.maxX, window.width)
        XCTAssertLessThanOrEqual(fixed.maxY, window.height)
    }

    /// Given: A stale initial width and the service oval expressed in the 480pt-wide video
    /// When: The oval is mapped through the stale rect
    /// Then: The oval only overhangs the window's SIDES once the stale width exceeds
    ///       `windowWidth * videoWidth / ovalWidth`. For a 640pt window and a 264pt oval that is
    ///       1163.6pt, so a stale width of 820 clips nothing horizontally while 1180 does. Side
    ///       clipping therefore identifies which stale width is in play.
    func testSideClippingRequiresALargeStaleWidth() {
        let window = CGSize(width: 640, height: 904)
        let videoOval = CGRect(x: 108, y: 107, width: 264, height: 427)
        let videoSize = CGSize(width: 480, height: 640)

        func sideOverhang(staleWidth: CGFloat) -> CGFloat {
            let staleHeight = staleWidth / 3 * 4
            let cam = CGRect(x: window.width / 2 - staleWidth / 2,
                             y: window.height / 2 - staleHeight / 2,
                             width: staleWidth, height: staleHeight)
            let oval = LivenessPreviewGeometry.ovalRect(
                forVideoOval: videoOval, videoSize: videoSize, previewRect: cam
            )
            let onScreen = CGRect(x: cam.minX + oval.minX, y: cam.minY + oval.minY,
                                  width: oval.width, height: oval.height)
            return max(0, -onScreen.minX) + max(0, onScreen.maxX - window.width)
        }

        XCTAssertEqual(window.width * videoSize.width / videoOval.width, 1163.63636, accuracy: 0.001)
        XCTAssertEqual(sideOverhang(staleWidth: 820), 0, accuracy: 0.001, "portrait screen width does not clip sides")
        XCTAssertGreaterThan(sideOverhang(staleWidth: 1180), 0, "landscape screen width does clip sides")
    }
}
