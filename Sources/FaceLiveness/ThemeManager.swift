//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//
import SwiftUI

public class ThemeManager {
	public static var shared = ThemeManager()

	// Public properties with default values
	public var livenessPrimaryBackground = Color.dynamicColors(
		light: .hex("#047D95"),
		dark: .hex("#7DD6E8")
	)

	public var livenessPrimaryLabel = Color.dynamicColors(
		light: .white,
		dark: .hex("#0D1926")
	)

	public var livenessBackground = Color.dynamicColors(
		light: .white,
		dark: .hex("#0D1926")
	)

	public var livenessLabel = Color.dynamicColors(
		light: .black,
		dark: .white
	)

	public var livenessErrorBackground = Color.dynamicColors(
		light: .hex("#950404"),
		dark: .hex("#EF8F8F")
	)

	public var livenessErrorLabel = Color.dynamicColors(
		light: .white,
		dark: .black
	)

	public var livenessWarningBackground = Color.dynamicColors(
		light: .hex("#B8CEF9"),
		dark: .hex("#663300")
	)

	public var livenessWarningLabel = Color.dynamicColors(
		light: .hex("#002266"),
		dark: .hex("#EFBF8F")
	)

	public var livenessPreviewBorder = Color.dynamicColors(
		light: .hex("#AEB3B7"),
		dark: .white
	)
}


extension ThemeManager {
	
	// Public functions to modify the colors
	public func setLivenessPrimaryBackground(light: UIColor, dark: UIColor) {
		livenessPrimaryBackground = Color.dynamicColors(light: light, dark: dark)
	}
	
	public func setLivenessPrimaryLabel(light: UIColor, dark: UIColor) {
		livenessPrimaryLabel = Color.dynamicColors(light: light, dark: dark)
	}
	
	public func setLivenessBackground(light: UIColor, dark: UIColor) {
		livenessBackground = Color.dynamicColors(light: light, dark: dark)
	}
	
	public func setLivenessLabel(light: UIColor, dark: UIColor) {
		livenessLabel = Color.dynamicColors(light: light, dark: dark)
	}
	
	public func setLivenessErrorBackground(light: UIColor, dark: UIColor) {
		livenessErrorBackground = Color.dynamicColors(light: light, dark: dark)
	}
	
	public func setLivenessErrorLabel(light: UIColor, dark: UIColor) {
		livenessErrorLabel = Color.dynamicColors(light: light, dark: dark)
	}
	
	public func setLivenessWarningBackground(light: UIColor, dark: UIColor) {
		livenessWarningBackground = Color.dynamicColors(light: light, dark: dark)
	}
	
	public func setLivenessWarningLabel(light: UIColor, dark: UIColor) {
		livenessWarningLabel = Color.dynamicColors(light: light, dark: dark)
	}
	
	public func setLivenessPreviewBorder(light: UIColor, dark: UIColor) {
		livenessPreviewBorder = Color.dynamicColors(light: light, dark: dark)
	}
	// Add similar functions for other colors as needed...
}
