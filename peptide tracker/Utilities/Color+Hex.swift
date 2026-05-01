import SwiftUI

extension Color {
    init?(hex: String) {
        let hexString = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let scanner = Scanner(string: hexString.hasPrefix("#") ? String(hexString.dropFirst()) : hexString)

        var color: UInt64 = 0
        guard scanner.scanHexInt64(&color) else {
            return nil
        }

        let length = hexString.hasPrefix("#") ? hexString.count - 1 : hexString.count
        if hexString.hasPrefix("#") {
            if length == 3 {
                let r = Int((color >> 8) & 0xF)
                let g = Int((color >> 4) & 0xF)
                let b = Int(color & 0xF)
                self.init(
                    red: Double(r * 17) / 255.0,
                    green: Double(g * 17) / 255.0,
                    blue: Double(b * 17) / 255.0,
                    opacity: 1.0
                )
            } else if length == 6 {
                let r = Int((color >> 16) & 0xFF)
                let g = Int((color >> 8) & 0xFF)
                let b = Int(color & 0xFF)
                self.init(
                    red: Double(r) / 255.0,
                    green: Double(g) / 255.0,
                    blue: Double(b) / 255.0,
                    opacity: 1.0
                )
            } else if length == 8 {
                let r = Int((color >> 24) & 0xFF)
                let g = Int((color >> 16) & 0xFF)
                let b = Int((color >> 8) & 0xFF)
                let a = Int(color & 0xFF)
                self.init(
                    red: Double(r) / 255.0,
                    green: Double(g) / 255.0,
                    blue: Double(b) / 255.0,
                    opacity: Double(a) / 255.0
                )
            } else {
                return nil
            }
        } else {
            if length == 3 {
                let r = Int((color >> 8) & 0xF)
                let g = Int((color >> 4) & 0xF)
                let b = Int(color & 0xF)
                self.init(
                    red: Double(r * 17) / 255.0,
                    green: Double(g * 17) / 255.0,
                    blue: Double(b * 17) / 255.0,
                    opacity: 1.0
                )
            } else if length == 6 {
                let r = Int((color >> 16) & 0xFF)
                let g = Int((color >> 8) & 0xFF)
                let b = Int(color & 0xFF)
                self.init(
                    red: Double(r) / 255.0,
                    green: Double(g) / 255.0,
                    blue: Double(b) / 255.0,
                    opacity: 1.0
                )
            } else if length == 8 {
                let r = Int((color >> 24) & 0xFF)
                let g = Int((color >> 16) & 0xFF)
                let b = Int((color >> 8) & 0xFF)
                let a = Int(color & 0xFF)
                self.init(
                    red: Double(r) / 255.0,
                    green: Double(g) / 255.0,
                    blue: Double(b) / 255.0,
                    opacity: Double(a) / 255.0
                )
            } else {
                return nil
            }
        }
    }
}
