//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import UIKit
import SwiftUI

public extension Color {
    static func dynamicColors(light: UIColor, dark: UIColor) -> Color {
        Color(
            UIColor(
                dynamicProvider: { traitCollection in
                    switch traitCollection.userInterfaceStyle {
                    case .dark: return dark
                    default: return light
                    }
                }
            )
        )
    }
    
    internal static let amp = Colors.self
}

extension UIColor {
    convenience init(
        hue: CGFloat,
        saturation: CGFloat,
        lightness: CGFloat,
        opacity: CGFloat = 1
    ) {
        let hue = hue / 360
        let s: CGFloat
        let b = lightness + saturation * min(lightness, 1 - lightness)
        if b == 0 { s = 0 }
        else { s = 2 * (1 - lightness / b) }
        self.init(
            hue: hue,
            saturation: s,
            brightness: b,
            alpha: opacity
        )
    }
}

struct Colors {
    static let red10Light = UIColor.init(hue: 0, saturation: 0.75, lightness: 0.95)
    static let red20Light = UIColor(hue: 0, saturation: 0.75, lightness: 0.85)
    static let red40Light = UIColor(hue: 0, saturation: 0.75, lightness: 0.75)
    static let red60Light = UIColor(hue: 0, saturation: 0.50, lightness: 0.50)
    static let red80Light = UIColor(hue: 0, saturation: 0.95, lightness: 0.30)
    static let red90Light = UIColor(hue: 0, saturation: 1, lightness: 0.20)
    static let red100Light = UIColor(hue: 0, saturation: 1, lightness: 0.15)
    static let orange10Light = UIColor(hue: 30, saturation: 0.75, lightness: 0.95)
    static let orange20Light = UIColor(hue: 30, saturation: 0.75, lightness: 0.85)
    static let orange40Light = UIColor(hue: 30, saturation: 0.75, lightness: 0.75)
    static let orange60Light = UIColor(hue: 30, saturation: 0.50, lightness: 0.50)
    static let orange80Light = UIColor(hue: 30, saturation: 0.95, lightness: 0.30)
    static let orange90Light = UIColor(hue: 30, saturation: 1, lightness: 0.20)
    static let orange100Light = UIColor(hue: 30, saturation: 1, lightness: 0.15)
    static let yellow10Light = UIColor(hue: 60, saturation: 0.75, lightness: 0.95)
    static let yellow20Light = UIColor(hue: 60, saturation: 0.75, lightness: 0.85)
    static let yellow40Light = UIColor(hue: 60, saturation: 0.75, lightness: 0.75)
    static let yellow60Light = UIColor(hue: 60, saturation: 0.50, lightness: 0.50)
    static let yellow80Light = UIColor(hue: 60, saturation: 0.95, lightness: 0.30)
    static let yellow90Light = UIColor(hue: 60, saturation: 1, lightness: 0.20)
    static let yellow100Light = UIColor(hue: 60, saturation: 1, lightness: 0.15)
    static let green10Light = UIColor(hue: 130, saturation: 0.60, lightness: 0.95)
    static let green20Light = UIColor(hue: 130, saturation: 0.60, lightness: 0.90)
    static let green40Light = UIColor(hue: 130, saturation: 0.44, lightness: 0.63)
    static let green60Light = UIColor(hue: 130, saturation: 0.43, lightness: 0.46)
    static let green80Light = UIColor(hue: 130, saturation: 0.33, lightness: 0.37)
    static let green90Light = UIColor(hue: 130, saturation: 0.27, lightness: 0.29)
    static let green100Light = UIColor(hue: 130, saturation: 0.22, lightness: 0.23)
    static let teal10Light = UIColor(hue: 190, saturation: 0.75, lightness: 0.95)
    static let teal20Light = UIColor(hue: 190, saturation: 0.75, lightness: 0.85)
    static let teal40Light = UIColor(hue: 190, saturation: 0.70, lightness: 0.70)
    static let teal60Light = UIColor(hue: 190, saturation: 0.50, lightness: 0.50)
    static let teal80Light = UIColor(hue: 190, saturation: 0.95, lightness: 0.30)
    static let teal90Light = UIColor(hue: 190, saturation: 1, lightness: 0.20)
    static let teal100Light = UIColor(hue: 190, saturation: 1, lightness: 0.15)
    static let blue10Light = UIColor(hue: 220, saturation: 0.95, lightness: 0.95)
    static let blue20Light = UIColor(hue: 220, saturation: 0.85, lightness: 0.85)
    static let blue40Light = UIColor(hue: 220, saturation: 0.70, lightness: 0.70)
    static let blue60Light = UIColor(hue: 220, saturation: 0.50, lightness: 0.50)
    static let blue80Light = UIColor(hue: 220, saturation: 0.95, lightness: 0.30)
    static let blue90Light = UIColor(hue: 220, saturation: 1, lightness: 0.20)
    static let blue100Light = UIColor(hue: 220, saturation: 1, lightness: 0.15)
    static let purple10Light = UIColor(hue: 300, saturation: 0.95, lightness: 0.95)
    static let purple20Light = UIColor(hue: 300, saturation: 0.85, lightness: 0.85)
    static let purple40Light = UIColor(hue: 300, saturation: 0.70, lightness: 0.70)
    static let purple60Light = UIColor(hue: 300, saturation: 0.50, lightness: 0.50)
    static let purple80Light = UIColor(hue: 300, saturation: 0.95, lightness: 0.30)
    static let purple90Light = UIColor(hue: 300, saturation: 1, lightness: 0.20)
    static let purple100Light = UIColor(hue: 300, saturation: 1, lightness: 0.15)
    static let pink10Light = UIColor(hue: 340, saturation: 0.95, lightness: 0.95)
    static let pink20Light = UIColor(hue: 340, saturation: 0.90, lightness: 0.85)
    static let pink40Light = UIColor(hue: 340, saturation: 0.70, lightness: 0.70)
    static let pink60Light = UIColor(hue: 340, saturation: 0.50, lightness: 0.50)
    static let pink80Light = UIColor(hue: 340, saturation: 0.95, lightness: 0.30)
    static let pink90Light = UIColor(hue: 340, saturation: 1, lightness: 0.20)
    static let pink100Light = UIColor(hue: 340, saturation: 1, lightness: 0.15)
    static let neutral10Light = UIColor(hue: 210, saturation: 0.5, lightness: 0.98)
    static let neutral20Light = UIColor(hue: 210, saturation: 0.5, lightness: 0.94)
    static let neutral40Light = UIColor(hue: 210, saturation: 0.5, lightness: 0.87)
    static let neutral60Light = UIColor(hue: 210, saturation: 0.8, lightness: 0.55)
    static let neutral80Light = UIColor(hue: 210, saturation: 0.10, lightness: 0.40)
    static let neutral90Light = UIColor(hue: 210, saturation: 0.25, lightness: 0.25)
    static let neutral100Light = UIColor(hue: 210, saturation: 0.50, lightness: 0.10)
    
    
    static let red10Dark = UIColor(hue: 0, saturation: 1, lightness: 0.15)
    static let red20Dark = UIColor(hue: 0, saturation: 1, lightness: 0.20)
    static let red40Dark = UIColor(hue: 0, saturation: 0.95, lightness: 0.30)
    static let red80Dark = UIColor(hue: 0, saturation: 0.75, lightness: 0.75)
    static let red90Dark = UIColor(hue: 0, saturation: 0.75, lightness: 0.85)
    static let red100Dark = UIColor(hue: 0, saturation: 0.75, lightness: 0.95)
    static let orange10Dark = UIColor(hue: 30, saturation: 1, lightness: 0.15)
    static let orange20Dark = UIColor(hue: 30, saturation: 1, lightness: 0.20)
    static let orange40Dark = UIColor(hue: 30, saturation: 0.95, lightness: 0.30)
    static let orange80Dark = UIColor(hue: 30, saturation: 0.75, lightness: 0.75)
    static let orange90Dark = UIColor(hue: 30, saturation: 0.75, lightness: 0.85)
    static let orange100Dark = UIColor(hue: 30, saturation: 0.75, lightness: 0.95)
    static let yellow10Dark = UIColor(hue: 60, saturation: 1, lightness: 0.15)
    static let yellow20Dark = UIColor(hue: 60, saturation: 1, lightness: 0.20)
    static let yellow40Dark = UIColor(hue: 60, saturation: 0.95, lightness: 0.30)
    static let yellow80Dark = UIColor(hue: 60, saturation: 0.75, lightness: 0.75)
    static let yellow90Dark = UIColor(hue: 60, saturation: 0.75, lightness: 0.85)
    static let yellow100Dark = UIColor(hue: 60, saturation: 0.75, lightness: 0.95)
    static let green10Dark = UIColor(hue: 130, saturation: 0.22, lightness: 0.23)
    static let green20Dark = UIColor(hue: 130, saturation: 0.27, lightness: 0.29)
    static let green40Dark = UIColor(hue: 130, saturation: 0.33, lightness: 0.37)
    static let green80Dark = UIColor(hue: 130, saturation: 0.44, lightness: 0.63)
    static let green90Dark = UIColor(hue: 130, saturation: 0.60, lightness: 0.90)
    static let green100Dark = UIColor(hue: 130, saturation: 0.60, lightness: 0.95)
    static let teal10Dark = UIColor(hue: 190, saturation: 1, lightness: 0.15)
    static let teal20Dark = UIColor(hue: 190, saturation: 1, lightness: 0.20)
    static let teal40Dark = UIColor(hue: 190, saturation: 0.95, lightness: 0.30)
    static let teal80Dark = UIColor(hue: 190, saturation: 0.70, lightness: 0.70)
    static let teal90Dark = UIColor(hue: 190, saturation: 0.75, lightness: 0.85)
    static let teal100Dark = UIColor(hue: 190, saturation: 0.75, lightness: 0.95)
    static let blue10Dark = UIColor(hue: 220, saturation: 1, lightness: 0.15)
    static let blue20Dark = UIColor(hue: 220, saturation: 1, lightness: 0.20)
    static let blue40Dark = UIColor(hue: 220, saturation: 0.95, lightness: 0.30)
    static let blue80Dark = UIColor(hue: 220, saturation: 0.70, lightness: 0.70)
    static let blue90Dark = UIColor(hue: 220, saturation: 0.85, lightness: 0.85)
    static let blue100Dark = UIColor(hue: 220, saturation: 0.95, lightness: 0.95)
    static let purple10Dark = UIColor(hue: 300, saturation: 1, lightness: 0.15)
    static let purple20Dark = UIColor(hue: 300, saturation: 1, lightness: 0.20)
    static let purple40Dark = UIColor(hue: 300, saturation: 0.95, lightness: 0.30)
    static let purple80Dark = UIColor(hue: 300, saturation: 0.70, lightness: 0.70)
    static let purple90Dark = UIColor(hue: 300, saturation: 0.85, lightness: 0.85)
    static let purple100Dark = UIColor(hue: 300, saturation: 0.95, lightness: 0.95)
    static let pink10Dark = UIColor(hue: 340, saturation: 1, lightness: 0.15)
    static let pink20Dark = UIColor(hue: 340, saturation: 1, lightness: 0.20)
    static let pink40Dark = UIColor(hue: 340, saturation: 0.95, lightness: 0.30)
    static let pink80Dark = UIColor(hue: 340, saturation: 0.70, lightness: 0.70)
    static let pink90Dark = UIColor(hue: 340, saturation: 0.90, lightness: 0.85)
    static let pink100Dark = UIColor(hue: 340, saturation: 0.95, lightness: 0.95)
    static let neutral10Dark = UIColor(hue: 210, saturation: 0.50, lightness: 0.10)
    static let neutral20Dark = UIColor(hue: 210, saturation: 0.25, lightness: 0.25)
    static let neutral40Dark = UIColor(hue: 210, saturation: 0.10, lightness: 0.40)
    static let neutral80Dark = UIColor(hue: 210, saturation: 0.5, lightness: 0.87)
    static let neutral90Dark = UIColor(hue: 210, saturation: 0.5, lightness: 0.94)
    static let neutral100Dark = UIColor(hue: 210, saturation: 0.5, lightness: 0.98)

