import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum AppTheme {
    static let brand = Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255) // #4F46E5 indigo-600
    static let brandViolet = Color(red: 124 / 255, green: 58 / 255, blue: 237 / 255) // #7C3AED violet-600
    static let brandGradient = LinearGradient(colors: [brand, brandViolet], startPoint: .leading, endPoint: .trailing)
    static let danger = Color(red: 225 / 255, green: 29 / 255, blue: 72 / 255) // #E11D48 rose-600
    static let emerald = Color(red: 5 / 255, green: 150 / 255, blue: 105 / 255) // #059669 emerald-600
    static let amber = Color(red: 217 / 255, green: 119 / 255, blue: 6 / 255) // #D97706 amber-600

    static func pageBackground(_ isDark: Bool) -> Color {
        isDark ? Color(red: 11 / 255, green: 15 / 255, blue: 25 / 255) : Color(red: 242 / 255, green: 242 / 255, blue: 247 / 255)
    }

    static func cardBackground(_ isDark: Bool) -> Color {
        isDark ? Color(red: 19 / 255, green: 26 / 255, blue: 42 / 255) : Color.white
    }

    static func subtleBackground(_ isDark: Bool) -> Color {
        isDark ? Color(red: 27 / 255, green: 36 / 255, blue: 56 / 255) : Color(red: 248 / 255, green: 250 / 255, blue: 252 / 255)
    }

    static func borderColor(_ isDark: Bool) -> Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.07)
    }

    static func dividerColor(_ isDark: Bool) -> Color {
        isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.06)
    }
}

struct InsetDivider: View {
    let isDark: Bool
    var inset: CGFloat = 16

    var body: some View {
        Rectangle()
            .fill(AppTheme.dividerColor(isDark))
            .frame(height: 0.5)
            .padding(.leading, inset)
    }
}

struct SheetTopHeader<Trailing: View>: View {
    let leftTitle: String
    let onLeft: () -> Void
    let title: String
    let isDark: Bool
    let trailing: () -> Trailing

    init(
        leftTitle: String = t("取消"),
        onLeft: @escaping () -> Void,
        title: String,
        isDark: Bool,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.leftTitle = leftTitle
        self.onLeft = onLeft
        self.title = title
        self.isDark = isDark
        self.trailing = trailing
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                HStack {
                    Button(action: onLeft) {
                        if leftTitle.hasPrefix("‹ ") {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary.opacity(0.8))
                                .frame(width: 32, height: 32)
                                .background(AppTheme.subtleBackground(isDark))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(AppTheme.borderColor(isDark), lineWidth: 0.8))
                                .accessibilityLabel(String(leftTitle.dropFirst(2)))
                        } else {
                            Text(leftTitle)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary.opacity(0.6))
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    trailing()
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 16)

            Rectangle()
                .fill(AppTheme.dividerColor(isDark))
                .frame(height: 0.5)
        }
    }
}

extension SheetTopHeader where Trailing == EmptyView {
    init(
        leftTitle: String = t("取消"),
        onLeft: @escaping () -> Void,
        title: String,
        isDark: Bool
    ) {
        self.init(leftTitle: leftTitle, onLeft: onLeft, title: title, isDark: isDark) {
            EmptyView()
        }
    }
}

struct FormTextFieldBox: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let isDark: Bool
    var isSecure: Bool = false
    var isMonospace: Bool = false
    var showEyeToggle: Bool = false
    var borderHighlight: Color? = nil
    var trailingLabelText: String? = nil
    var trailingLabelColor: Color = AppTheme.brand
    var trailingAction: (() -> Void)? = nil
    var keyboardType: UIKeyboardType = .default

    @State private var revealed: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.primary.opacity(0.6))
                Spacer()
                if let trailingText = trailingLabelText, !trailingText.isEmpty {
                    if let action = trailingAction {
                        Button(action: action) {
                            Text(trailingText)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(trailingLabelColor)
                        }
                    } else {
                        Text(trailingText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(trailingLabelColor)
                    }
                }
            }
            .padding(.horizontal, 4)

            HStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 12))
                            .foregroundColor(.primary.opacity(0.4))
                            .allowsHitTesting(false)
                    }
                    if isSecure && !revealed {
                        SecureField("", text: $text)
                            .font(isMonospace ? .system(size: 12, design: .monospaced) : .system(size: 12))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    } else {
                        TextField("", text: $text)
                            .font(isMonospace ? .system(size: 12, design: .monospaced) : .system(size: 12))
                            .keyboardType(keyboardType)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    }
                }
                if showEyeToggle {
                    Button {
                        revealed.toggle()
                    } label: {
                        Image(systemName: revealed ? "eye.slash" : "eye")
                            .font(.system(size: 14))
                            .foregroundColor(.primary.opacity(0.5))
                            .frame(width: 28, height: 28)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(AppTheme.cardBackground(isDark))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderHighlight ?? AppTheme.borderColor(isDark), lineWidth: borderHighlight != nil ? 1 : 0.8)
            )
        }
    }
}

