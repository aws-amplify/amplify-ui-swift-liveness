//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import UIKit
import XCTest
@testable import FaceLiveness
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

/// Records the oval rects the view model asks to have drawn.
final class MockLivenessViewControllerPresenter: FaceLivenessViewControllerPresenter {
    var drawnOvalRects: [CGRect] = []

    func drawOvalInCanvas(_ ovalRect: CGRect) {
        drawnOvalRects.append(ovalRect)
    }

    func displayFreshness(colorSequences: [FaceLivenessSession.DisplayColor]) {}
    func stopFreshness() {}
    func displaySingleFrame(uiImage: UIImage) {}
    func completeNoLightCheck() {}
}

/// Fixtures shared by the geometry tests.
enum LivenessGeometryFixture {
    /// The oval the service specifies, in the 480x640 video's coordinate space.
    static let videoOval = CGRect(x: 108, y: 107, width: 264, height: 427)
    static let videoSize = CGSize(width: 480, height: 640)

    /// A view model whose session configuration carries `videoOval`, reporting draws to `presenter`.
    @MainActor
    static func makeViewModel(presenter: MockLivenessViewControllerPresenter) -> FaceLivenessDetectionViewModel {
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
        return viewModel
    }

    /// `videoOval` mapped onto a preview rect of the given width, which is how the view model
    /// is expected to place it. Expressed independently of `LivenessPreviewGeometry` so the
    /// tests do not restate the implementation.
    static func expectedOval(forPreviewWidth previewWidth: CGFloat) -> CGRect {
        let scale = previewWidth / videoSize.width
        return CGRect(
            x: videoOval.minX * scale,
            y: videoOval.minY * scale,
            width: videoOval.width * scale,
            height: videoOval.height * scale
        )
    }

    /// The preview rect the shipped code produced: full viewport width, height derived from it,
    /// centred in the viewport. Kept so the "no change on tall viewports" guarantee and the
    /// stale-frame scenarios are stated against the old expression rather than hand-copied numbers.
    static func legacyPreviewRect(fittingIn viewport: CGSize) -> CGRect {
        let width = viewport.width
        let height = width / 3 * 4
        return CGRect(
            x: (viewport.width - width) / 2,
            y: (viewport.height - height) / 2,
            width: width,
            height: height
        )
    }
}

extension XCTestCase {
    /// Draws the oval and waits for the view model to move to `.recording(ovalDisplayed: true)`,
    /// which `drawOval` does on the next main queue turn.
    @MainActor
    func drawOvalAndWaitUntilDisplayed(
        _ viewModel: FaceLivenessDetectionViewModel,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let displayed = expectation(description: "oval displayed")
        viewModel.drawOval(onComplete: { displayed.fulfill() })
        wait(for: [displayed], timeout: 1)
        XCTAssertEqual(
            viewModel.livenessState.state,
            .recording(ovalDisplayed: true),
            file: file,
            line: line
        )
    }

    func assertRect(
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
}
