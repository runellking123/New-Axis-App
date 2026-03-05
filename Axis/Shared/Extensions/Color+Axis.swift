import SwiftUI

extension Color {
    static let axisGold = Color("AxisGold")
    static let axisDark = Color("AxisDark")

    static let axisGoldLight = Color(red: 0.878, green: 0.750, blue: 0.400)
    static let axisGoldDark = Color(red: 0.808, green: 0.694, blue: 0.337)
}

extension ShapeStyle where Self == Color {
    static var axisGold: Color { Color.axisGold }
    static var axisDark: Color { Color.axisDark }
}