    // --amplify-colors-(.*)-(.*)-(\d*): var\(--amplify-colors-(.*)-(\d*)\);
    // static var $1$2$3: Color { $4$5 }
    static var brandPrimary10: Color { .dynamicColors(light: teal10Light, dark: teal10Dark) }
    static var brandPrimary20: Color { .dynamicColors(light: teal20Light, dark: teal20Dark) }
    static var brandPrimary40: Color { .dynamicColors(light: teal40Light, dark: teal40Dark) }
    static var brandPrimary60: Color { .dynamicColors(light: teal60Light, dark: teal80Dark) }
    static var brandPrimary80: Color { .dynamicColors(light: teal80Light, dark: teal80Dark) }
    static var brandPrimary90: Color { .dynamicColors(light: teal90Light, dark: teal90Dark) }
    static var brandPrimary100: Color { .dynamicColors(light: teal100Light, dark: teal100Dark) }
    static var brandSecondary10: Color { .dynamicColors(light: purple10Light, dark: purple10Dark) }
    static var brandSecondary20: Color { .dynamicColors(light: purple20Light, dark: purple20Dark) }
    static var brandSecondary40: Color { .dynamicColors(light: purple40Light, dark: purple40Dark) }
    static var brandSecondary60: Color { .dynamicColors(light: purple60Light, dark: purple80Dark) }
    static var brandSecondary80: Color { .dynamicColors(light: purple80Light, dark: purple80Dark) }
    static var brandSecondary90: Color { .dynamicColors(light: purple90Light, dark: purple90Dark) }
    static var brandSecondary100: Color { .dynamicColors(light: purple100Light, dark: purple100Dark) }