struct FormTextAreaBox: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let isDark: Bool
    var minHeight: CGFloat = 68

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.primary.opacity(0.6))
                .padding(.horizontal, 4)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 12))
                        .foregroundColor(.primary.opacity(0.4))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.system(size: 12))
                    .svClearScrollBackground()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(minHeight: minHeight)
            }
            .background(AppTheme.cardBackground(isDark))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.borderColor(isDark), lineWidth: 0.8)
            )
        }
    }
}

struct SearchBarField: View {
    let placeholder: String
    @Binding var text: String
    let isDark: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary.opacity(0.45))
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 12))
                        .foregroundColor(.primary.opacity(0.45))
                        .allowsHitTesting(false)
                }
                TextField("", text: $text)
                    .font(.system(size: 12))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.primary.opacity(0.35))
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(AppTheme.cardBackground(isDark))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.borderColor(isDark), lineWidth: 0.8)
        )
    }
}

struct ItemAvatarView: View {
    let item: VaultItem

    var body: some View {
        switch item.type {
        case .login:
            let letter = String((item.title.trimmingCharacters(in: .whitespaces).first ?? "S")).uppercased()
            let palette: [Color] = [
                Color(red: 30 / 255, green: 41 / 255, blue: 59 / 255),
                AppTheme.brand,
                Color(red: 2 / 255, green: 132 / 255, blue: 199 / 255),
                AppTheme.emerald
            ]
            let code = Int(letter.unicodeScalars.first?.value ?? 83)
            RoundedRectangle(cornerRadius: 12)
                .fill(palette[code % palette.count])
                .frame(width: 40, height: 40)
                .overlay(
                    Text(letter)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                )
        case .card:
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.emerald.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "creditcard")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(AppTheme.emerald)
                )
        case .note:
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "doc.text")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color(red: 2 / 255, green: 132 / 255, blue: 199 / 255))
                )
        case .identity:
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.amber.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.text.rectangle")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(AppTheme.amber)
                )
        }
    }
}

struct ColorizedPasswordText: View {
    let password: String
    var fontSize: CGFloat = 16

    var body: some View {
        password.reduce(Text("")) { partial, ch in
            let color: Color
            if ch.isNumber {
                color = Color(red: 56 / 255, green: 189 / 255, blue: 248 / 255) // sky-400
            } else if !ch.isLetter {
                color = Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255) // amber-400
            } else {
                color = .white
            }
            return partial + Text(String(ch)).foregroundColor(color)
        }
        .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ExportFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .data] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - iOS 15+ Compatibility Helpers (zero compromise on iOS 16+)

enum SvSheetStyle {
    case large
    case mediumAndLarge
    case compact(CGFloat)
}

struct SvCompatNavigationContainer<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content()
            }
        } else {
            NavigationView {
                content()
            }
            .navigationViewStyle(.stack)
        }
    }
}

private struct LegacySheetDetentsConfigurator: UIViewControllerRepresentable {
    let style: SvSheetStyle

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            guard let sheet = uiViewController.parent?.sheetPresentationController
                    ?? uiViewController.presentingViewController?.presentedViewController?.sheetPresentationController else {
                return
            }
            switch style {
            case .large:
                sheet.detents = [.large()]
            case .mediumAndLarge:
                sheet.detents = [.medium(), .large()]
            case .compact:
                sheet.detents = [.medium()]
            }
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28
        }
    }
}

extension View {
    @ViewBuilder
    func svSheetPresentation(_ style: SvSheetStyle) -> some View {
        if #available(iOS 16.0, *) {
            switch style {
            case .large:
                self
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            case .mediumAndLarge:
                self
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            case .compact(let height):
                self
                    .presentationDetents([.height(height)])
                    .presentationDragIndicator(.visible)
            }
        } else {
            self.background(LegacySheetDetentsConfigurator(style: style))
        }
    }

    @ViewBuilder
    func svClearScrollBackground() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self.onAppear {
                UITextView.appearance().backgroundColor = .clear
            }
        }
    }
}
