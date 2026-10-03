//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import FaceLiveness

final class LivenessPreviewGeometryTests: XCTestCase {
    /// The previous preview sizing. See `LivenessGeometryFixture.legacyPreviewRect`.
    private func legacyPreviewRect(fittingIn viewport: CGSize) -> CGRect {
        LivenessGeometryFixture.legacyPreviewRect(fittingIn: viewport)
    }

    // MARK: - Tall viewports

    /// Given: A phone portrait viewport (iPhone 15), taller than 4/3 of its width
    /// When: The preview rect is fitted
    /// Then: It matches the previous sizing and fills the viewport's width
    func testPhonePortraitIsUnchanged() {
        let viewport = CGSize(width: 393, height: 852)
        let rect = LivenessPreviewGeometry.previewRect(fittingIn: viewport)

        assertRect(rect, CGRect(x: 0, y: 164, width: 393, height: 524))
        assertRect(rect, legacyPreviewRect(fittingIn: viewport), "must match the previous sizing")
    }

    /// Given: Every shipping iPhone size and both portrait iPad sizes
    /// When: The preview rect is fitted
    /// Then: Each one matches the previous sizing
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

    /// Given: A viewport whose height is exactly 4/3 of its width
    /// When: The preview rect is fitted
    /// Then: It fills the viewport exactly and matches the previous sizing
    func testExactFourThirdsThresholdFillsTheViewport() {
        let viewport = CGSize(width: 600, height: 800)
        let rect = LivenessPreviewGeometry.previewRect(fittingIn: viewport)

        assertRect(rect, CGRect(x: 0, y: 0, width: 600, height: 800))
        assertRect(rect, legacyPreviewRect(fittingIn: viewport), "the threshold must be continuous")
    }

