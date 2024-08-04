//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct LoadingPageView: View {
    
    var body: some View {
        VStack {
            HStack(spacing: 5) {
                ProgressView()
                Text(LocalizedStrings.challenge_connecting)
            }
            
        }
    }
}

struct LoadingPageView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingPageView()
    }
}
