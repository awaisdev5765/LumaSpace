import SwiftUI

// MARK: - Color from furniture color-name string

extension Color {
    static func fromColorName(_ name: String) -> Color {
        switch name.lowercased() {
        case "white", "cream", "ivory", "off-white": return Color(hex: "F5F5F0")
        case "black", "ebony", "charcoal", "graphite": return Color(hex: "2C2C2C")
        case "grey", "gray", "light grey", "light gray": return Color(hex: "9E9E9E")
        case "dark grey", "dark gray": return Color(hex: "5C5C5C")
        case "beige", "sand", "linen", "oatmeal": return Color(hex: "C8B89A")
        case "brown", "walnut", "chocolate": return Color(hex: "6B4226")
        case "oak", "natural", "light oak", "honey": return Color(hex: "C8A870")
        case "navy", "navy blue", "midnight blue": return Color.Luma.navy
        case "blue", "cobalt", "ocean": return Color(hex: "1565C0")
        case "light blue", "sky blue", "powder blue": return Color(hex: "90CAF9")
        case "green", "forest green", "hunter green": return Color(hex: "2E7D32")
        case "sage", "olive", "moss": return Color(hex: "7A8C6E")
        case "teal", "petrol": return Color(hex: "1A7A6E")
        case "red", "cherry": return Color(hex: "C62828")
        case "rust", "terracotta", "burnt orange": return Color(hex: "BF360C")
        case "orange": return Color(hex: "E65100")
        case "yellow", "mustard", "gold": return Color.Luma.gold
        case "pink", "blush", "rose": return Color(hex: "E91E8C")
        case "purple", "plum", "violet", "lavender": return Color(hex: "6A1B9A")
        case "brass", "bronze": return Color(hex: "8C6914")
        default: return Color(uiColor: .systemGray4)
        }
    }
}

// MARK: - Safe Array Subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

// MARK: - Color Hex String

extension Color {
    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - Conditional Modifier

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }

    @ViewBuilder
    func ifLet<T, Content: View>(_ optional: T?, transform: (Self, T) -> Content) -> some View {
        if let value = optional { transform(self, value) } else { self }
    }
}

// MARK: - Uneven Rounded Rectangle (backport for < iOS 16)

struct UnevenRoundedRectangle: Shape {
    var topLeadingRadius: CGFloat
    var bottomLeadingRadius: CGFloat
    var bottomTrailingRadius: CGFloat
    var topTrailingRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tl = min(topLeadingRadius, min(rect.width / 2, rect.height / 2))
        let tr = min(topTrailingRadius, min(rect.width / 2, rect.height / 2))
        let bl = min(bottomLeadingRadius, min(rect.width / 2, rect.height / 2))
        let br = min(bottomTrailingRadius, min(rect.width / 2, rect.height / 2))

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + tr), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - br, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bl), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addQuadCurve(to: CGPoint(x: rect.minX + tl, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Keyboard Dismiss

extension View {
    func dismissKeyboardOnTap() -> some View {
        onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
    }
}

// MARK: - Safe Area Bottom

extension View {
    var safeAreaBottom: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows.first?.safeAreaInsets.bottom ?? 0
    }
}

// MARK: - Placeholder

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