    /// Given: Viewports one point taller and one point shorter than the 4/3 threshold
    /// When: The preview rect is fitted
    /// Then: The taller one fills the width and the shorter one is clamped, with no jump
    func testThresholdIsContinuous() {
        let taller = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 600, height: 801))
        let shorter = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 600, height: 799))

        XCTAssertEqual(taller.width, 600, accuracy: 0.0001)
        XCTAssertEqual(shorter.width, 599.25, accuracy: 0.0001)
        XCTAssertEqual(taller.width - shorter.width, 0.75, accuracy: 0.0001)
    }

    // MARK: - Short viewports

    /// Given: A near-square 904x640 viewport
    /// When: The preview rect is fitted
    /// Then: It is letterboxed to 480x640 inside the viewport; the previous sizing overflowed
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

    /// Given: The same window rotated to 640x904, above the 4/3 threshold
    /// When: The preview rect is fitted
    /// Then: It matches the previous sizing
    func testNearSquarePortraitIsUnchanged() {
        let viewport = CGSize(width: 640, height: 904)
        let rect = LivenessPreviewGeometry.previewRect(fittingIn: viewport)

        assertRect(rect, CGRect(x: 0, y: 25.33333, width: 640, height: 853.33333), accuracy: 0.001)
        assertRect(rect, legacyPreviewRect(fittingIn: viewport), accuracy: 0.001)
    }

    /// Given: An iPad 10th gen in landscape
    /// When: The preview rect is fitted
    /// Then: It is letterboxed to 615x820; the previous sizing was 1573pt tall
    func testIPadLandscapeIsClamped() {
        let viewport = CGSize(width: 1180, height: 820)
        let rect = LivenessPreviewGeometry.previewRect(fittingIn: viewport)

        assertRect(rect, CGRect(x: 282.5, y: 0, width: 615, height: 820))
        XCTAssertEqual(legacyPreviewRect(fittingIn: viewport).height, 1573.33333, accuracy: 0.001)
    }

    /// Given: An iPad 5th gen in landscape (issue #229)
    /// When: The preview rect is fitted
    /// Then: It is letterboxed to 576x768 and fits the window
    func testIPad5thGenLandscapeIsClamped() {
        let rect = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 1024, height: 768))

        assertRect(rect, CGRect(x: 224, y: 0, width: 576, height: 768))
    }

    // MARK: - Invariants

    /// Given: A sweep of viewports either side of the threshold, including square and extreme
    /// When: The preview rect is fitted
    /// Then: It is always 3:4, inside the viewport, and centered
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

    /// Given: A viewport with no area
    /// When: The preview rect is fitted
    /// Then: It is `.zero`
    func testEmptyViewportIsZero() {
        XCTAssertEqual(LivenessPreviewGeometry.previewRect(fittingIn: .zero), .zero)
        XCTAssertEqual(LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 393, height: 0)), .zero)
        XCTAssertEqual(LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 0, height: 852)), .zero)
        XCTAssertEqual(LivenessPreviewGeometry.previewRect(fittingIn: .init(width: -393, height: -852)), .zero)
    }

    // MARK: - Oval mapping

    /// Given: A preview rect as wide as the 480pt video
    /// When: The service's oval is mapped onto it
    /// Then: The oval is passed through unscaled
    func testOvalAtVideoScaleIsUnscaled() {
        let videoOval = CGRect(x: 108, y: 107, width: 264, height: 427)

        let rect = LivenessPreviewGeometry.ovalRect(
            forVideoOval: videoOval,
            videoSize: .init(width: 480, height: 640),
            previewWidth: 480
        )

        assertRect(rect, videoOval)
    }

    /// Given: A preview rect narrower than the video
    /// When: The service's oval is mapped onto it
    /// Then: Every edge is scaled by the preview-to-video width ratio
    func testOvalScalesWithPreviewWidth() {
        let videoOval = CGRect(x: 108, y: 107, width: 264, height: 427)
        let scale: CGFloat = 393.0 / 480.0

        let rect = LivenessPreviewGeometry.ovalRect(
            forVideoOval: videoOval,
            videoSize: .init(width: 480, height: 640),
            previewWidth: 393
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
    /// Then: The clamped oval fits the viewport's height; the unclamped one did not
    func testOvalFitsTheViewportAfterClamping() {
        let viewport = CGSize(width: 904, height: 640)
        let videoOval = CGRect(x: 108, y: 107, width: 264, height: 427)
        let videoSize = CGSize(width: 480, height: 640)

        let fixed = LivenessPreviewGeometry.ovalRect(
            forVideoOval: videoOval,
            videoSize: videoSize,
            previewWidth: LivenessPreviewGeometry.previewRect(fittingIn: viewport).width
        )
        let legacy = LivenessPreviewGeometry.ovalRect(
            forVideoOval: videoOval,
            videoSize: videoSize,
            previewWidth: legacyPreviewRect(fittingIn: viewport).width
        )

        XCTAssertLessThanOrEqual(fixed.maxY, viewport.height)
        XCTAssertGreaterThan(legacy.height, viewport.height, "the previous oval was taller than the window")
    }

    /// Given: A video size with no width
    /// When: The service's oval is mapped
    /// Then: The result is `.zero`
    func testOvalWithEmptyVideoSizeIsZero() {
        let rect = LivenessPreviewGeometry.ovalRect(
            forVideoOval: .init(x: 108, y: 107, width: 264, height: 427),
            videoSize: .init(width: 0, height: 640),
            previewWidth: 480
        )

        XCTAssertEqual(rect, .zero)
    }

    // MARK: - The marginal band around the threshold

    /// Given: A 640x904 windowed viewport, above the 4/3 threshold with 50.67pt of headroom
    /// When: The preview rect is fitted
    /// Then: It matches the previous sizing; the clamp is a no-op here
    func testWindowedViewport640x904IsAboveThresholdAndUnchanged() {
        let viewport = CGSize(width: 640, height: 904)
        let rect = LivenessPreviewGeometry.previewRect(fittingIn: viewport)

        XCTAssertEqual(viewport.width * 4 / 3, 853.33333, accuracy: 0.001, "height the preview needs")
        XCTAssertEqual(viewport.height - viewport.width * 4 / 3, 50.66667, accuracy: 0.001, "headroom")
        assertRect(rect, CGRect(x: 0, y: 25.33333, width: 640, height: 853.33333), accuracy: 0.001)
        assertRect(rect, legacyPreviewRect(fittingIn: viewport), accuracy: 0.001, "must be a no-op")
    }

    /// Given: A 640x845.5 view, just below the 4/3 threshold
    /// When: The preview rect is fitted
    /// Then: The clamp fires with a small letterbox; the previous sizing overflowed by 7.83pt
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
    /// Then: One point of missing height costs 0.75pt of width and 0.375pt of letterbox a side
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
    /// Then: The oval is fully inside the view at every step and the rect never degenerates
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
                previewWidth: preview.width
            )
            let label = "640x\(String(format: "%.2f", viewport.height))"

            XCTAssertGreaterThan(preview.width, 0, "\(label) preview must not degenerate")
            XCTAssertGreaterThan(preview.height, 0, "\(label) preview must not degenerate")
            XCTAssertLessThanOrEqual(preview.maxY, viewport.height + 0.0001, "\(label) preview must fit")
            XCTAssertLessThanOrEqual(preview.maxX, viewport.width + 0.0001, "\(label) preview must fit")
            // the oval is in preview-local coordinates
            XCTAssertLessThanOrEqual(preview.minY + oval.maxY, viewport.height + 0.0001,
                                     "\(label) oval must be fully visible")
            XCTAssertLessThanOrEqual(preview.minX + oval.maxX, viewport.width + 0.0001,
                                     "\(label) oval must be fully visible")
        }
    }

    // MARK: - The resize path

    /// Given: A view resized from 820x1180 to 640x904, both above the 4/3 threshold
    /// When: The preview rect is refitted
    /// Then: It changes, so a relayout is required even though neither size is clamped
    func testResizeBetweenTwoUnclampedSizesStillChangesTheRect() {
        let before = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 820, height: 1180))
        let after = LivenessPreviewGeometry.previewRect(fittingIn: .init(width: 640, height: 904))

        assertRect(before, CGRect(x: 0, y: 43.33333, width: 820, height: 1093.33333), accuracy: 0.001)
        assertRect(after, CGRect(x: 0, y: 25.33333, width: 640, height: 853.33333), accuracy: 0.001)
        XCTAssertNotEqual(before, after)
    }

    /// Given: A face that fills the service's oval, and a view resized from 820x1180 to 640x904
    /// When: The face is normalized against the fitted preview and the oval mapped onto it
    /// Then: Face and oval coincide before and after the resize; a stale oval does not match
    func testResizeNoLongerDesyncsLandmarksFromTheOval() {
        let videoOval = LivenessGeometryFixture.videoOval
        let videoSize = LivenessGeometryFixture.videoSize
        let sizeAtSetup = CGSize(width: 820, height: 1180)
        let sizeAfterResize = CGSize(width: 640, height: 904)

        // the detector reports landmarks as fractions of the frame
        let faceFillingTheOval = DetectedFace(
            boundingBox: CGRect(
                x: videoOval.minX / videoSize.width,
                y: videoOval.minY / videoSize.height,
                width: videoOval.width / videoSize.width,
                height: videoOval.height / videoSize.height
            ),
            leftEye: .zero, rightEye: .zero, nose: .zero, mouth: .zero, rightEar: .zero, leftEar: .zero,
            confidence: 1
        )

        func normalizedFaceBox(in previewRect: CGRect) -> CGRect {
            faceFillingTheOval.normalize(width: previewRect.width, height: previewRect.height).boundingBox
        }
        func oval(in previewRect: CGRect) -> CGRect {
            LivenessPreviewGeometry.ovalRect(forVideoOval: videoOval, videoSize: videoSize, previewWidth: previewRect.width)
        }

        let before = LivenessPreviewGeometry.previewRect(fittingIn: sizeAtSetup)
        let after = LivenessPreviewGeometry.previewRect(fittingIn: sizeAfterResize)
        XCTAssertNotEqual(before, after, "the resize must actually change the fitted rect")

        assertRect(normalizedFaceBox(in: before), oval(in: before), "before the resize")
        assertRect(normalizedFaceBox(in: after), oval(in: after), "after the resize")

        // landmarks in the new space, oval still in the old one
        let desynced = normalizedFaceBox(in: after)
        let staleOval = oval(in: before)
        XCTAssertNotEqual(desynced.minX, staleOval.minX, accuracy: 0.0001)
        XCTAssertNotEqual(desynced.minY, staleOval.minY, accuracy: 0.0001)
        XCTAssertNotEqual(desynced.width, staleOval.width, accuracy: 0.0001)
        XCTAssertNotEqual(desynced.height, staleOval.height, accuracy: 0.0001)
    }

    /// Given: A sweep of viewport sizes and a face that fills the service's oval
    /// When: The face is normalized against the fitted preview and the oval mapped onto it
    /// Then: They coincide at every size
    func testLandmarksAndOvalAgreeAtEveryViewportSize() {
        let videoOval = LivenessGeometryFixture.videoOval
        let videoSize = LivenessGeometryFixture.videoSize
        let faceFillingTheOval = DetectedFace(
            boundingBox: CGRect(
                x: videoOval.minX / videoSize.width,
                y: videoOval.minY / videoSize.height,
                width: videoOval.width / videoSize.width,
                height: videoOval.height / videoSize.height
            ),
            leftEye: .zero, rightEye: .zero, nose: .zero, mouth: .zero, rightEar: .zero, leftEar: .zero,
            confidence: 1
        )
        let viewports: [CGSize] = [
            .init(width: 393, height: 852),
            .init(width: 640, height: 904),
            .init(width: 820, height: 1180),
            .init(width: 700, height: 700),
            .init(width: 904, height: 640),
            .init(width: 1180, height: 820),
            .init(width: 1024, height: 768)
        ]

        for viewport in viewports {
            let fitted = LivenessPreviewGeometry.previewRect(fittingIn: viewport)
            let face = faceFillingTheOval.normalize(width: fitted.width, height: fitted.height).boundingBox
            let oval = LivenessPreviewGeometry.ovalRect(forVideoOval: videoOval, videoSize: videoSize, previewWidth: fitted.width)

            assertRect(face, oval, "\(Int(viewport.width))x\(Int(viewport.height))")
        }
    }

    // MARK: - Get-ready column width

    /// Given: The container the get-ready preview gets on an iPhone 15 (below the begin button)
    /// When: The column width is fitted
    /// Then: The width binds, so the layout is unchanged
    func testGetReadyColumnWidthIsUnchangedOnPhones() {
        let width = LivenessPreviewGeometry.columnWidth(fittingIn: CGSize(width: 393, height: 683))

        XCTAssertEqual(width, 393, accuracy: 0.0001)
    }

    /// Given: Every tall viewport from the preview-rect sweep
    /// When: The column width is fitted
    /// Then: Each one keeps its own width
    func testGetReadyColumnWidthIsUnchangedForAllTallViewports() {
        let tallViewports: [CGSize] = [
            .init(width: 320, height: 568),
            .init(width: 375, height: 667),
            .init(width: 390, height: 844),
            .init(width: 393, height: 852),
            .init(width: 402, height: 874),
            .init(width: 430, height: 932),
            .init(width: 440, height: 956),
            .init(width: 768, height: 1024),
            .init(width: 820, height: 1180),
            .init(width: 1032, height: 1376)
        ]

        for viewport in tallViewports {
            let width = LivenessPreviewGeometry.columnWidth(fittingIn: viewport)
            XCTAssertEqual(
                width, viewport.width, accuracy: 0.0001,
                "\(Int(viewport.width))x\(Int(viewport.height)) must not move"
            )
        }
    }

    /// Given: A wide window (904x564 available to the preview)
    /// When: The column width is fitted
    /// Then: The height binds and the column narrows to a 3:4 portrait width
    func testGetReadyColumnWidthNarrowsInWideWindows() {
        let width = LivenessPreviewGeometry.columnWidth(fittingIn: CGSize(width: 904, height: 564))

        XCTAssertEqual(width, 423, accuracy: 0.0001)
    }

    /// Given: A viewport whose width is exactly 3/4 of its height
    /// When: The column width is fitted
    /// Then: The width is returned unchanged (the two terms agree)
    func testGetReadyColumnWidthAtTheExactThreshold() {
        let width = LivenessPreviewGeometry.columnWidth(fittingIn: CGSize(width: 480, height: 640))

        XCTAssertEqual(width, 480, accuracy: 0.0001)
    }

    /// Given: A sweep of viewports on both sides of the threshold
    /// When: The column width and the preview rect are fitted
    /// Then: They agree on the width, so the two screens clamp identically
    func testGetReadyColumnWidthMatchesThePreviewRectWidth() {
        let viewports: [CGSize] = [
            .init(width: 393, height: 852),
            .init(width: 640, height: 904),
            .init(width: 700, height: 700),
            .init(width: 904, height: 640),
            .init(width: 1180, height: 820),
            .init(width: 1024, height: 768)
        ]

        for viewport in viewports {
            XCTAssertEqual(
                LivenessPreviewGeometry.columnWidth(fittingIn: viewport),
                LivenessPreviewGeometry.previewRect(fittingIn: viewport).width,
                accuracy: 0.0001,
                "\(Int(viewport.width))x\(Int(viewport.height))"
            )
        }
    }

    /// Given: A zero-sized viewport (SwiftUI's first layout pass can propose one)
    /// When: The column width is fitted
    /// Then: It is zero, not negative or undefined
    func testGetReadyColumnWidthOfAnEmptyViewportIsZero() {
        let width = LivenessPreviewGeometry.columnWidth(fittingIn: .zero)

        XCTAssertEqual(width, 0, accuracy: 0.0001)
    }
}
