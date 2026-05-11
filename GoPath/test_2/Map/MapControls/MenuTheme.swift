import SwiftUI

enum MenuTheme
{
    static let backgroundFallback = Color(red: 0.04, green: 0.07, blue: 0.09)
    static let cardFill = Color(red: 0.12, green: 0.15, blue: 0.18).opacity(0.78)
    static let elevatedCardFill = Color(red: 0.14, green: 0.17, blue: 0.21).opacity(0.86)
    static let selectedCardFill = Color(red: 0.10, green: 0.23, blue: 0.20).opacity(0.72)
    static let cardStroke = Color.white.opacity(0.09)
    static let controlStroke = Color.white.opacity(0.14)
    static let selectedStroke = Color(red: 0.55, green: 0.92, blue: 0.66).opacity(0.88)
    static let mutedText = Color.white.opacity(0.58)
    static let faintText = Color.white.opacity(0.36)
    static let green = Color(red: 0.53, green: 0.90, blue: 0.63)
    static let blue = Color(red: 0.35, green: 0.72, blue: 0.95)
    static let redDot = Color(red: 1.0, green: 0.38, blue: 0.43)

    static var primaryGradient: LinearGradient
    {
        LinearGradient(
            colors: [
                Color(red: 0.53, green: 0.88, blue: 0.62),
                Color(red: 0.34, green: 0.72, blue: 0.95)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var softGlowGradient: LinearGradient
    {
        LinearGradient(
            colors: [
                Color(red: 0.55, green: 0.94, blue: 0.65).opacity(0.75),
                Color(red: 0.38, green: 0.77, blue: 0.97).opacity(0.72)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct MenuBackgroundView: View
{
    var imageName: String = "MenuBackground"

    var body: some View
    {
        GeometryReader { proxy in
            ZStack {
                MenuTheme.backgroundFallback

                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }
}

struct GlassPressButtonStyle: ButtonStyle
{
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var cornerRadius: CGFloat = 13
    var scale: CGFloat = 0.955
    var shadowColor: Color = .clear
    var shadowRadius: CGFloat = 0
    var shadowY: CGFloat = 0

    func makeBody(configuration: Configuration) -> some View
    {
        let isPressed = configuration.isPressed
        let animation: Animation? = reduceMotion
            ? .easeOut(duration: 0.10)
            : .spring(response: 0.19, dampingFraction: 0.76)

        return configuration.label
            .compositingGroup()
            .scaleEffect(reduceMotion ? 1.0 : (isPressed ? scale : 1.0))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isPressed ? 0.26 : 0.0),
                                Color(red: 0.80, green: 0.90, blue: 1.0).opacity(isPressed ? 0.14 : 0.0),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(isPressed ? 0.18 : 0.0))
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(isPressed ? 0.34 : 0.0), lineWidth: 1.15)
                    .allowsHitTesting(false)
            }
            .brightness(isPressed ? -0.030 : 0)
            .saturation(isPressed ? 1.08 : 1.0)
            .offset(y: reduceMotion ? 0 : (isPressed ? 1.1 : 0))
            .shadow(
                color: shadowColor.opacity(
                    isPressed && reduceMotion == false ? 0.40 : 1.0
                ),
                radius: isPressed && reduceMotion == false ? shadowRadius * 0.34 : shadowRadius,
                x: 0,
                y: isPressed && reduceMotion == false ? shadowY * 0.28 : shadowY
            )
            .animation(animation, value: isPressed)
    }
}

struct GradientGlassPressButtonStyle: ButtonStyle
{
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var cornerRadius: CGFloat
    var scale: CGFloat
    var shadowColor: Color = .clear
    var shadowRadius: CGFloat = 0
    var shadowY: CGFloat = 0

    func makeBody(configuration: Configuration) -> some View
    {
        let isPressed = configuration.isPressed
        let animation: Animation? = reduceMotion
            ? .easeOut(duration: 0.10)
            : .spring(response: 0.20, dampingFraction: 0.78)

        return configuration.label
            .compositingGroup()
            .scaleEffect(reduceMotion ? 1.0 : (isPressed ? scale : 1.0))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isPressed ? 0.24 : 0.0),
                                Color(red: 0.86, green: 0.95, blue: 1.0).opacity(isPressed ? 0.12 : 0.0),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(isPressed ? 0.16 : 0.0))
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(isPressed ? 0.30 : 0.0), lineWidth: 1.15)
                    .allowsHitTesting(false)
            }
            .brightness(isPressed ? -0.036 : 0)
            .saturation(isPressed ? 1.05 : 1.0)
            .offset(y: reduceMotion ? 0 : (isPressed ? 1.0 : 0))
            .shadow(
                color: shadowColor.opacity(
                    isPressed && reduceMotion == false ? 0.42 : 1.0
                ),
                radius: isPressed && reduceMotion == false ? shadowRadius * 0.32 : shadowRadius,
                x: 0,
                y: isPressed && reduceMotion == false ? shadowY * 0.24 : shadowY
            )
            .animation(animation, value: isPressed)
    }
}

struct GlassTextPressButtonStyle: ButtonStyle
{
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var scale: CGFloat = 0.955

