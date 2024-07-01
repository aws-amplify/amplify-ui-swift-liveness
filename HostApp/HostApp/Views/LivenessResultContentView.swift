//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

struct LivenessResultContentView: View {
    @State var result: Result = .init(livenessResult: .init(auditImageBytes: nil, confidenceScore: -1, isLive: false, challenge: nil))
    let fetchResults: () async throws -> Result

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Result:")
                Text(result.text)
                    .fontWeight(.semibold)
            }

            HStack {
                Text("Liveness confidence score:")
                Text(result.value)
                    .foregroundColor(result.valueTextColor)
                    .padding(6)
                    .background(result.valueBackgroundColor)
                    .cornerRadius(8)
            }

            if let image = result.auditImage {
                Image(uiImage: .init(data: image) ?? UIImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                    .background(Color.secondary.opacity(0.1))
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 128))
                    .frame(maxWidth: .infinity, idealHeight: 268)
                    .background(Color.secondary.opacity(0.1))
            }
            
            if !result.isLive {
                steps()
                    .padding()
                    .background(
                        Rectangle()
                            .foregroundColor(
                                .dynamicColors(
                                    light: .hex("#ECECEC"),
                                    dark: .darkGray
                                )
                            )
                            .cornerRadius(6))
            }
        }
        .padding(.bottom, 16)
        .onAppear {
            Task {
                do {
                    self.result = try await fetchResults()
                } catch {
                    print("Error fetching result", error)
                }
            }
        }
    }
    
    func step(number: Int, text: String) -> some View {
        HStack(alignment: .top) {
            Text("\(number).")
            Text(text)
        }
    }
    
    @ViewBuilder
    private func steps() -> some View {
        switch result.challenge?.type {
        case .faceMovementChallenge:
            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                Text("Tips to pass the video check:")
                    .fontWeight(.semibold)
                
                Text("Remove sunglasses, mask, hat, or anything blocking your face.")
                    .accessibilityElement(children: .combine)
            }
        case .faceMovementAndLightChallenge:
            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                Text("Tips to pass the video check:")
                    .fontWeight(.semibold)
                
                step(number: 1, text: "Avoid very bright lighting conditions, such as direct sunlight.")
                    .accessibilityElement(children: .combine)
                
                step(number: 2, text: "Remove sunglasses, mask, hat, or anything blocking your face.")
                    .accessibilityElement(children: .combine)
            }
        case .none:
            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                EmptyView()
            }
        }
    }
}


extension LivenessResultContentView {
    static let mock = LivenessResultContentView(
        fetchResults: {
            .init(
                livenessResult: .init(
                    auditImageBytes: nil,
                    confidenceScore: 99.8329,
                    isLive: true,
                    challenge: nil
                )
            )
        }
    )
}

struct LivenessResultContentView_Previews: PreviewProvider {
    static var previews: some View {
        LivenessResultContentView.mock
    }
}
