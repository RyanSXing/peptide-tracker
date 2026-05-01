import SwiftUI

struct ColorGenerator {
    static func color(for name: String) -> Color {
        let hash = name.hashValue
        let hue = Double(abs(hash) % 360)
        return Color(
            hue: hue / 360.0,
            saturation: 0.7,
            brightness: 0.5
        )
    }
}
