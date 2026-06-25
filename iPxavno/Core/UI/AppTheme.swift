import UIKit

enum AppTheme {
    enum Color {
        static let background = UIColor(hex: 0xF7F8FA)
        static let surface = UIColor.white
        static let ink = UIColor(hex: 0x161A1D)
        static let secondaryInk = UIColor(hex: 0x667085)
        static let line = UIColor(hex: 0xE4E7EC)
        static let accent = UIColor(hex: 0x0E9384)
        static let accentDark = UIColor(hex: 0x0B6F63)
        static let warm = UIColor(hex: 0xF79009)
        static let violet = UIColor(hex: 0x7A5AF8)
    }

    enum Font {
        static let largeTitle = UIFont.systemFont(ofSize: 32, weight: .bold)
        static let title = UIFont.systemFont(ofSize: 24, weight: .bold)
        static let headline = UIFont.systemFont(ofSize: 17, weight: .semibold)
        static let body = UIFont.systemFont(ofSize: 15, weight: .regular)
        static let caption = UIFont.systemFont(ofSize: 12, weight: .medium)
    }

    enum Metric {
        static let screenInset: CGFloat = 20
        static let cornerRadius: CGFloat = 8
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let red = CGFloat((hex & 0xFF0000) >> 16) / 255
        let green = CGFloat((hex & 0x00FF00) >> 8) / 255
        let blue = CGFloat(hex & 0x0000FF) / 255
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
