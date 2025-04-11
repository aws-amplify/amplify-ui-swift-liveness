//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Vision
import CoreML
import Accelerate
import CoreGraphics
import CoreImage
import VideoToolbox

enum FaceDetectorShortRange {}

extension FaceDetectorShortRange {
    final class Model: FaceDetector {
        var model: MLModel
        let confidenceScoreThreshold: Float = 0.7
        let weightedNonMaxSuppressionThreshold: Float = 0.3

        init(_ model: MLModel) {
            self.model = model
        }

        convenience init() throws {
            try self.init(
                face_detection_short_range(
                    configuration: .init()
                ).model
            )
        }

        weak var detectionResultHandler: FaceDetectionResultHandler?

        func setResultHandler(detectionResultHandler: FaceDetectionResultHandler) {
            self.detectionResultHandler = detectionResultHandler
        }

        func detectFaces(from buffer: CVPixelBuffer) {
            let faces = prediction(for: buffer)
            let observationResult: FaceDetectionResult
            switch faces.count {
            case 1:
                observationResult = .singleFace(faces[0])
            case 2...:
                observationResult = .multipleFaces
            default:
                observationResult = .noFace
            }

            detectionResultHandler?.process(newResult: observationResult)
        }

        func prediction(for buffer: CVPixelBuffer) -> [DetectedFace] {
            var image: CGImage?
            VTCreateCGImageFromCVPixelBuffer(buffer, options: nil, imageOut: &image)
            guard let image = image else { return [] }
            let imageHeight = Float32(image.height)
            let imageWidth = Float32(image.width)

            let heightScale = max(imageHeight, imageWidth) / imageHeight
            let widthScale = max(imageHeight, imageWidth) / imageWidth
            let simdScale = SIMD2(Double(widthScale), Double(heightScale))
            let simdShift = SIMD2(Double(widthScale - 1) / 2, Double(heightScale - 1) / 2)

            guard let input = try? face_detection_short_rangeInput(imageWith: image) else {
                return []
            }

            guard let output = try? model.prediction(from: input) else {
                return []
            }

            guard let landmarksMultiArray = output.featureValue(for: "1477")?.multiArrayValue else { return [] }

            let landmarksCapacity = landmarksMultiArray.count / 16

            let boundLandmarks = landmarksMultiArray.dataPointer.bindMemory(
                to: SIMD16<Float32>.self,
                capacity: landmarksCapacity
            )

            let landmarks = [SIMD16<Float32>](
                UnsafeBufferPointer(
                    start: boundLandmarks,
                    count: landmarksCapacity
                )
            )

            guard let confidenceScoresMultiArray = output.featureValue(for: "1011")?.multiArrayValue else { return [] }

            let confidenceScoresCapacity = confidenceScoresMultiArray.count

            let boundConfidenceScores = confidenceScoresMultiArray.dataPointer.bindMemory(
                to: Float32.self,
                capacity: confidenceScoresCapacity
            )

            let confidenceScores = [Float32](
                UnsafeBufferPointer(
                    start: boundConfidenceScores,
                    count: confidenceScoresCapacity
                )
            )

            var passingConfidenceScoresIndices = confidenceScores
                .enumerated()
                .filter { $0.element >= confidenceScoreThreshold }
                .sorted(by: {
                    $0.element > $1.element
                })
                .map(\.offset)

            var faces = [DetectedFace]()

            while passingConfidenceScoresIndices.count > 0 {
                var overlappingOutputs = [SIMD16<Float32>]()
                var overlappingConfidenceScore = Float32(0)
                var nonOverlappingIndices = [Int]()
                for index in 0..<passingConfidenceScoresIndices.count {

                    let intersectionOverUnion = intersectionOverUnion(
                        landmarks[passingConfidenceScoresIndices[0]],
                        landmarks[passingConfidenceScoresIndices[index]]
                    )

                    if intersectionOverUnion >= weightedNonMaxSuppressionThreshold {
                        overlappingOutputs.append(
                            confidenceScores[passingConfidenceScoresIndices[index]] * landmarks[passingConfidenceScoresIndices[index]]
                        )
                        overlappingConfidenceScore += confidenceScores[passingConfidenceScoresIndices[index]]
                    } else {
                        nonOverlappingIndices.append(passingConfidenceScoresIndices[index])
                    }
                }

                passingConfidenceScoresIndices = nonOverlappingIndices
                let averageResult = overlappingOutputs.reduce(SIMD16<Float32>(repeating: 0), +) / overlappingConfidenceScore

                var faceResult = [SIMD2<Double>]()
                for i in 0..<8 {
                    let faceL = SIMD2(
                        Double(averageResult[2 * i]),
                        Double(averageResult[2 * i + 1])
                    ) * simdScale - simdShift
                    faceResult.append(faceL)
                }

                let minX = faceResult[0].x
                let minY = faceResult[0].y
                let maxX = faceResult[1].x
                let maxY = faceResult[1].y
                let rightEye = faceResult[2]
                let leftEye = faceResult[3]
                let nose = faceResult[4]
                let mouth = faceResult[5]
                let rightEar = faceResult[6]
                let leftEar = faceResult[7]
                


                let boundingBox = CGRect(
                    x: minX,
                    y: minY,
                    width: maxX - minX,
                    height: maxY - minY
                )

                let face = DetectedFace(
                    boundingBox: boundingBox,
                    leftEye: .init(x: leftEye.x, y: leftEye.y),
                    rightEye: .init(x: rightEye.x, y: rightEye.y),
                    nose: .init(x: nose.x, y: nose.y),
                    mouth: .init(x: mouth.x, y: mouth.y),
                    rightEar: .init(x: rightEar.x, y: rightEar.y),
                    leftEar: .init(x: leftEar.x, y: leftEar.y),
                    confidence: overlappingConfidenceScore / Float(overlappingOutputs.count)
                )

                faces.append(face)
            }

            return faces
        }

        func intersectionOverUnion(_ b1: SIMD16<Float32>, _ b2: SIMD16<Float32>) -> Float {
            func points(for box: SIMD16<Float32>) -> (minX: Float, minY: Float, maxX: Float, maxY: Float) {
                (box[1], box[0], box[3], box[2])
            }

            let b1 = points(for: b1)
            let b2 = points(for: b2)

            let areaB1 = (b1.maxY - b1.minY) * (b1.maxX - b1.minX)
            if areaB1 <= 0 { return 0 }

            let areaB2 = (b2.maxY - b2.minY) * (b2.maxX - b2.minX)
            if areaB2 <= 0 { return 0 }

            let intersectionMinX = max(b1.minX, b2.minX)
            let intersectionMinY = max(b1.minY, b2.minY)
            let intersectionMaxX = min(b1.maxX, b2.maxX)
            let intersectionMaxY = min(b1.maxY, b2.maxY)

            let intersectionArea = max(0, intersectionMaxY - intersectionMinY) *
            max(0, intersectionMaxX - intersectionMinX)

            return intersectionArea / (areaB1 + areaB2 - intersectionArea)
        }
    }
}
