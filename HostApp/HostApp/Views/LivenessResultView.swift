//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct LivenessResultView<Content: View>: View {
    let title: String
    let sessionID: String
    let content: Content
    let onTryAgain: () -> Void
    @State var displayingCopiedNotification = false

    init(
        title: String = "Liveness Result",
        sessionID: String,
        onTryAgain: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.sessionID = sessionID
        self.content = content()
        self.onTryAgain = onTryAgain
    }

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.system(size: 34, weight: .semibold))
                        .padding(.bottom, 8)

                    sessionIDBox
                        .padding(.bottom, 16)

                    content
                }
                .padding()
            }

            if displayingCopiedNotification {
                Text("Copied Session ID")
                    .foregroundColor(.dynamicColors(light: .white, dark: .black))
                    .padding(8)
                    .background(Color.dynamicColors(light: .darkGray, dark: .lightGray))
                    .cornerRadius(6)
                    .onAppear {
                        Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in
                            withAnimation {
                                displayingCopiedNotification = false
                            }
                        }
                    }
            }
            tryAgainButton
        }
    }

    private func copySessionID() {
        withAnimation {
            displayingCopiedNotification = true
        }
        UIPasteboard.general.string = sessionID
    }

    private var sessionIDBox: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Session ID:")
                    .fontWeight(.semibold)
                Text(sessionID)
            }
            Spacer()
            Button(
                action: copySessionID,
                label: {
                    Image(systemName: "square.on.square")
                        .foregroundColor(.primary)
                        .frame(width: 20, height: 20)
                }
            )
            .frame(width: 44, height: 44)
        }
        .padding()
        .background(
            Rectangle()
                .foregroundColor(
                    .dynamicColors(
                        light: .hex("#ECECEC"),
                        dark: .darkGray
                    )
                )
                .cornerRadius(6)
        )
    }

    private var tryAgainButton: some View {
        Button(
            action: onTryAgain,
            label: {
                Text("Try Again")
                    .foregroundColor(
                        .dynamicColors(light: .white, dark: .black)
                    )
                    .frame(maxWidth: .infinity)
            }
        )
        .frame(height: 52)
        ._background {
            Color.dynamicColors(light: .hex("#047D95"), dark: .hex("#7dd6e8"))
        }
        .cornerRadius(14)
        .padding(.leading)
        .padding(.trailing)
        .padding(.bottom, 16)
    }
}

extension LivenessResultView where Content == LivenessResultContentView {
    static var sessionID: String {
        String(UUID().uuidString.flatMap { $0.lowercased() })
    }

    static var mock: Self {
        .init(
            sessionID: sessionID,
            onTryAgain: {},
            content: { LivenessResultContentView.mock }
        )
    }
}

struct LivenessCheckView_Previews: PreviewProvider {
    static let sessionID = String(UUID().uuidString.flatMap { $0.lowercased() })
    static var previews: some View {
        LivenessResultView(
            sessionID: sessionID,
            onTryAgain: {},
            content: {
                LivenessCheckErrorContentView.mock
            }
        )
    }
}

