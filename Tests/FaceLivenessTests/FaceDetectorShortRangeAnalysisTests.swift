//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import CoreML
import VideoToolbox
@testable import FaceLiveness
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

final class FaceDetectorShortRangeAnalysisTests: XCTestCase {
    /// Supplies a session configuration as the view model does; the model holds it weakly.
    private final class SessionConfigurationStub: FaceDetectionSessionConfigurationWrapper {
        let sessionConfiguration: FaceLivenessSession.SessionConfiguration?

        init(_ sessionConfiguration: FaceLivenessSession.SessionConfiguration?) {
            self.sessionConfiguration = sessionConfiguration
        }
    }

    /// Records the frame reports and results the detector delivers, in order.
    private final class RecordingResultHandler: FaceDetectionResultHandler {
        private(set) var calls: [String] = []
        private(set) var reports: [FaceDetectionFrameReport] = []

        func process(newResult: FaceDetectionResult) {
            switch newResult {
            case .noFace: calls.append("noFace")
            case .singleFace: calls.append("singleFace")
            case .multipleFaces: calls.append("multipleFaces")
            }
        }

        func process(frameReport: FaceDetectionFrameReport) {
            calls.append("frameReport")
            reports.append(frameReport)
        }
    }

    /// Stands in for the CoreML model, throwing `error` or returning `outputs`.
    private final class ScriptedModel: MLModel {
        let error: Error?
        let outputs: [String: MLFeatureValue]

        init(error: Error? = nil, outputs: [String: MLFeatureValue] = [:]) {
            self.error = error
            self.outputs = outputs
            super.init()
        }

        override func prediction(from input: MLFeatureProvider) throws -> MLFeatureProvider {
            if let error { throw error }
            return try MLDictionaryFeatureProvider(dictionary: outputs)
        }
    }

    /// Outputs shaped as the real model's, with zero-area boxes, which hang the detector if any score passes.
    private func scriptedOutputs(scores: [Float]) throws -> [String: MLFeatureValue] {
        let anchors = NSNumber(value: scores.count)
        let boxes = try MLMultiArray(shape: [1, anchors, 16], dataType: .float32)
        boxes.dataPointer.initializeMemory(as: Float32.self, repeating: 0, count: boxes.count)
        let scoreArray = try MLMultiArray(shape: [1, anchors, 1], dataType: .float32)
        let scoreValues = scoreArray.dataPointer.bindMemory(to: Float32.self, capacity: scores.count)
        scoreValues.update(from: scores, count: scores.count)
        return ["1477": MLFeatureValue(multiArray: boxes), "1011": MLFeatureValue(multiArray: scoreArray)]
    }

    /// A blank 480x640 BGRA frame, as the camera delivers.
    private func makeBlankFrame() throws -> CVPixelBuffer {
        try XCTUnwrap(makeFrame(at: 0).imageBuffer)
    }

    /// Runs `body` while `model` reads `configuration` through a wrapper.
    private func withConfiguration<T>(
        _ configuration: FaceLivenessSession.SessionConfiguration?,
        on model: FaceDetectorShortRange.Model,
        _ body: () -> T
    ) -> T {
        let stub = SessionConfigurationStub(configuration)
        model.setFaceDetectionSessionConfigurationWrapper(configuration: stub)
        return withExtendedLifetime(stub, body)
    }

    /// Given: Scores with the highest first or last, with NaN, only NaN, none, or only negative ones
    /// When: The top score is taken
    /// Then: It's the highest real score, unchanged, or 0 if there's none
    func testTopScoreIsTheHighestRealScore() {
        let rows: [(name: String, scores: [Float], top: Float)] = [
            ("highest first", [0.9, 0.1, 0.2], 0.9),
            ("highest last", [0.1, 0.2, 0.9], 0.9),
            ("NaN first", [.nan, 0.3, 0.1], 0.3),
            ("NaN last", [0.3, .nan], 0.3),
            ("only NaN", [.nan, .nan], 0),
            ("no scores", [], 0),
            ("only negative", [-0.5, -.infinity], 0)
        ]

        for row in rows {
            XCTAssertEqual(FaceDetectorShortRange.Model.topScore(of: row.scores), row.top, row.name)
        }
    }