    static var fontPrimary: Color { .dynamicColors(light: neutral100Light, dark: neutral100Dark) }
    static var fontSecondary: Color {
        .dynamicColors(light: neutral90Light, dark: neutral100Dark)
    }
    static var fontTertiary: Color {
        .dynamicColors(light: neutral80Light, dark: neutral90Dark)
    }
    static var fontDisabled: Color {
        .dynamicColors(light: neutral60Light, dark: neutral80Dark)
    }
    
    static var fontInteractive: Color { brandPrimary80 }
    static var fontHover: Color { brandPrimary90 }
    static var fontFocus: Color { brandPrimary100 }
    static var fontActive: Color { brandPrimary100 }
    static var fontInverse: Color {
        .dynamicColors(light: .white, dark: neutral10Dark)
    }
    
    static var fontInfo: Color { .dynamicColors(light: blue90Light, dark: blue90Dark) }
    static var fontWarning: Color { .dynamicColors(light: orange90Light, dark: orange90Dark) }
    static var fontError: Color { .dynamicColors(light: red90Light, dark: red90Dark) }
    static var fontSuccess: Color { .dynamicColors(light: green90Light, dark: green90Dark) }
    
    static var backgroundPrimary: Color {
        .dynamicColors(light: .white, dark: neutral10Dark)
    }
    static var backgroundSecondary: Color {
        .dynamicColors(light: neutral10Light, dark: neutral20Dark)
    }
    static var backgroundTertiary: Color {
        .dynamicColors(light: neutral20Light, dark: neutral40Dark)
    }
    
