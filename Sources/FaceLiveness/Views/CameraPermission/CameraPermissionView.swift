//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct CameraPermissionView: View {
    @Binding var displayingCameraPermissionsNeededAlert: Bool

    init(
        displayingCameraPermissionsNeededAlert: Binding<Bool> = .constant(false)
    ) {
        self._displayingCameraPermissionsNeededAlert = displayingCameraPermissionsNeededAlert
    }

    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
            VStack {
                Text(LocalizedStrings.camera_permission_change_setting_header)
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(8)
                    
                Text(LocalizedStrings.camera_permission_change_setting_description)
                    .multilineTextAlignment(.center)
                    .padding(8)
            }
            Spacer()
            editPermissionButton
        }
        .alert(isPresented: $displayingCameraPermissionsNeededAlert) {
            Alert(
                title: Text(LocalizedStrings.camera_setting_alert_title),
                message: Text(LocalizedStrings.camera_setting_alert_message),
                primaryButton: .default(
                    Text(LocalizedStrings.camera_setting_alert_update_setting_button_text).bold(),
                    action: {
                        goToSettingsAppPage()
                    }),
                secondaryButton: .default(
                    Text(LocalizedStrings.camera_setting_alert_not_now_button_text)
                )
            )
        }
    }

    private func goToSettingsAppPage() {
        guard let settingsAppURL = URL(string: UIApplication.openSettingsURLString)
        else { return }
        UIApplication.shared.open(settingsAppURL, options: [:])
    }

    private var editPermissionButton: some View {
        Button(
            action: goToSettingsAppPage,
            label: {
                Text(LocalizedStrings.camera_permission_change_setting_button_title)
                    .foregroundColor(.livenessPrimaryLabel)
                    .frame(maxWidth: .infinity)
            }
        )
        .frame(height: 52)
        ._background { Color.livenessPrimaryBackground }
        .cornerRadius(14)
        .padding([.leading, .trailing])
        .padding(.bottom, 16)
    }
}

struct CameraPermissionView_Previews: PreviewProvider {
    static var previews: some View {
        CameraPermissionView()
    }
}