    func makeBody(configuration: Configuration) -> some View
    {
        let isPressed = configuration.isPressed
        let animation: Animation? = reduceMotion
            ? .easeOut(duration: 0.10)
            : .spring(response: 0.19, dampingFraction: 0.80)

        return configuration.label
            .compositingGroup()
            .scaleEffect(reduceMotion ? 1.0 : (isPressed ? scale : 1.0))
            .overlay {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(isPressed ? 0.08 : 0.0))
                    .padding(.horizontal, -10)
                    .padding(.vertical, -6)
                    .allowsHitTesting(false)
            }
            .overlay {
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(isPressed ? 0.08 : 0.0))
                    .padding(.horizontal, -10)
                    .padding(.vertical, -6)
                    .allowsHitTesting(false)
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(isPressed ? 0.16 : 0.0), lineWidth: 1)
                    .padding(.horizontal, -10)
                    .padding(.vertical, -6)
                    .allowsHitTesting(false)
            }
            .brightness(isPressed ? 0.02 : 0)
            .offset(y: reduceMotion ? 0 : (isPressed ? 0.8 : 0))
            .animation(animation, value: isPressed)
    }
}

struct GlassTextPressEffect: ViewModifier
{
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isPressed: Bool
    var scale: CGFloat = 0.955

    func body(content: Content) -> some View
    {
        let animation: Animation? = reduceMotion
            ? .easeOut(duration: 0.10)
            : .spring(response: 0.20, dampingFraction: 0.80)

        content
            .compositingGroup()
            .scaleEffect(reduceMotion ? 1.0 : (isPressed ? scale : 1.0))
            .overlay {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(isPressed ? 0.12 : 0.03))
                    .padding(.horizontal, -10)
                    .padding(.vertical, -6)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
            .overlay {
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(isPressed ? 0.12 : 0.04))
                    .padding(.horizontal, -10)
                    .padding(.vertical, -6)
                    .allowsHitTesting(false)
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(isPressed ? 0.18 : 0.06), lineWidth: 1)
                    .padding(.horizontal, -10)
                    .padding(.vertical, -6)
                    .allowsHitTesting(false)
            }
            .brightness(isPressed ? 0.03 : 0)
            .offset(y: reduceMotion ? 0 : (isPressed ? 0.9 : 0))
            .animation(animation, value: isPressed)
    }
}

struct GlassIconPressButtonStyle: ButtonStyle
{
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var cornerRadius: CGFloat
    var scale: CGFloat
    var shadowColor: Color = .clear
    var shadowRadius: CGFloat = 0
    var shadowY: CGFloat = 0
    var overlayWidth: CGFloat
    var overlayHeight: CGFloat

    func makeBody(configuration: Configuration) -> some View
    {
        let isPressed = configuration.isPressed
        let animation: Animation? = reduceMotion
            ? .easeOut(duration: 0.10)
            : .spring(response: 0.19, dampingFraction: 0.80)

        return configuration.label
            .compositingGroup()
            .scaleEffect(reduceMotion ? 1.0 : (isPressed ? scale : 1.0))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isPressed ? 0.22 : 0.0),
                                Color(red: 0.80, green: 0.90, blue: 1.0).opacity(isPressed ? 0.10 : 0.0),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: overlayWidth, height: overlayHeight)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(isPressed ? 0.14 : 0.0))
                    .frame(width: overlayWidth, height: overlayHeight)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(isPressed ? 0.26 : 0.0), lineWidth: 1.1)
                    .frame(width: overlayWidth, height: overlayHeight)
                    .allowsHitTesting(false)
            }
            .brightness(isPressed ? -0.018 : 0)
            .offset(y: reduceMotion ? 0 : (isPressed ? 1.0 : 0))
            .shadow(
                color: shadowColor.opacity(
                    isPressed && reduceMotion == false ? 0.42 : 1.0
                ),
                radius: isPressed && reduceMotion == false ? shadowRadius * 0.34 : shadowRadius,
                x: 0,
                y: isPressed && reduceMotion == false ? shadowY * 0.28 : shadowY
            )
            .animation(animation, value: isPressed)
    }
}

struct GlassIconPressEffect: ViewModifier
{
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isPressed: Bool
    let cornerRadius: CGFloat
    var scale: CGFloat
    var shadowColor: Color = .clear
    var shadowRadius: CGFloat = 0
    var shadowY: CGFloat = 0
    var overlayWidth: CGFloat
    var overlayHeight: CGFloat