    static var backgroundQuaternary: Color { .dynamicColors(light: neutral60Light, dark: neutral80Dark) }
    static var backgroundDisabled: Color { backgroundTertiary }
    

    
    static var backgroundInfo: Color { .dynamicColors(light: blue20Light, dark: blue20Dark) }
    static var backgroundWarning: Color { .dynamicColors(light: orange20Light, dark: orange20Dark) }
    static var backgroundError: Color { .dynamicColors(light: red20Light, dark: red20Dark) }
    static var backgroundSuccess: Color { .dynamicColors(light: green20Light, dark: green20Dark) }
    static var borderPrimary: Color {
        .dynamicColors(light: neutral60Light, dark: neutral80Dark)
    }
    static var borderSecondary: Color {
        .dynamicColors(light: neutral40Light, dark: neutral40Dark)
    }
    
    static var borderTertiary: Color {
        .dynamicColors(light: neutral20Light, dark: neutral20Dark)
    }
    
    static var borderDisabled: Color { borderTertiary }
    static var borderPressed: Color { brandPrimary100 }
    static var borderFocus: Color { brandPrimary100 }
    static var borderError: Color { .dynamicColors(light: red80Light, dark: red80Dark) }
    
    static let shadowPrimaryLight = Color(hue: 210, saturation: 0.50, lightness: 0.25)
    static let shadowSecondaryLight = Color(hue: 210, saturation: 0.50, lightness: 0.15)
    static let shadowTertiaryLight = Color(hue: 210, saturation: 0.50, lightness: 0.05)
}

