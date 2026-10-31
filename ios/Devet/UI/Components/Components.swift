import SwiftUI

extension AuthFailure {
    /// User-visible message key (spec/api.md §0.2); same mapping as Android `messageRes()`.
    var messageKey: LocalizedStringKey {
        switch self {
        case .invalidCredentials: "auth.error.invalid_credentials"
        case .userAlreadyExists: "auth.error.email_taken"
        case .weakPassword: "auth.error.weak_password"
        case .rateLimited: "auth.error.rate_limited"
        case .linkInvalid: "auth.error.link_invalid"
        case .network: "common.error.network"
        case .forbidden: "common.error.forbidden"
        case .emailNotConfirmed, .unauthorized, .notConfigured, .unknown: "common.error.unknown"
        }
    }
}

/// Line icons (spec/design.md §6). iOS uses the closest SF Symbols at a light weight.
enum DevetIcon {
    static let mail = "envelope"
    static let lock = "lock"
    static let eye = "eye"
    static let eyeOff = "eye.slash"
    static let user = "person"
    static let alert = "exclamationmark.triangle"
    static let wifiOff = "wifi.slash"
    static let chevronRight = "chevron.right"
    static let trash = "trash"
}

/// Label, bordered box with icon, optional helper or error line below.
struct DevetTextField: View {
    let label: LocalizedStringKey
    let icon: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType?
    var secure = false
    var isError = false
    var supporting: LocalizedStringKey?
    var readOnly = false
    var submitLabel: SubmitLabel = .next
    var onSubmit: () -> Void = {}
    var onFocusChange: (Bool) -> Void = { _ in }

    @State private var revealed = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s0_5) {
            Text(label).devetFont(DevetType.footnote).foregroundStyle(isError ? Color.DS.feedbackDanger : Color.DS.textSecondary)
            HStack(spacing: Spacing.s1_5) {
                Image(systemName: icon).fontWeight(.light).foregroundStyle(Color.DS.textSecondary).frame(width: Sizes.icon)
                    .accessibilityHidden(true)
                Group {
                    if secure && !revealed {
                        SecureField("", text: $text)
                    } else {
                        TextField("", text: $text)
                    }
                }
                .devetFont(DevetType.body)
                .foregroundStyle(Color.DS.textPrimary)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(keyboard == .emailAddress || secure ? .never : .words)
                .autocorrectionDisabled(keyboard == .emailAddress || secure)
                .disabled(readOnly)
                .focused($focused)
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)
                .onChange(of: focused, perform: onFocusChange)
                .accessibilityLabel(Text(label))
                if secure {
                    Button { revealed.toggle() } label: {
                        Image(systemName: revealed ? DevetIcon.eyeOff : DevetIcon.eye).fontWeight(.light)
                            .foregroundStyle(Color.DS.textSecondary).frame(width: Sizes.touchMin, height: Sizes.touchMin)
                    }
                    .accessibilityLabel(Text(revealed ? "auth.password.hide" : "auth.password.show"))
                }
            }
            .padding(.leading, Spacing.s2)
            .padding(.trailing, secure ? Spacing.s0_5 : Spacing.s2)
            .frame(minHeight: Sizes.controlHeight)
            .background(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(focused || isError ? Color.DS.bgSurface : Color.DS.bgSunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .stroke(isError ? Color.DS.feedbackDanger : focused ? Color.DS.borderFocus : Color.DS.borderControl, lineWidth: focused || isError ? 2 : 1)
            )
            if let supporting {
                HStack(spacing: Spacing.s0_5) {
                    if isError { Image(systemName: DevetIcon.alert).font(.footnote).accessibilityHidden(true) }
                    Text(supporting).devetFont(DevetType.footnote)
                }
                .foregroundStyle(isError ? Color.DS.feedbackDanger : Color.DS.textSecondary)
                .padding(.leading, Spacing.s2)
            }
        }
    }
}

/// Main action: brand fill, 52 pt, spinner inside while loading (screens.md §1).
struct PrimaryButton: View {
    let title: LocalizedStringKey
    var enabled = true
    var loading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if loading {
                    ProgressView().tint(Color.DS.textOnBrand)
                } else {
                    Text(title).devetFont(DevetType.headline).multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Sizes.controlHeight)
            .foregroundStyle(enabled || loading ? Color.DS.textOnBrand : Color.DS.textSecondary)
            .background(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(enabled || loading ? Color.DS.brandPrimary : Color.DS.bgSunken)
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled || loading)
    }
}

struct LinkButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).devetFont(DevetType.headline).foregroundStyle(Color.DS.textLink).frame(minHeight: Sizes.touchMin)
        }
        .buttonStyle(.plain)
    }
}

/// Offline strip at the top (screens.md: offline → strip, main action disabled).
struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: Spacing.s1) {
            Image(systemName: DevetIcon.wifiOff).accessibilityHidden(true)
            Text("common.error.network").devetFont(DevetType.callout)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.DS.feedbackWarning)
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.s1_5)
        .background(Color.DS.feedbackWarningBg)
        .accessibilityIdentifier("offline")
    }
}

/// Error strip inside a form (danger background, icon + text).
struct ErrorBanner: View {
    let message: LocalizedStringKey

    var body: some View {
        HStack(spacing: Spacing.s1) {
            Image(systemName: DevetIcon.alert).accessibilityHidden(true)
            Text(message).devetFont(DevetType.callout)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.DS.feedbackDanger)
        .padding(Spacing.s1_5)
        .background(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).fill(Color.DS.feedbackDangerBg))
    }
}

/// Art + serif title + body + actions ("check your e-mail" screens).
struct MessageContent<Actions: View>: View {
    let title: LocalizedStringKey
    let body_: Text
    @ViewBuilder let actions: Actions

    init(title: LocalizedStringKey, body: Text, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.body_ = body
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: Spacing.s1_5) {
            EnvelopeArt().stroke(Color.DS.accentGold, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                .frame(width: 160, height: 124).padding(.bottom, Spacing.s1).accessibilityHidden(true)
            Text(title).devetFont(DevetType.serifHeadline).foregroundStyle(Color.DS.textPrimary).multilineTextAlignment(.center)
            body_.devetFont(DevetType.body).foregroundStyle(Color.DS.textSecondary).multilineTextAlignment(.center)
            VStack(spacing: Spacing.s1) { actions }.padding(.top, Spacing.s2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.s6)
    }
}

/// Top banner toast (spec/design.md §7: iOS toast comes from the top).
struct ToastBanner: View {
    let message: LocalizedStringKey

    var body: some View {
        Text(message).devetFont(DevetType.callout).foregroundStyle(Color.DS.textPrimary)
            .padding(Spacing.s2).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).fill(Color.DS.bgRaised))
            .shadow(color: .black.opacity(0.1), radius: 16, y: 8)
            .padding(.horizontal, Spacing.s2)
            .accessibilityAddTraits(.isStaticText)
    }
}