    /// Given: The real model on a blank frame and no configuration, a movement one, then a movement and light one
    /// When: Faces are detected at the fallback threshold, the frame's top score, then 0
    /// Then: Reports precede results, count the faces, say if the session threshold applied and keep the top score
    func testEachReportPrecedesAndDescribesItsResult() throws {
        let model = try FaceDetectorShortRange.Model()
        let handler = RecordingResultHandler()
        model.setResultHandler(detectionResultHandler: handler)
        let frame = try makeBlankFrame()
        let topScore = model.analyze(frame).report.topScore
        let challenge = { (threshold: Double) in
            LivenessDiagnosticsFixture.ovalMatchChallenge(faceDetectionThreshold: threshold)
        }
        let configurations: [FaceLivenessSession.SessionConfiguration?] = [
            nil,
            .faceMovement(challenge(Double(topScore))),
            .faceMovementAndLight(.init(colors: []), challenge(0))
        ]

        for configuration in configurations {
            withConfiguration(configuration, on: model) { model.detectFaces(from: frame) }
        }

        XCTAssertEqual(handler.calls, [
            "frameReport", "noFace", "frameReport", "singleFace", "frameReport", "multipleFaces"
        ], "a blank frame scored \(topScore)")
        XCTAssertEqual(handler.reports.map { min($0.faceCount, 2) }, [0, 1, 2], "face counts, several as 2")
        XCTAssertEqual(handler.reports.map(\.usedSessionThreshold), [false, true, true])
        XCTAssertEqual(handler.reports.map(\.topScore), [topScore, topScore, topScore])
        XCTAssertEqual(handler.reports.compactMap(\.failure?.stage), [])
    }

    /// Given: A frame VideoToolbox can't convert, and models that throw, return nothing, or return no scores
    /// When: Faces are detected with each
    /// Then: Each report names the failed stage and its cause, and precedes a no face result
    func testEachFailedStageIsReported() throws {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 480, 640, kCVPixelFormatType_OneComponent32Float, nil, &buffer)
        let unconvertible = try XCTUnwrap(buffer)
        var image: CGImage?
        let status = VTCreateCGImageFromCVPixelBuffer(unconvertible, options: nil, imageOut: &image)
        XCTAssertNotEqual(status, noErr, "VideoToolbox converted the frame")
        let conversionError = NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        let thrown = NSError(domain: "ScriptedModel", code: 7)
        let boxesOnly = try scriptedOutputs(scores: [0]).filter { $0.key == "1477" }
        let blank = try makeBlankFrame()
        let rows: [(stage: FrameAnalysisFailure.Stage, frame: CVPixelBuffer, model: MLModel, cause: NSError?)] = [
            (.imageConversion, unconvertible, ScriptedModel(), conversionError),
            (.prediction, blank, ScriptedModel(error: thrown), thrown),
            (.missingLandmarks, blank, ScriptedModel(), nil),
            (.missingScores, blank, ScriptedModel(outputs: boxesOnly), nil)
        ]

        for row in rows {
            let model = FaceDetectorShortRange.Model(row.model)
            let handler = RecordingResultHandler()
            model.setResultHandler(detectionResultHandler: handler)

            model.detectFaces(from: row.frame)

            XCTAssertEqual(handler.calls, ["frameReport", "noFace"], row.stage.rawValue)
            let failure = try XCTUnwrap(handler.reports.first?.failure, row.stage.rawValue)
            XCTAssertEqual(failure.stage, row.stage)
            XCTAssertEqual(failure.cause.map { $0 as NSError }, row.cause, row.stage.rawValue)
        }
    }

    /// Given: A model scoring every anchor 4.54e-5 but one at 0.1192, and a 0.9 threshold, as in Android's test
    /// When: A frame is analyzed
    /// Then: No face passes, and the report's top score is still 0.1192
    func testTheTopScoreIncludesScoresBelowTheThreshold() throws {
        var scores = [Float](repeating: 4.54e-5, count: 896)
        scores[1] = 0.1192
        let model = FaceDetectorShortRange.Model(ScriptedModel(outputs: try scriptedOutputs(scores: scores)))
        let frame = try makeBlankFrame()
        let configuration = LivenessDiagnosticsFixture.movementConfiguration(faceDetectionThreshold: 0.9)

        let report = withConfiguration(configuration, on: model) { model.analyze(frame).report }

        XCTAssertNil(report.failure)
        XCTAssertEqual(report.faceCount, 0)
        XCTAssertEqual(report.topScore, 0.1192)
    }
}
