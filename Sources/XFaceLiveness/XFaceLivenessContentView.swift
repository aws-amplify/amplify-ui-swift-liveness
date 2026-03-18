//
//  XFaceLivenessContentView.swift
//  XFaceLiveness
//
//  Created by Ruslan Serebriakov on 3/17/26.
//  Copyright © 2026 X Corp. All rights reserved.
//

import SwiftUI
import FaceLivenessCore

struct XFaceLivenessDetectorWrapper: View {

    let sessionID: String
    let region: String
    let onSuccess: () -> Void
    let onFailure: () -> Void

    @State private var isPresented = true

    var body: some View {
        if isPresented {
            // Use XFaceLivenessDetectorView for dark theme
            // disableStartView: true - skip "Get ready for your video selfie" step
            // Goes directly to face detection with "Put your face in the circle"
            XFaceLivenessDetectorView(
                sessionID: sessionID,
                region: region,
                disableStartView: true,
                isPresented: $isPresented,
                onCompletion: { result in
                    handleResult(result)
                }
            )
        } else {
            Color.black.ignoresSafeArea()
        }
    }

    private func handleResult(_ result: Result<Void, FaceLivenessDetectionError>) {
        switch result {
        case .success:
            NSLog("[FaceLiveness] ✅ Success")
            onSuccess()
        case .failure(let error):
            NSLog("[FaceLiveness] ❌ Failed:  message=%@", error.message)
            onFailure()
        }
    }
}
