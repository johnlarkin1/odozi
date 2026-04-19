//
//  UIColor+Extensions.swift
//  Odyssey
//
//  Created by John Larkin on 1/6/24.
//

import Foundation

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

extension PlatformColor {
    // Convert PlatformColor to Hex String
    func toHexString() -> String {
        #if os(macOS)
            guard let rgbColor = usingColorSpace(.sRGB) else { return "#000000" }
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            rgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif

        let rgb = Int(r * 255) << 16 | Int(g * 255) << 8 | Int(b * 255) << 0
        if a < 1.0 {
            let alphaByte = Int(a * 255)
            return String(format: "#%06x%02x", rgb, alphaByte)
        }
        return String(format: "#%06x", rgb)
    }

    // Convert Hex String to PlatformColor
    static func fromHexString(_ hex: String) -> PlatformColor {
        var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if cString.hasPrefix("#") {
            cString.remove(at: cString.startIndex)
        }

        guard cString.count == 6 || cString.count == 8 else {
            return PlatformColor.gray
        }

        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)

        let alpha: CGFloat
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        if cString.count == 8 {
            red = CGFloat((rgbValue & 0xFF00_0000) >> 24) / 255.0
            green = CGFloat((rgbValue & 0x00FF_0000) >> 16) / 255.0
            blue = CGFloat((rgbValue & 0x0000_FF00) >> 8) / 255.0
            alpha = CGFloat(rgbValue & 0x0000_00FF) / 255.0
        } else {
            red = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
            green = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
            blue = CGFloat(rgbValue & 0x0000FF) / 255.0
            alpha = 1.0
        }

        return PlatformColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
