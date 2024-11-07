//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

// sample Usage
// import AmplifyUILiveness

//  Modify colors in the client app
// ThemeManager.shared.setLivenessPrimaryBackground(
//	 light: .red, // Example light color
//	 dark: .blue  // Example dark color
// )

//  Access modified color
//	let modifiedColor = Color.livenessPrimaryBackground


import SwiftUI

extension Color {
	public static var livenessPrimaryBackground: Color {
		return ThemeManager.shared.livenessPrimaryBackground
	}

	public static var livenessPrimaryLabel: Color {
		return ThemeManager.shared.livenessPrimaryLabel
	}

	public static var livenessBackground: Color {
		return ThemeManager.shared.livenessBackground
	}

	public static var livenessLabel: Color {
		return ThemeManager.shared.livenessLabel
	}

	public static var livenessErrorBackground: Color {
		return ThemeManager.shared.livenessErrorBackground
	}

	public static var livenessErrorLabel: Color {
		return ThemeManager.shared.livenessErrorLabel
	}

	public static var livenessWarningBackground: Color {
		return ThemeManager.shared.livenessWarningBackground
	}

	public static var livenessWarningLabel: Color {
		return ThemeManager.shared.livenessWarningLabel
	}

	public static var livenessPreviewBorder: Color {
		return ThemeManager.shared.livenessPreviewBorder
	}
}

