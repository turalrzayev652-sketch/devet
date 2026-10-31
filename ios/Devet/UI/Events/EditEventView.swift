import SwiftUI

/// Screen [3] in edit mode: the same fields as one page with sections (screens.md §3). Owner and co-host.
struct EditEventView: View {
    @StateObject var vm: EditEventViewModel
    let onSaved: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    Text("edit.title").devetFont(DevetType.serifTitle).foregroundStyle(Color.DS.textPrimary)
                    if vm.loading {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.DS.bgSunken).frame(height: 120)
                        }
                    } else if vm.original == nil {
                        ErrorBanner(message: (vm.error ?? .unknown).messageKey)
                        LinkButton(title: "common.retry") { Task { await vm.load() } }
                    } else {
                        Section(title: "edit.section.type") { TypeChoices(selected: vm.draft.type) { vm.draft.type = $0 } }
                        Section(title: "create.names") { NamesFields(draft: $vm.draft, showRequired: true) }
                        Section(title: "edit.section.date_time") {
                            DateTimeFields(startsAt: $vm.draft.startsAt, now: vm.now, showPastHint: !vm.dateOK)
                        }
                        Section(title: "edit.section.venue") { VenueFields(draft: $vm.draft, showRequired: true) }
                        Section(title: "create.q5") { LanguageChoices(selected: vm.draft.defaultLang) { vm.draft.defaultLang = $0 } }
                        Section(title: "create.q6") { TablematesToggle(on: $vm.draft.showTablemates) }
                        if let error = vm.error { ErrorBanner(message: error.messageKey) }
                    }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.s1)
            }
            .scrollDismissesKeyboard(.interactively)
            if vm.original != nil {
                PrimaryButton(title: "common.save", enabled: vm.canSave, loading: vm.saving) { Task { await vm.save() } }
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.vertical, Spacing.s2)
                    .accessibilityIdentifier("save")
            }
        }
        .background(Color.DS.bgCanvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task { if vm.original == nil { await vm.load() } }
        .onChange(of: vm.saved) { saved in if saved { onSaved() } }
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