extension Color {
    init(hue: CGFloat, saturation: CGFloat, lightness: CGFloat) {
        self.init(UIColor(hue: hue, saturation: saturation, lightness: lightness))
    }
}

/*
 

 --amplify-font-sizes-xxxs: 0.375rem;
 --amplify-font-sizes-xxs: 0.5rem;
 --amplify-font-sizes-xs: 0.75rem;
 --amplify-font-sizes-small: 0.875rem;
 --amplify-font-sizes-medium: 1rem;
 --amplify-font-sizes-large: 1.25rem;
 --amplify-font-sizes-xl: 1.5rem;
 --amplify-font-sizes-xxl: 2rem;
 --amplify-font-sizes-xxxl: 2.5rem;
 --amplify-font-sizes-xxxxl: 3rem;
 --amplify-font-weights-hairline: 100;
 --amplify-font-weights-thin: 200;
 --amplify-font-weights-light: 300;
 --amplify-font-weights-normal: 400;
 --amplify-font-weights-medium: 500;
 --amplify-font-weights-semibold: 600;
 --amplify-font-weights-bold: 700;
 --amplify-font-weights-extrabold: 800;
 --amplify-font-weights-black: 900;
 --amplify-line-heights-small: 1.25;
 --amplify-line-heights-medium: 1.5;
 --amplify-line-heights-large: 2;
 --amplify-opacities-0: 0;
 --amplify-opacities-10: 0.1;
 --amplify-opacities-20: 0.2;
 --amplify-opacities-30: 0.3;
 --amplify-opacities-40: 0.4;
 --amplify-opacities-50: 0.5;
 --amplify-opacities-60: 0.6;
 --amplify-opacities-70: 0.7;
 --amplify-opacities-80: 0.8;
 --amplify-opacities-90: 0.9;
 --amplify-opacities-100: 1;
 --amplify-outline-offsets-small: 1px;
 --amplify-outline-offsets-medium: 2px;
 --amplify-outline-offsets-large: 3px;
 --amplify-outline-widths-small: 1px;
 --amplify-outline-widths-medium: 2px;
 --amplify-outline-widths-large: 3px;
 --amplify-radii-xs: 0.125rem;
 --amplify-radii-small: 0.25rem;
 --amplify-radii-medium: 0.5rem;
 --amplify-radii-large: 1rem;
 --amplify-radii-xl: 2rem;
 --amplify-radii-xxl: 4rem;
 --amplify-radii-xxxl: 8rem;
 --amplify-shadows-small: 0px 2px 4px  var(--amplify-colors-shadow-tertiary);
 --amplify-shadows-medium: 0px 2px 6px  var(--amplify-colors-shadow-secondary);
 --amplify-shadows-large: 0px 4px 12px  var(--amplify-colors-shadow-primary);
 --amplify-space-zero: 0;
 --amplify-space-xxxs: 0.25rem;
 --amplify-space-xxs: 0.375rem;
 --amplify-space-xs: 0.5rem;
 --amplify-space-small: 0.75rem;
 --amplify-space-medium: 1rem;
 --amplify-space-large: 1.5rem;
 --amplify-space-xl: 2.0rem;
 --amplify-space-xxl: 3.0rem;
 --amplify-space-xxxl: 4.5rem;
 --amplify-space-relative-xxxs: 0.25em;
 --amplify-space-relative-xxs: 0.375em;
 --amplify-space-relative-xs: 0.5em;
 --amplify-space-relative-small: 0.75em;
 --amplify-space-relative-medium: 1em;
 --amplify-space-relative-large: 1.5em;
 --amplify-space-relative-xl: 2.0em;
 --amplify-space-relative-xxl: 3.0em;
 --amplify-space-relative-xxxl: 4.5em;
 --amplify-space-relative-full: 100%;
 --amplify-time-short: 100ms;
 --amplify-time-medium: 250ms;
 --amplify-time-long: 500ms;
 --amplify-transforms-slide-x-small: translateX(0.5em);
 --amplify-transforms-slide-x-medium: translateX(1em);
 --amplify-transforms-slide-x-large: translateX(2em);
 }

 @media (prefers-color-scheme: dark) {
           [data-amplify-theme="amplify-docs"][data-amplify-color-mode="system"] {

 --amplify-colors-font-primary: var(--amplify-colors-white);
 static var fontsecondary: Color { neutral100 }
 static var fonttertiary: Color { neutral90 }
 static var fontinverse: Color { neutral10 }
 static var backgroundprimary: Color { neutral10 }
 static var backgroundsecondary: Color { neutral20 }
 static var backgroundtertiary: Color { neutral40 }
 static var borderprimary: Color { neutral60 }
 static var bordersecondary: Color { neutral40 }
 static var bordertertiary: Color { neutral20 }
 --amplify-colors-overlay-10: hsla(0, 0%, 100%, 0.1);
 --amplify-colors-overlay-20: hsla(0, 0%, 100%, 0.2);
 --amplify-colors-overlay-30: hsla(0, 0%, 100%, 0.3);
 --amplify-colors-overlay-40: hsla(0, 0%, 100%, 0.4);
 --amplify-colors-overlay-50: hsla(0, 0%, 100%, 0.5);
 --amplify-colors-overlay-60: hsla(0, 0%, 100%, 0.6);
 --amplify-colors-overlay-70: hsla(0, 0%, 100%, 0.7);
 --amplify-colors-overlay-80: hsla(0, 0%, 100%, 0.8);
 --amplify-colors-overlay-90: hsla(0, 0%, 100%, 0.9);
 }
         }

 [data-amplify-theme="amplify-docs"][data-amplify-color-mode="dark"] {
 --amplify-colors-red-10: hsl(0, 100%, 15%);
 --amplify-colors-red-20: hsl(0, 100%, 20%);
 --amplify-colors-red-40: hsl(0, 95%, 30%);
 --amplify-colors-red-80: hsl(0, 75%, 75%);
 --amplify-colors-red-90: hsl(0, 75%, 85%);
 --amplify-colors-red-100: hsl(0, 75%, 95%);
 --amplify-colors-orange-10: hsl(30, 100%, 15%);
 --amplify-colors-orange-20: hsl(30, 100%, 20%);
 --amplify-colors-orange-40: hsl(30, 95%, 30%);
 --amplify-colors-orange-80: hsl(30, 75%, 75%);
 --amplify-colors-orange-90: hsl(30, 75%, 85%);
 --amplify-colors-orange-100: hsl(30, 75%, 95%);
 --amplify-colors-yellow-10: hsl(60, 100%, 15%);
 --amplify-colors-yellow-20: hsl(60, 100%, 20%);
 --amplify-colors-yellow-40: hsl(60, 95%, 30%);
 --amplify-colors-yellow-80: hsl(60, 75%, 75%);
 --amplify-colors-yellow-90: hsl(60, 75%, 85%);
 --amplify-colors-yellow-100: hsl(60, 75%, 95%);
 --amplify-colors-green-10: hsl(130, 22%, 23%);
 --amplify-colors-green-20: hsl(130, 27%, 29%);
 --amplify-colors-green-40: hsl(130, 33%, 37%);
 --amplify-colors-green-80: hsl(130, 44%, 63%);
 --amplify-colors-green-90: hsl(130, 60%, 90%);
 --amplify-colors-green-100: hsl(130, 60%, 95%);
 --amplify-colors-teal-10: hsl(190, 100%, 15%);
 --amplify-colors-teal-20: hsl(190, 100%, 20%);
 --amplify-colors-teal-40: hsl(190, 95%, 30%);
 --amplify-colors-teal-80: hsl(190, 70%, 70%);
 --amplify-colors-teal-90: hsl(190, 75%, 85%);
 --amplify-colors-teal-100: hsl(190, 75%, 95%);
 --amplify-colors-blue-10: hsl(220, 100%, 15%);
 --amplify-colors-blue-20: hsl(220, 100%, 20%);
 --amplify-colors-blue-40: hsl(220, 95%, 30%);
 --amplify-colors-blue-80: hsl(220, 70%, 70%);
 --amplify-colors-blue-90: hsl(220, 85%, 85%);
 --amplify-colors-blue-100: hsl(220, 95%, 95%);
 --amplify-colors-purple-10: hsl(300, 100%, 15%);
 --amplify-colors-purple-20: hsl(300, 100%, 20%);
 --amplify-colors-purple-40: hsl(300, 95%, 30%);
 --amplify-colors-purple-80: hsl(300, 70%, 70%);
 --amplify-colors-purple-90: hsl(300, 85%, 85%);
 --amplify-colors-purple-100: hsl(300, 95%, 95%);
 --amplify-colors-pink-10: hsl(340, 100%, 15%);
 --amplify-colors-pink-20: hsl(340, 100%, 20%);
 --amplify-colors-pink-40: hsl(340, 95%, 30%);
 --amplify-colors-pink-80: hsl(340, 70%, 70%);
 --amplify-colors-pink-90: hsl(340, 90%, 85%);
 --amplify-colors-pink-100: hsl(340, 95%, 95%);
 --amplify-colors-neutral-10: hsl(210, 50%, 10%);
 --amplify-colors-neutral-20: hsl(210, 25%, 25%);
 --amplify-colors-neutral-40: hsl(210, 10%, 40%);
 --amplify-colors-neutral-80: hsl(210, 5%, 87%);
 --amplify-colors-neutral-90: hsl(210, 5%, 94%);
 --amplify-colors-neutral-100: hsl(210, 5%, 98%);
 --amplify-colors-font-primary: var(--amplify-colors-white);
 --amplify-colors-font-secondary: var(--amplify-colors-neutral-100);
 --amplify-colors-font-tertiary: var(--amplify-colors-neutral-90);
 --amplify-colors-font-inverse: var(--amplify-colors-neutral-10);
 --amplify-colors-background-primary: var(--amplify-colors-neutral-10);
 --amplify-colors-background-secondary: var(--amplify-colors-neutral-20);
 --amplify-colors-background-tertiary: var(--amplify-colors-neutral-40);
 --amplify-colors-border-primary: var(--amplify-colors-neutral-60);
 --amplify-colors-border-secondary: var(--amplify-colors-neutral-40);
 --amplify-colors-border-tertiary: var(--amplify-colors-neutral-20);
 --amplify-colors-overlay-10: hsla(0, 0%, 100%, 0.1);
 --amplify-colors-overlay-20: hsla(0, 0%, 100%, 0.2);
 --amplify-colors-overlay-30: hsla(0, 0%, 100%, 0.3);
 --amplify-colors-overlay-40: hsla(0, 0%, 100%, 0.4);
 --amplify-colors-overlay-50: hsla(0, 0%, 100%, 0.5);
 --amplify-colors-overlay-60: hsla(0, 0%, 100%, 0.6);
 --amplify-colors-overlay-70: hsla(0, 0%, 100%, 0.7);
 --amplify-colors-overlay-80: hsla(0, 0%, 100%, 0.8);
 --amplify-colors-overlay-90: hsla(0, 0%, 100%, 0.9);
 }

 [data-amplify-theme-override="classic"] [data-amplify-theme="amplify-docs"] {
 --amplify-colors-brand-primary-10: var(--amplify-colors-blue-10);
 --amplify-colors-brand-primary-20: var(--amplify-colors-blue-20);
 --amplify-colors-brand-primary-40: var(--amplify-colors-blue-40);
 --amplify-colors-brand-primary-60: var(--amplify-colors-blue-60);
 --amplify-colors-brand-primary-80: var(--amplify-colors-blue-80);
 --amplify-colors-brand-primary-90: var(--amplify-colors-blue-90);
 --amplify-colors-brand-primary-100: var(--amplify-colors-blue-100);
 --amplify-colors-brand-secondary-10: var(--amplify-colors-neutral-10);
 --amplify-colors-brand-secondary-20: var(--amplify-colors-neutral-20);
 --amplify-colors-brand-secondary-40: var(--amplify-colors-neutral-40);
 --amplify-colors-brand-secondary-60: var(--amplify-colors-neutral-60);
 --amplify-colors-brand-secondary-80: var(--amplify-colors-neutral-80);
 --amplify-colors-brand-secondary-90: var(--amplify-colors-neutral-90);
 --amplify-colors-brand-secondary-100: var(--amplify-colors-neutral-100);
 --amplify-colors-border-primary: var(--amplify-colors-neutral-40);
 --amplify-colors-border-secondary: var(--amplify-colors-neutral-20);
 --amplify-colors-border-tertiary: var(--amplify-colors-neutral-10);
 --amplify-radii-small: 2px;
 --amplify-radii-medium: 2px;
 --amplify-radii-large: 4px;
 --amplify-radii-xl: 6px;
 }

 [data-amplify-theme-override="terminal"] [data-amplify-theme="amplify-docs"] {
 --amplify-colors-green-10: #C7EFCA;
 --amplify-colors-green-20: #9AE2A1;
 --amplify-colors-green-40: #4CCB68;
 --amplify-colors-green-60: #44AF5B;
 --amplify-colors-green-80: #31703D;
 --amplify-colors-green-90: #224226;
 --amplify-colors-brand-primary-10: var(--amplify-colors-green-10);
 --amplify-colors-brand-primary-20: var(--amplify-colors-green-20);
 --amplify-colors-brand-primary-40: var(--amplify-colors-green-40);
 --amplify-colors-brand-primary-60: var(--amplify-colors-green-60);
 --amplify-colors-brand-primary-80: var(--amplify-colors-green-80);
 --amplify-colors-brand-primary-90: var(--amplify-colors-green-90);
 --amplify-colors-brand-primary-100: var(--amplify-colors-green-100);
 --amplify-colors-brand-secondary-10: var(--amplify-colors-green-10);
 --amplify-colors-brand-secondary-20: var(--amplify-colors-green-20);
 --amplify-colors-brand-secondary-40: var(--amplify-colors-green-40);
 --amplify-colors-brand-secondary-60: var(--amplify-colors-green-60);
 --amplify-colors-brand-secondary-80: var(--amplify-colors-green-80);
 --amplify-colors-brand-secondary-90: var(--amplify-colors-green-90);
 --amplify-colors-brand-secondary-100: var(--amplify-colors-green-100);
 --amplify-colors-border-primary: black;
 --amplify-shadows-small: 0px 2px 4px  var(--amplify-colors-shadow-tertiary);
 --amplify-shadows-medium: 10px 10px 0 0px var(--amplify-colors-shadow-secondary);
 --amplify-shadows-large: 8px 30px 0 10px var(--amplify-colors-shadow-primary);
 --amplify-components-card-box-shadow: var(--amplify-shadows-medium);
 --amplify-components-heading-1-font-weight: var(--amplify-font-weights-extrabold);
 --amplify-components-heading-2-font-weight: var(--amplify-font-weights-extrabold);
 --amplify-components-heading-3-font-weight: var(--amplify-font-weights-extrabold);
 --amplify-components-heading-4-font-weight: var(--amplify-font-weights-extrabold);
 --amplify-components-heading-5-font-weight: var(--amplify-font-weights-extrabold);
 --amplify-components-heading-6-font-weight: var(--amplify-font-weights-extrabold);
 --amplify-components-button-primary-background-color: var(--amplify-colors-brand-primary-40);
 --amplify-components-button-primary-color: var(--amplify-colors-font-primary);
 --amplify-components-button-primary-border-color: var(--amplify-colors-border-primary);
 --amplify-radii-small: 0;
 --amplify-radii-medium: 0;
 --amplify-radii-large: 0;
 --amplify-space-small: 1rem;
 --amplify-space-medium: 1.5rem;
 --amplify-space-large: 2rem;
 --amplify-border-widths-small: 2px;
 --amplify-border-widths-medium: 4px;
 --amplify-border-widths-large: 8px;
 }

 */
