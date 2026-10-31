import Contacts
import ContactsUI
import SwiftUI
import UniformTypeIdentifiers

/// Screen [7] Add guests: tabs Manual · Contacts · Excel (spec/screens.md §7).
struct AddGuestView: View {
    let manual: ManualGuestViewModel
    let contacts: ContactsViewModel
    let excel: ExcelImportViewModel
    @State var tab: Int
    let onClose: () -> Void
    let onPremium: () -> Void
    let onAddon: () -> Void
    let onChanged: () -> Void
    @State private var toast: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text("guests.add.title").devetFont(DevetType.serifTitle).foregroundStyle(Color.DS.textPrimary).padding(.horizontal, Spacing.gutter)
            HStack(spacing: Spacing.s0_5) {
                ForEach(Array(["guests.tab.manual", "guests.tab.contacts", "guests.tab.excel"].enumerated()), id: \.offset) { i, key in
                    Chip(title: Text(LocalizedStringKey(key)), selected: tab == i) { tab = i }.frame(maxWidth: .infinity)
                }
            }
            .padding(Spacing.s0_5)
            .background(Capsule().fill(Color.DS.bgSunken))
            .padding(.horizontal, Spacing.gutter)
            switch tab {
            case 0: ManualTab(vm: manual, onClose: onClose, onPremium: onPremium, onAddon: onAddon, onAdded: added)
            case 1: ContactsTab(vm: contacts, onPremium: onPremium, onAddon: onAddon, onAdded: added)
            default: ExcelTab(vm: excel, onPremium: onPremium, onAddon: onAddon, onAdded: added)
            }
        }
        .padding(.top, Spacing.s1)
        .background(Color.DS.bgCanvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if let toast {
                ToastBanner(message: LocalizedStringKey(toast))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task { try? await Task.sleep(nanoseconds: 3_000_000_000); self.toast = nil }
            }
        }
        .animation(.easeOut(duration: Motion.base), value: toast)
    }

    private func added(_ text: String) {
        onChanged()
        toast = text
    }
}

private struct TabScroll<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s2) { content }
                .padding(.horizontal, Spacing.gutter).padding(.vertical, Spacing.s1)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Manual

private struct ManualTab: View {
    @ObservedObject var vm: ManualGuestViewModel
    let onClose: () -> Void
    let onPremium: () -> Void
    let onAddon: () -> Void
    let onAdded: (String) -> Void

    var body: some View {
        TabScroll {
            ChipRow(label: "guest.salutation", items: Salutation.allCases, title: { Text(LocalizedStringKey($0.labelKey)) }, selected: vm.form.salutation) { vm.form.salutation = $0 }
            DevetTextField(label: "guest.name", icon: DevetIcon.user, text: $vm.form.name, contentType: .name,
                           isError: vm.nameError, supporting: vm.nameError ? "guest.error.name" : nil)
            Toggle(isOn: $vm.form.withFamily) { Text("guest.with_family").devetFont(DevetType.body) }.tint(Color.DS.brandPrimary)
            CountStepper(value: $vm.form.count)
            PhoneField(phone: $vm.form.phone, issue: vm.phoneProblem, duplicateOf: vm.duplicateOf)
            ChipRow(label: "guest.side", items: Side.allCases, title: { Text(LocalizedStringKey($0.labelKey)) }, selected: vm.form.side) { vm.form.side = $0 }
            DevetTextField(label: "guest.table", icon: "tablecells", text: $vm.form.table)
            ChipRow(label: "guest.lang", items: [nil] + SystemAppLanguage.supported.map(Optional.some),
                    title: { $0.map { Text(LocalizedStringKey("lang.\($0)")) } ?? Text("guest.lang.event") }, selected: vm.form.lang) { vm.form.lang = $0 }
            GreetingPreview(names: vm.spec.displayNames, form: vm.form, eventLang: vm.eventLang)
            if let error = vm.error { ErrorBanner(message: error.messageKey) }
            PrimaryButton(title: "guest.save_next", loading: vm.saving) { Task { await vm.save(andNext: true) } }
            LinkButton(title: "common.save") { Task { await vm.save(andNext: false) } }.frame(maxWidth: .infinity)
        }
        .task { await vm.load() }
        .onChange(of: vm.added) { name in
            guard let name else { return }
            vm.added = nil
            if vm.done { onClose() } else { onAdded(localized("guest.added", name)) }
        }
        .sheet(item: $vm.limit) { LimitSheet(hit: $0, onPremium: onPremium, onAddon: onAddon) }
    }
}