    func body(content: Content) -> some View
    {
        let animation: Animation? = reduceMotion
            ? .easeOut(duration: 0.10)
            : .spring(response: 0.22, dampingFraction: 0.78)

        content
            .compositingGroup()
            .scaleEffect(reduceMotion ? 1.0 : (isPressed ? scale : 1.0))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isPressed ? 0.28 : 0.0),
                                Color(red: 0.80, green: 0.90, blue: 1.0).opacity(isPressed ? 0.14 : 0.0),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: overlayWidth, height: overlayHeight)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(isPressed ? 0.18 : 0.0))
                    .frame(width: overlayWidth, height: overlayHeight)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(isPressed ? 0.32 : 0.0), lineWidth: 1.1)
                    .frame(width: overlayWidth, height: overlayHeight)
                    .allowsHitTesting(false)
            }
            .brightness(isPressed ? -0.024 : 0)
            .offset(y: reduceMotion ? 0 : (isPressed ? 1.0 : 0))
            .shadow(
                color: shadowColor.opacity(
                    isPressed && reduceMotion == false ? 0.38 : 1.0
                ),
                radius: isPressed && reduceMotion == false ? shadowRadius * 0.30 : shadowRadius,
                x: 0,
                y: isPressed && reduceMotion == false ? shadowY * 0.24 : shadowY
            )
            .animation(animation, value: isPressed)
    }
}

struct GradientGlassPressEffect: ViewModifier
{
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isPressed: Bool
    let cornerRadius: CGFloat
    var scale: CGFloat = 0.968
    var shadowColor: Color = .clear
    var shadowRadius: CGFloat = 0
    var shadowY: CGFloat = 0

    func body(content: Content) -> some View
    {
        let animation: Animation? = reduceMotion
            ? .easeOut(duration: 0.10)
            : .spring(response: 0.20, dampingFraction: 0.78)

        content
            .compositingGroup()
            .scaleEffect(reduceMotion ? 1.0 : (isPressed ? scale : 1.0))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isPressed ? 0.28 : 0.0),
                                Color(red: 0.86, green: 0.95, blue: 1.0).opacity(isPressed ? 0.14 : 0.0),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(isPressed ? 0.18 : 0.0))
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(isPressed ? 0.32 : 0.0), lineWidth: 1.15)
                    .allowsHitTesting(false)
            }
            .brightness(isPressed ? -0.040 : 0)
            .saturation(isPressed ? 1.06 : 1.0)
            .offset(y: reduceMotion ? 0 : (isPressed ? 1.0 : 0))
            .shadow(
                color: shadowColor.opacity(
                    isPressed && reduceMotion == false ? 0.42 : 1.0
                ),
                radius: isPressed && reduceMotion == false ? shadowRadius * 0.28 : shadowRadius,
                x: 0,
                y: isPressed && reduceMotion == false ? shadowY * 0.22 : shadowY
            )
            .animation(animation, value: isPressed)
    }
}

struct HistoryChevronPressButtonStyle: ButtonStyle
{
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View
    {
        let isPressed = configuration.isPressed
        let animation: Animation? = reduceMotion
            ? .easeOut(duration: 0.10)
            : .spring(response: 0.22, dampingFraction: 0.80)

        return configuration.label
            .compositingGroup()
            .scaleEffect(reduceMotion ? 1.0 : (isPressed ? 0.92 : 1.0))
            .opacity(isPressed ? 0.84 : 1.0)
            .brightness(isPressed ? 0.06 : 0)
            .offset(y: reduceMotion ? 0 : (isPressed ? 0.8 : 0))
            .animation(animation, value: isPressed)
    }
}

struct HistoryCellPressModifier: ViewModifier
{
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isPressed: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View
    {
        let animation: Animation? = reduceMotion
            ? .easeOut(duration: 0.10)
            : .spring(response: 0.15, dampingFraction: 0.95, blendDuration: 0.01)

        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isPressed ? 0.14 : 0.0),
                                Color(red: 0.80, green: 0.90, blue: 1.0).opacity(isPressed ? 0.06 : 0.0),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(isPressed ? 0.08 : 0.0))
                    .allowsHitTesting(false)
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(isPressed ? 0.20 : 0.0), lineWidth: 1.1)
            )
            .brightness(isPressed ? 0.012 : 0)
            .saturation(isPressed ? 1.02 : 1.0)
            .scaleEffect(reduceMotion ? 1.0 : (isPressed ? 0.982 : 1.0))
            .offset(y: reduceMotion ? 0 : (isPressed ? 0.07 : 0))
            .animation(animation, value: isPressed)
    }
}

struct GlassControlBackground: View
{
    let cornerRadius: CGFloat

    var body: some View
    {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.10))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.35)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(MenuTheme.controlStroke, lineWidth: 1)
            )
    }
}

struct GlassCardBackground: View
{
    let isSelected: Bool
    var cornerRadius: CGFloat = 18

    var body: some View
    {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(isSelected ? MenuTheme.selectedCardFill : MenuTheme.elevatedCardFill)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.20)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isSelected ? MenuTheme.softGlowGradient : LinearGradient(
                            colors: [MenuTheme.cardStroke, MenuTheme.cardStroke],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: isSelected ? 1.25 : 1
                    )
            )
            .shadow(
                color: isSelected ? MenuTheme.green.opacity(0.22) : Color.black.opacity(0.18),
                radius: isSelected ? 18 : 10,
                x: 0,
                y: isSelected ? 0 : 8
            )
    }
}

private struct FullScreenPreviewWrapper: View
{
    var body: some View
    {
        NavigatorOnMap()
    }
}

#Preview("Full iPhone Screen") {
    FullScreenPreviewWrapper()
}
