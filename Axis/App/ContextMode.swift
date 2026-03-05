import Foundation
import SwiftUI

enum ContextMode: String, CaseIterable, Codable, Identifiable {
    case work = "Work"
    case dad = "Dad"
    case me = "Me"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .dad: return "figure.and.child.holdinghands"
        case .me: return "person.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .work: return Color.axisGold
        case .dad: return .blue
        case .me: return .green
        }
    }

    var greeting: String {
        switch self {
        case .work: return "Let's get it done."
        case .dad: return "Family first."
        case .me: return "Time for you."
        }
    }
}
