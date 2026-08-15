import AILimitsCore
import SwiftUI

enum Brand {
    static let paper = Color(red: 0.961, green: 0.953, blue: 0.929)
    static let ink = Color(red: 0.067, green: 0.067, blue: 0.059)

    static func accent(for provider: ProviderID) -> Color {
        switch provider {
        case .codex: Color(red: 0.071, green: 0.486, blue: 0.471)
        case .claude: Color(red: 0.784, green: 0.400, blue: 0.239)
        case .cursor: Color(red: 0.431, green: 0.357, blue: 0.784)
        case .copilot: Color(red: 0.204, green: 0.471, blue: 0.788)
        case .openRouter: Color(red: 0.510, green: 0.341, blue: 0.851)
        default: .secondary
        }
    }
}

