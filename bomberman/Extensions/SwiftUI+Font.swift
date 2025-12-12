import SwiftUI

extension Font {
    
    static func pixelifySans(
        size: CGFloat,
        fontWeight: Weight = .regular
    ) -> Font {
        return Font.custom(CustomFont(weight: fontWeight).rawValue, size: size)
    }
    
}

fileprivate enum CustomFont: String {
    case regular = "PixelifySans-Regular"
    case medium = "PixelifySans-Medium"
    case semiBold = "PixelifySans-SemiBold"
    case bold = "PixelifySans-Bold"
    
    init(weight: Font.Weight) {
        switch weight {
        case .regular:
            self = .regular
        case .medium:
            self = .medium
        case .semibold:
            self = .semiBold
        case .bold:
            self = .bold
        default:
            self = .regular
        }
    }
}
