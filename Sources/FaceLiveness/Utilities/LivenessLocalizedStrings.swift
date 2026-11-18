//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

// computed on every read, so a language the app switches to while running is picked up (#280)
enum LocalizedStrings {
    /// en = "Photosensitivity Warning"
    static var get_ready_photosensitivity_title: String { "amplify_ui_liveness_get_ready_photosensitivity_title".localized() }

    /// en = "This check displays colored lights. Use caution if you are photosensitive."
    static var get_ready_photosensitivity_description: String { "amplify_ui_liveness_get_ready_photosensitivity_description".localized() }

    /// en = "Photosensitivity Information"
    static var get_ready_photosensitivity_icon_a11y: String { "amplify_ui_liveness_get_ready_photosensitivity_icon_a11y".localized() }

    /// en = "Photosensitivity warning"
    static var get_ready_photosensitivity_dialog_title: String { "amplify_ui_liveness_get_ready_photosensitivity_dialog_title".localized() }

    /// en = "A small percentage of individuals may experience epileptic seizures when exposed to colored lights. Use caution if you, or anyone in your family, have an epileptic condition."
    static var get_ready_photosensitivity_dialog_description: String { "amplify_ui_liveness_get_ready_photosensitivity_dialog_description".localized() }

    /// en = "Start video check"
    static var get_ready_begin_check: String { "amplify_ui_liveness_get_ready_begin_check".localized() }

    /// en = "REC"
    static var challenge_recording_indicator_label: String { "amplify_ui_liveness_challenge_recording_indicator_label".localized() }

    /// en = "Move back"
    static var challenge_instruction_move_face_back: String { "amplify_ui_liveness_challenge_instruction_move_face_back".localized() }

    /// en = "Move closer"
    static var challenge_instruction_move_face_closer: String { "amplify_ui_liveness_challenge_instruction_move_face_closer".localized() }

    /// en = "Hold still"
    static var challenge_instruction_hold_still: String { "amplify_ui_liveness_challenge_instruction_hold_still".localized() }

    /// en = "Only one face per check"
    static var challenge_instruction_multiple_faces_detected: String { "amplify_ui_liveness_challenge_instruction_multiple_faces_detected".localized() }

    /// en = "Connecting..."
    static var challenge_connecting: String { "amplify_ui_liveness_challenge_connecting".localized() }

    /// en = "Verifying"
    static var challenge_verifying: String { "amplify_ui_liveness_challenge_verifying".localized() }

    /// en = "Change Your Camera Settings"
    static var camera_setting_alert_title: String { "amplify_ui_liveness_camera_setting_alert_title".localized() }

    /// en = "Allow camera permission in settings."
    static var camera_setting_alert_message: String { "amplify_ui_liveness_camera_setting_alert_message".localized() }

    /// en = "Update Setting"
    static var camera_setting_alert_update_setting_button_text: String { "amplify_ui_liveness_camera_setting_alert_update_setting_button_text".localized() }

    /// en = "Not Now"
    static var camera_setting_alert_not_now_button_text: String { "amplify_ui_liveness_camera_setting_alert_not_now_button_text".localized() }

    /// en = "Close"
    static var close_button_a11y: String { "amplify_ui_liveness_close_button_a11y".localized() }

    /// en = "Portrait orientation required"
    static var orientation_prompt_title: String { "amplify_ui_liveness_orientation_prompt_title".localized() }

    /// en = "Rotate your device to portrait (vertical) orientation to continue."
    static var orientation_prompt_description: String { "amplify_ui_liveness_orientation_prompt_description".localized() }
    
    /// en = "Center your face"
    static var preview_center_your_face_text: String { "amplify_ui_liveness_center_your_face_text".localized() }
    
    /// en = "Change Camera Setting"
    static var camera_permission_change_setting_button_title: String { "amplify_ui_liveness_camera_permission_button_title".localized() }
    
    /// en = "Camera is not accessible"
    static var camera_permission_change_setting_header: String { "amplify_ui_liveness_camera_permission_button_header".localized() }
    
    /// en = "You may have to go into settings to grant camera permissions and close the app and retry"
    static var camera_permission_change_setting_description: String { "amplify_ui_liveness_camera_permission_button_description".localized() }
    
    /// en = ""
    static var amplify_ui_liveness_face_not_prepared_reason_pendingCheck: String { "amplify_ui_liveness_face_not_prepared_reason_pendingCheck".localized() }
    
    /// en = "Move closer"
    static var amplify_ui_liveness_face_not_prepared_reason_move_face_closer: String { "amplify_ui_liveness_face_not_prepared_reason_move_face_closer".localized() }
    
    /// en = "Move face in front of camera"
    static var amplify_ui_liveness_face_not_prepared_reason_no_face: String { "amplify_ui_liveness_face_not_prepared_reason_no_face".localized() }
    
    /// en = "Move face farther away"
    static var amplify_ui_liveness_face_not_prepared_reason_face_too_close: String { "amplify_ui_liveness_face_not_prepared_reason_face_too_close".localized() }
}
