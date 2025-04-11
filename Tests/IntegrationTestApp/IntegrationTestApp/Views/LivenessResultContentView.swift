//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct LivenessResultContentView: View {
    @State var result: Result = .init(livenessResult: .init(auditImageBytes: nil, confidenceScore: -1, isLive: false))
    let fetchResults: () async throws -> Result

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Result:")
                Text(result.text)
                    .fontWeight(.semibold)
                    .foregroundColor(result.valueTextColor)
                    .padding(6)
                    .background(result.valueBackgroundColor)
                    .cornerRadius(8)

            }
            .padding(.bottom, 12)

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
                        
    private func steps() -> some View {
        func step(number: Int, text: String) -> some View {
            HStack(alignment: .top) {
                Text("\(number).")
                Text(text)
            }
        }

        return VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text("Tips to pass the video check:")
                .fontWeight(.semibold)
            step(number: 1, text: "Maximize your screen's brightness.")
                .accessibilityElement(children: .combine)

            step(number: 2, text: "Avoid very bright lighting conditions, such as direct sunlight.")
                .accessibilityElement(children: .combine)

            step(number: 3, text: "Remove sunglasses, mask, hat, or anything blocking your face.")
                .accessibilityElement(children: .combine)
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
                    isLive: true
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