// MARK: - Contacts

private struct ContactsTab: View {
    @ObservedObject var vm: ContactsViewModel
    let onPremium: () -> Void
    let onAddon: () -> Void
    let onAdded: (String) -> Void
    @State private var picking = false
    @State private var presenter = ContactPickerPresenter()

    var body: some View {
        TabScroll {
            HStack(spacing: Spacing.s1_5) {
                Image(systemName: "person.crop.rectangle.stack").font(.title).foregroundStyle(Color.DS.accentGold)
                Text("contacts.title").devetFont(DevetType.serifHeadline).foregroundStyle(Color.DS.textPrimary)
            }
            Text("contacts.body").devetFont(DevetType.body).foregroundStyle(Color.DS.textSecondary)
            ForEach(vm.picked) { p in
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name).devetFont(DevetType.headline).foregroundStyle(Color.DS.textPrimary)
                            if let phone = p.phoneE164 {
                                Text(phone).devetFont(DevetType.footnote).foregroundStyle(Color.DS.textSecondary)
                            } else {
                                Text("contacts.no_mobile").devetFont(DevetType.footnote).foregroundStyle(Color.DS.feedbackWarning)
                            }
                            if let dup = p.duplicateOf { Text(localized("guest.duplicate", dup)).devetFont(DevetType.footnote).foregroundStyle(Color.DS.feedbackWarning) }
                        }
                        Spacer()
                        LinkButton(title: "contacts.remove") { vm.remove(p.id) }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.s1) {
                            ForEach(Salutation.allCases) { s in Chip(title: Text(LocalizedStringKey(s.labelKey)), selected: p.salutation == s) { vm.edit(p.id) { $0.salutation = s } } }
                        }
                    }
                    CountStepper(value: Binding(get: { p.count }, set: { v in vm.edit(p.id) { $0.count = v } }))
                }
                .padding(Spacing.s2)
                .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.DS.bgSurface))
            }
            if vm.picked.isEmpty {
                PrimaryButton(title: "contacts.pick") { picking = true }
            } else {
                LinkButton(title: "contacts.pick_more") { picking = true }
            }
            Text("contacts.privacy").devetFont(DevetType.footnote).foregroundStyle(Color.DS.textSecondary)
            if let error = vm.error { ErrorBanner(message: error.messageKey) }
            if !vm.picked.isEmpty {
                PrimaryButton(title: LocalizedStringKey(plural("contacts.add", vm.picked.count)), loading: vm.saving) { Task { await vm.addAll() } }
            }
        }
        .task { await vm.load() }
        .onChange(of: picking) { show in
            guard show else { return }
            picking = false
            presenter.present { contacts in
                for c in contacts {
                    let name = CNContactFormatter.string(from: c, style: .fullName) ?? c.givenName
                    vm.picked(name: name, numbers: c.phoneNumbers.map { $0.value.stringValue })
                }
            }
        }
        .confirmationDialog(vm.choosing?.name ?? "", isPresented: Binding(get: { vm.choosing != nil }, set: { if !$0 { vm.choosing = nil } }), titleVisibility: .visible) {
            ForEach(vm.choosing?.numbers ?? [], id: \.self) { number in
                Button(number) { if let c = vm.choosing { vm.add(name: c.name, number: number) }; vm.choosing = nil }
            }
        }
        .onChange(of: vm.addedCount) { n in
            guard let n else { return }
            vm.addedCount = nil
            onAdded(plural("guests.added_many", n))
        }
        .sheet(item: $vm.limit) { LimitSheet(hit: $0, onPremium: onPremium, onAddon: onAddon) }
    }
}

/// System contact picker: several contacts at once, no contacts permission (the app only gets what was picked).
/// Presented by UIKit from the top view controller — embedded in a SwiftUI sheet it stays blank.
@MainActor
private final class ContactPickerPresenter: NSObject, CNContactPickerDelegate {
    private var onPick: (([CNContact]) -> Void)?

    func present(onPick: @escaping ([CNContact]) -> Void) {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
        guard var top = scene?.keyWindow?.rootViewController else { return }
        while let next = top.presentedViewController { top = next }
        self.onPick = onPick
        let picker = CNContactPickerViewController()
        picker.delegate = self
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        top.present(picker, animated: true)
    }

