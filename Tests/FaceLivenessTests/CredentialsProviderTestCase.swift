//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import SwiftUI
import AWSPluginsCore
@testable import FaceLiveness
@testable import AWSPredictionsPlugin
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

@MainActor
final class CredentialsProviderTestCase: XCTestCase {
    var videoChunker: VideoChunker!
    var viewModel: FaceLivenessDetectionViewModel!
    var faceDetector: MockFaceDetector!
    var livenessService: MockLivenessService!

    override func setUp() {
        faceDetector = MockFaceDetector()
        livenessService = MockLivenessService()
        let videoChunker = VideoChunker(
            assetWriter: LivenessAVAssetWriter(),
            assetWriterDelegate: VideoChunker.AssetWriterDelegate(),
            assetWriterInput: LivenessAVAssetWriterInput()
        )
        let captureSession = LivenessCaptureSession(
            captureDevice: .init(avCaptureDevice: nil),
            outputDelegate: OutputSampleBufferCapturer(
                faceDetector: faceDetector,
                videoChunker: videoChunker
            )
        )

        let viewModel = FaceLivenessDetectionViewModel(
            faceDetector: faceDetector,
            faceInOvalMatching: .init(instructor: .init()),
            videoChunker: videoChunker,
            closeButtonAction: {},
            sessionID: UUID().uuidString,
            isPreviewScreenEnabled: false,
            challengeOptions: .init(faceMovementChallengeOption: .init(camera: .front),
                                    faceMovementAndLightChallengeOption: .init())
        )

        self.videoChunker = videoChunker
        self.viewModel = viewModel
    }

    /// Given: A `FaceLivenessDetectorView`
    /// When: The callsite provides an `AWSCredentialsProvider` conforming type that provides
    /// an `AWSCredentials` conforming type
    /// Then: The provided `accessKeyId` and `secretAccessKey` should
    /// match that of credentials used by the underlying `SigV4Signer`. **And** the
    /// sessionToken should be `nil`
    func testUsesProvidedCredentialsProvider() async throws {
        let accessKey = "AKIAIOSFODNN7EXAMPLE"
        let secretKey = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        let credentialsProvider = MockCredentialsProvider {
            MockAWSCredentials(accessKeyId: accessKey, secretAccessKey: secretKey)
        }

        let liveness = FaceLivenessDetectorView(
            sessionID: UUID().uuidString,
            credentialsProvider: credentialsProvider,
            region: "us-east-1",
            challengeOptions: .init(faceMovementChallengeOption: .init(camera: .front), 
                                    faceMovementAndLightChallengeOption: .init()),
            isPresented: .constant(true),
            onCompletion: { _ in }
        )

        let session = try await liveness.sessionTask.value
        let credential = session.signer.credential

        XCTAssertEqual(accessKey, credential.accessKey)
        XCTAssertEqual(secretKey, credential.secretKey)
        XCTAssertNil(credential.sessionToken)
    }


    /// Given: A `FaceLivenessDetectorView`
    /// When: The callsite provides an `AWSCredentialsProvider` conforming type that provides
    /// an `AWSTemporaryCredentials` conforming type
    /// Then: The provided `accessKeyId`, `secretAccessKey`, **and** `sessionToken` should
    /// match that of credentials used by the underlying `SigV4Signer`
    func testUsesProvidedCredentialsProvider_temporaryCredentials() async throws {
        let accessKey = "AKIAIOSFODNN7EXAMPLE"
        let secretKey = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        let sessionToken = "MOCK_SESSION_TOKEN"

        let credentialsProvider = MockCredentialsProvider {
            MockAWSTemporaryCredentials(
                sessionToken: sessionToken,
                expiration: .distantFuture,
                accessKeyId: accessKey,
                secretAccessKey: secretKey
            )
        }

        let liveness = FaceLivenessDetectorView(
            sessionID: UUID().uuidString,
            credentialsProvider: credentialsProvider,
            region: "us-east-1",
            challengeOptions: .init(faceMovementChallengeOption: .init(camera: .front),
                                    faceMovementAndLightChallengeOption: .init()),
            isPresented: .constant(true),
            onCompletion: { _ in }
        )

        let session = try await liveness.sessionTask.value
        let credential = session.signer.credential

        XCTAssertEqual(accessKey, credential.accessKey)
        XCTAssertEqual(secretKey, credential.secretKey)
        XCTAssertEqual(sessionToken, credential.sessionToken)
    }
}
