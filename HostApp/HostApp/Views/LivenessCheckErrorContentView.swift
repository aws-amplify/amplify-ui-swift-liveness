//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct LivenessCheckErrorContentView: View {
    let name: String
    let description: String

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.hex("#950404"))
                Text("Error: \(name)")
                    .fontWeight(.semibold)
            }
            .padding(.bottom, 4)
            Text(description)
        }
    }
}

extension LivenessCheckErrorContentView {
    static let mock = LivenessCheckErrorContentView(
        name: "Time out",
        description: "Face didn't fit inside oval in time limit. Try again and completely fill the oval with face in it."
    )

    static let unexpected = LivenessCheckErrorContentView(
        name: "An unexpected error ocurred",
        description: "Please try again."
    )

    static let faceMatchTimeOut = LivenessCheckErrorContentView(
        name: "Time out",
        description: "Face did not fill oval in time limit. Try again and completely fill the oval with face in it."
    )

    static let sessionTimeOut = LivenessCheckErrorContentView(
        name: "Connection interrupted",
        description: "Your connection was unexpectedly closed."
    )

    static let failedDuringCountdown = LivenessCheckErrorContentView(
        name: "Check failed during countdown",
        description: "Avoid moving closer during countdown and ensure only one face is in front of camera."
    )

    static let invalidSignature = LivenessCheckErrorContentView(
        name: "The signature on the request is invalid.",
        description: "Ensure the device time is correct and try again."
    )

    static let cameraNotAvailable = LivenessCheckErrorContentView(
        name: "The camera could not be started.",
        description: "There might be a hardware issue with the camera."
    )

}

struct LivenessCheckErrorContentView_Previews: PreviewProvider {
    static var previews: some View {
        LivenessCheckErrorContentView.mock
    }
}