    nonisolated func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
        MainActor.assumeIsolated { onPick?(contacts); onPick = nil }
    }

    nonisolated func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        MainActor.assumeIsolated { onPick = nil }
    }
}

// MARK: - Excel

private let fieldLabels: [(String, LocalizedStringKey)] = [
    ("name", "guest.name"), ("phone", "guest.phone"), ("salutation", "guest.salutation"), ("invited_count", "guest.count"),
    ("with_family", "guest.with_family"), ("side", "guest.side"), ("table_no", "guest.table"),
]

/// "C" for column index 2.
private func letter(_ i: Int) -> String { i < 26 ? String(UnicodeScalar(65 + i)!) : letter(i / 26 - 1) + String(UnicodeScalar(65 + i % 26)!) }

private struct ExcelTab: View {
    @ObservedObject var vm: ExcelImportViewModel
    let onPremium: () -> Void
    let onAddon: () -> Void
    let onAdded: (String) -> Void
    @State private var importing = false
    private static let xlsx = UTType(filenameExtension: "xlsx") ?? .data

    var body: some View {
        TabScroll {
            switch vm.step {
            case .pick, .reading, .fileError:
                pickCard
                if case let .fileError(noRows) = vm.step {
                    ErrorBanner(message: noRows ? "excel.no_rows" : LocalizedStringKey(NSLocalizedString("excel.file_error", comment: "") + "\n" + NSLocalizedString("excel.file_error_body", comment: "")))
                }
            case let .mapping(m): mapping(m)
            case let .summary(s): summary(s)
            }
            if let error = vm.error { ErrorBanner(message: error.messageKey) }
        }
        .task { await vm.load() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [Self.xlsx]) { result in
            guard case let .success(url) = result else { return }
            Task {
                await vm.open(fileName: url.lastPathComponent) {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    return try Data(contentsOf: url)
                }
            }
        }
        .onChange(of: vm.addedCount) { n in
            guard let n else { return }
            vm.addedCount = nil
            onAdded(plural("guests.added_many", n))
        }
        .sheet(item: $vm.limit) { LimitSheet(hit: $0, onPremium: onPremium, onAddon: onAddon) }
    }

    private var pickCard: some View {
        VStack(spacing: Spacing.s1_5) {
            Image(systemName: "square.and.arrow.up").font(.largeTitle.weight(.light)).foregroundStyle(Color.DS.accentGold)
            Text("excel.title").devetFont(DevetType.serifHeadline).foregroundStyle(Color.DS.textPrimary).multilineTextAlignment(.center)
            Text("excel.body").devetFont(DevetType.callout).foregroundStyle(Color.DS.textSecondary)
            PrimaryButton(title: "excel.choose", loading: vm.step == .reading) { importing = true }
            if let url = Bundle.main.url(forResource: "guests-sample", withExtension: "xlsx", subdirectory: "sample") {
                // Shared under the localized file name so it saves as e.g. "qonaqlar-numune.xlsx".
                ShareLink(item: SampleFile(url: url), preview: SharePreview(Text("excel.sample"))) {
                    Text("excel.sample").devetFont(DevetType.headline).foregroundStyle(Color.DS.textLink).frame(minHeight: Sizes.touchMin)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.s3)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.DS.bgSurface))
    }

