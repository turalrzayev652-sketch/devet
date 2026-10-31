import SwiftUI

/// Screen [12b] Settings (spec/screens.md §12b).
struct SettingsView: View {
    @StateObject var vm: SettingsViewModel
    let termsURL: URL?
    let privacyURL: URL?
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("settings.title").devetFont(DevetType.serifDisplay).foregroundStyle(Color.DS.textPrimary)
                if let error = vm.error { ErrorBanner(message: error.messageKey) }

                Section(title: "settings.profile") {
                    DevetTextField(
                        label: "settings.name", icon: DevetIcon.user, text: $vm.name, contentType: .name,
                        supporting: vm.saved ? "settings.saved" : nil, submitLabel: .done, onSubmit: { Task { await vm.saveName() } }
                    )
                    DevetTextField(label: "auth.email", icon: DevetIcon.mail, text: .constant(vm.email), keyboard: .emailAddress, readOnly: true)
                    PrimaryButton(title: "common.save", enabled: vm.canSaveName, loading: vm.saving) { Task { await vm.saveName() } }
                }

                Section(title: "settings.language") {
                    // iOS: the language is chosen in Settings → Devet → Language (decision 2026-10-31).
                    Card {
                        Row(title: Text(LocalizedStringKey("lang.\(vm.language.effective)")), icon: DevetIcon.chevronRight) {
                            vm.language.openSystemSettings()
                        }
                    }
                }

                Section(title: "settings.about") {
                    Card {
                        Row(title: Text("settings.terms"), icon: DevetIcon.chevronRight) { termsURL.map { openURL($0) } }
                        Divider().overlay(Color.DS.borderHairline)
                        Row(title: Text("settings.privacy"), icon: DevetIcon.chevronRight) { privacyURL.map { openURL($0) } }
                        Divider().overlay(Color.DS.borderHairline)
                        Text(localized("settings.version", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""))
                            .devetFont(DevetType.callout).foregroundStyle(Color.DS.textSecondary)
                            .padding(Spacing.s2).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Card {
                    Row(title: Text("settings.logout"), icon: nil) { Task { await vm.signOut() } }
                        .accessibilityIdentifier("logout")
                    Divider().overlay(Color.DS.borderHairline)
                    Row(title: Text("settings.delete.button"), icon: DevetIcon.trash, color: Color.DS.feedbackDanger) { vm.openDelete() }
                        .accessibilityIdentifier("delete")
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.s1)
        }
        .background(Color.DS.bgCanvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .sheet(isPresented: $vm.deleteDialog) { DeleteAccountSheet(vm: vm) }
    }
}

/// Deletion confirmation: explanation + the account e-mail typed again (screens.md §12b). A sheet, because an
/// iOS alert cannot hold the explanation, a text field and an error together.
private struct DeleteAccountSheet: View {
    @ObservedObject var vm: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text("settings.delete.title").devetFont(DevetType.serifHeadline).foregroundStyle(Color.DS.textPrimary)
            Text("settings.delete.body").devetFont(DevetType.body).foregroundStyle(Color.DS.textPrimary)
            DevetTextField(label: "settings.delete.confirm_hint", icon: DevetIcon.mail, text: $vm.deleteConfirm, keyboard: .emailAddress, submitLabel: .done)
            if vm.deleteFailed { ErrorBanner(message: "settings.delete.error") }
            Button { Task { await vm.deleteAccount() } } label: {
                ZStack {
                    if vm.deleting { ProgressView().tint(Color.DS.textOnBrand) } else { Text("settings.delete.confirm").devetFont(DevetType.headline) }
                }
                .frame(maxWidth: .infinity, minHeight: Sizes.controlHeight)
                .foregroundStyle(vm.canDelete || vm.deleting ? Color.DS.textOnBrand : Color.DS.textSecondary)
                .background(RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(vm.canDelete || vm.deleting ? Color.DS.feedbackDanger : Color.DS.bgSunken))
            }
            .buttonStyle(.plain)
            .disabled(!vm.canDelete || vm.deleting)
            .accessibilityIdentifier("deleteConfirmButton")
            Button { vm.deleteDialog = false } label: {
                Text("common.cancel").devetFont(DevetType.headline).foregroundStyle(Color.DS.textLink).frame(maxWidth: .infinity, minHeight: Sizes.touchMin)
            }
            .buttonStyle(.plain)
            .disabled(vm.deleting)
        }
        .padding(Spacing.gutter)
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(vm.deleting)
        .background(Color.DS.bgRaised.ignoresSafeArea())
    }
}

private struct Section<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s1_5) {
            Text(title).textCase(.uppercase).devetFont(DevetType.caption).foregroundStyle(Color.DS.textSecondary)
            content
        }
    }
}

private struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.DS.bgSurface))
    }
}

private struct Row: View {
    let title: Text
    let icon: String?
    var color = Color.DS.textPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                title.devetFont(DevetType.body).foregroundStyle(color)
                Spacer()
                if let icon {
                    Image(systemName: icon).fontWeight(.light).foregroundStyle(color == Color.DS.textPrimary ? Color.DS.textSecondary : color)
                }
            }
            .padding(.horizontal, Spacing.s2)
            .frame(minHeight: Sizes.controlHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
