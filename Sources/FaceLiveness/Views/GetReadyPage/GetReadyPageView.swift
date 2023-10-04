//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct GetReadyPageView: View {
    @Binding var displayingCameraPermissionsNeededAlert: Bool
    let beginCheckButtonDisabled: Bool
    let onBegin: () -> Void

    init(
        displayingCameraPermissionsNeededAlert: Binding<Bool> = .constant(false),
        onBegin: @escaping () -> Void,
        beginCheckButtonDisabled: Bool = false
    ) {
        self._displayingCameraPermissionsNeededAlert = displayingCameraPermissionsNeededAlert
        self.onBegin = onBegin
        self.beginCheckButtonDisabled = beginCheckButtonDisabled
    }

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading) {
                    Text(LocalizedStrings.get_ready_page_title)
                        .font(.system(size: 34, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)
                        .padding(.bottom, 8)

                    Text(LocalizedStrings.get_ready_page_description)
                        .padding(.bottom, 8)

                    WarningBox(
                        titleText: LocalizedStrings.get_ready_photosensitivity_title,
                        bodyText: LocalizedStrings.get_ready_photosensitivity_description,
                        popoverContent: { photosensitivityWarningPopoverContent }
                    )
                    .accessibilityElement(children: .combine)
                    .padding(.bottom, 8)

                    Text(LocalizedStrings.get_ready_steps_title)
                        .fontWeight(.semibold)
                        .padding(.bottom, 16)

                    OvalIllustrationExamples()
                        .accessibilityHidden(true)
                        .padding(.bottom)

                    steps()
                }
                .padding()
            }

            beginCheckButton
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

    private var beginCheckButton: some View {
        Button(
            action: onBegin,
            label: {
                Text(LocalizedStrings.get_ready_begin_check)
                    .foregroundColor(.livenessPrimaryLabel)
                    .frame(maxWidth: .infinity)
            }
        )
        .disabled(beginCheckButtonDisabled)
        .frame(height: 52)
        ._background { Color.livenessPrimaryBackground }
        .cornerRadius(14)
        .padding([.leading, .trailing])
        .padding(.bottom, 16)
    }

    private var photosensitivityWarningPopoverContent: some View {
        VStack {
            Text(LocalizedStrings.get_ready_photosensitivity_dialog_title)
                .font(.system(size: 20, weight: .medium))
                .frame(alignment: .center)
                .padding()
            Text(LocalizedStrings.get_ready_photosensitivity_dialog_description)
                .padding()
            Spacer()
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
            spacing: 16
        ) {
            step(number: 1, text: LocalizedStrings.get_ready_fit_face)
                .accessibilityElement(children: .combine)

            step(number: 2, text: LocalizedStrings.get_ready_face_not_covered)
                .accessibilityElement(children: .combine)

            step(number: 3, text: LocalizedStrings.get_ready_lighting)
                .accessibilityElement(children: .combine)
        }
    }
}

struct GetReadyPageView_Previews: PreviewProvider {
    static var previews: some View {
        GetReadyPageView(onBegin: {})
    }
}