    @ViewBuilder private func mapping(_ m: ExcelMapping) -> some View {
        Text("excel.map_title").devetFont(DevetType.serifHeadline).foregroundStyle(Color.DS.textPrimary)
        Text(localized("excel.map_body", m.fileName, "\(m.rows.count)")).devetFont(DevetType.callout).foregroundStyle(Color.DS.textSecondary)
        if !m.hasName { ErrorBanner(message: "excel.name_column_missing") }
        ForEach(Array(m.headers.enumerated()), id: \.offset) { col, header in
            HStack {
                Text(localized("excel.column", letter(col), header)).devetFont(DevetType.body).foregroundStyle(Color.DS.textPrimary)
                Spacer()
                Menu {
                    ForEach(fieldLabels, id: \.0) { field, label in Button { vm.setColumn(col, field) } label: { Text(label) } }
                    Button { vm.setColumn(col, nil) } label: { Text("excel.skip") }
                } label: {
                    Text(fieldLabels.first { $0.0 == m.columns[col] }?.1 ?? "excel.skip").devetFont(DevetType.headline).foregroundStyle(Color.DS.textLink)
                }
            }
            .padding(.horizontal, Spacing.s2)
            .frame(minHeight: Sizes.controlHeight)
            .background(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).fill(Color.DS.bgSurface))
        }
        Text("excel.preview").devetFont(DevetType.caption).foregroundStyle(Color.DS.textSecondary)
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(m.rows.prefix(5).enumerated()), id: \.offset) { _, row in
                    HStack(spacing: Spacing.s1) {
                        ForEach(m.headers.indices, id: \.self) { i in
                            Text(i < row.count ? ExcelRules.asText(row[i]) : "").devetFont(DevetType.footnote).lineLimit(1).frame(width: 120, alignment: .leading)
                        }
                    }
                }
            }
            .padding(Spacing.s1_5)
        }
        .background(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).fill(Color.DS.bgSurface))
        PrimaryButton(title: "excel.continue", enabled: m.hasName) { vm.toSummary() }
        LinkButton(title: "excel.choose") { vm.restart() }
    }

    @ViewBuilder private func summary(_ s: ExcelSummary) -> some View {
        Text(localized("excel.summary", "\(s.guests.count)", "\(s.errors.count)")).devetFont(DevetType.headline).foregroundStyle(Color.DS.textPrimary)
        GeometryReader { geo in
            let total = max(1, s.guests.count + s.errors.count)
            HStack(spacing: 0) {
                Capsule().fill(Color.DS.feedbackSuccess).frame(width: geo.size.width * CGFloat(s.guests.count) / CGFloat(total))
                Spacer(minLength: 0)
            }
            .background(Capsule().fill(Color.DS.feedbackDangerBg))
        }
        .frame(height: 8)
        if s.duplicates > 0 {
            Text(localized("excel.duplicates", "\(s.duplicates)")).devetFont(DevetType.callout).foregroundStyle(Color.DS.feedbackWarning)
        }
        if !s.errors.isEmpty {
            Text("excel.errors_title").devetFont(DevetType.caption).foregroundStyle(Color.DS.textSecondary)
            VStack(alignment: .leading, spacing: Spacing.s0_5) {
                ForEach(Array(s.errors.prefix(50).enumerated()), id: \.offset) { _, e in
                    Text(localized("excel.row", "\(e.sheetRow)", e.codes.map { NSLocalizedString("excel.err.\($0)", comment: "") }.joined(separator: ", ")))
                        .devetFont(DevetType.footnote).foregroundStyle(Color.DS.feedbackDanger)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.s1_5)
            .background(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).fill(Color.DS.bgSurface))
        }
        if s.importing {
            Text("excel.importing").devetFont(DevetType.callout).foregroundStyle(Color.DS.textSecondary)
            ProgressView().tint(Color.DS.accentGold)
        }
        PrimaryButton(title: LocalizedStringKey(plural("excel.import", s.guests.count)), enabled: !s.guests.isEmpty, loading: s.importing) {
            Task { await vm.importAll() }
        }
        LinkButton(title: "common.back") { vm.backToMapping() }
    }
}

/// The bundled sample, exported under the localized file name.
private struct SampleFile: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: UTType(filenameExtension: "xlsx") ?? .data) { file in
            let name = NSLocalizedString("excel.sample_name", comment: "")
            let target = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.copyItem(at: file.url, to: target)
            return SentTransferredFile(target)
        }
    }
}

// MARK: - Limit

/// Limit refusal (screens.md §7 "Limit"): nothing was added; offer a premium template or a limit add-on.
struct LimitSheet: View {
    let hit: LimitHit
    let onPremium: () -> Void
    let onAddon: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s1_5) {
            Text(localized("limit.title", hit.limit.map(String.init) ?? "—")).devetFont(DevetType.serifHeadline).foregroundStyle(Color.DS.textPrimary)
            Text("limit.body").devetFont(DevetType.body).foregroundStyle(Color.DS.textSecondary)
            PrimaryButton(title: "limit.premium") { dismiss(); onPremium() }
            LinkButton(title: "limit.addon") { dismiss(); onAddon() }.frame(maxWidth: .infinity)
        }
        .padding(Spacing.gutter)
        .presentationDetents([.medium])
        .background(Color.DS.bgRaised.ignoresSafeArea())
        .accessibilityIdentifier("limitSheet")
    }
}
