import SwiftUI

/// Inside an event: tab bar Guests · Send · Statistics · More (screens.md §0). Send/Stats/More come later.
struct EventView: View {
    @StateObject var vm: GuestListViewModel
    let title: String
    let reloadToken: Int
    let storage: any StorageRepository
    let onAdd: (Int) -> Void
    let onLimit: () -> Void

    var body: some View {
        TabView {
            GuestListView(vm: vm, title: title, reloadToken: reloadToken, onAdd: onAdd, onLimit: onLimit)
                .tabItem { Label("nav.guests", systemImage: "person.2") }
            PreviewListView(eventId: vm.eventId, repo: vm.repo, events: vm.events, storage: storage, displayNames: vm.spec.displayNames, onReady: { /* TODO: T48I send flow */ })
                .tabItem { Label("nav.send", systemImage: "paperplane") }
            ComingSoonView(title: nil).tabItem { Label("nav.stats", systemImage: "chart.bar") }
            ComingSoonView(title: nil).tabItem { Label("nav.more", systemImage: "ellipsis") }
        }
        .tint(Color.DS.brandPrimary)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Screen [6] Guests (spec/screens.md §6).
struct GuestListView: View {
    @ObservedObject var vm: GuestListViewModel
    let title: String
    let reloadToken: Int
    let onAdd: (Int) -> Void
    let onLimit: () -> Void
    @State private var tableText = ""
    @State private var sidePicker = false
    @State private var toast: LocalizedStringKey?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                if vm.selecting { selectionBar } else {
                    Text(verbatim: title).devetFont(DevetType.footnote).foregroundStyle(Color.DS.textSecondary).lineLimit(1)
                        .padding(.horizontal, Spacing.gutter)
                }
                if !vm.loading && vm.guests.isEmpty && vm.error == nil {
                    EmptyGuests(onAdd: onAdd)
                } else {
                    content
                }
            }
            if !vm.selecting && !vm.guests.isEmpty {
                Button { onAdd(0) } label: {
                    Text("guests.add").devetFont(DevetType.headline).foregroundStyle(Color.DS.textOnBrand)
                        .padding(.horizontal, Spacing.s3).frame(minHeight: Sizes.controlHeight)
                        .background(Capsule().fill(Color.DS.brandPrimary))
                        .shadow(color: .black.opacity(0.1), radius: 16, y: 8)
                }
                .buttonStyle(.plain)
                .padding(Spacing.s2)
                .accessibilityIdentifier("fab")
            }
        }
        .background(Color.DS.bgCanvas.ignoresSafeArea())
        .task(id: reloadToken) { await vm.load() }
        .overlay(alignment: .top) {
            if let toast {
                ToastBanner(message: toast).transition(.move(edge: .top).combined(with: .opacity))
                    .task { try? await Task.sleep(nanoseconds: 3_000_000_000); self.toast = nil }
            }
        }
        .animation(.easeOut(duration: Motion.base), value: toast != nil)
        .onChange(of: vm.message) { m in
            guard let m else { return }
            toast = m == .saved ? "settings.saved" : "guests.deleted"
            vm.message = nil
        }
        .onChange(of: vm.actionError) { e in if let e { toast = e.messageKey; vm.actionError = nil } }
        .sheet(item: $vm.editing) { _ in EditGuestSheet(vm: vm) }
        .alert(deleteTitle, isPresented: Binding(get: { vm.confirmDelete != nil }, set: { if !$0 { vm.confirmDelete = nil } })) {
            Button(role: .destructive) { Task { await vm.performDelete() } } label: { Text("events.delete.confirm") }
            Button(role: .cancel) { vm.confirmDelete = nil } label: { Text("common.cancel") }
        } message: { Text("guests.delete.body") }
        .alert(Text("guests.bulk.table"), isPresented: $vm.bulkTable) {
            TextField(text: $tableText) { Text("guests.bulk.table_hint") }
            Button { Task { await vm.bulkTable(tableText); tableText = "" } } label: { Text("guests.bulk.apply") }
            Button(role: .cancel) { tableText = "" } label: { Text("common.cancel") }
        } message: { Text("guests.bulk.table_hint") }
        .confirmationDialog(Text("guest.side"), isPresented: $sidePicker, titleVisibility: .visible) {
            ForEach(Side.allCases) { side in Button { Task { await vm.bulkSide(side) } } label: { Text(LocalizedStringKey(side.labelKey)) } }
        }
    }

    private var deleteTitle: String {
        guard let ids = vm.confirmDelete else { return "" }
        if ids.count == 1, let g = vm.guests.first(where: { $0.id == ids[0] }) {
            return localized("guests.delete.title", vm.spec.displayNames.displayName(g.name, g.salutation, withFamily: g.withFamily, lang: g.lang ?? vm.eventLang))
        }
        return plural("guests.bulk.delete_title", ids.count)
    }

    @ViewBuilder private var content: some View {
        HStack {
            Text("guests.title").devetFont(DevetType.serifTitle).foregroundStyle(Color.DS.textPrimary)
            Spacer()
            LimitRing(count: vm.guests.count, limit: vm.limit, level: vm.level)
        }
        .padding(.horizontal, Spacing.gutter).padding(.vertical, Spacing.s1)
        if vm.level != .normal, let limit = vm.limit {
            let near = vm.level == .near
            Button(action: onLimit) {
                Text(near ? plural("limit.near", limit - vm.guests.count) : NSLocalizedString("limit.full", comment: ""))
                    .devetFont(DevetType.footnote).foregroundStyle(near ? Color.DS.accentGoldText : Color.DS.feedbackDanger)
                    .padding(.horizontal, Spacing.s1_5).padding(.vertical, Spacing.s0_5)
                    .background(Capsule().fill(near ? Color.DS.accentGoldSubtle : Color.DS.feedbackDangerBg))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.gutter)
        }
        DevetTextField(label: "guests.search", icon: "magnifyingglass", text: $vm.query, submitLabel: .search)
            .padding(.horizontal, Spacing.gutter).padding(.vertical, Spacing.s1)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s1) {
                ForEach(GuestFilter.allCases) { f in
                    Chip(title: Text(localized("guests.chip", NSLocalizedString(f.labelKey, comment: ""), "\(vm.count(f))")), selected: vm.filter == f) { vm.filter = f }
                }
            }
            .padding(.horizontal, Spacing.gutter)
        }
        if let error = vm.error {
            VStack(alignment: .leading) {
                ErrorBanner(message: LocalizedStringKey(NSLocalizedString("guests.load_error", comment: "") + " " + error.messageText))
                LinkButton(title: "common.retry") { Task { await vm.load() } }
            }
            .padding(.horizontal, Spacing.gutter).padding(.top, Spacing.s1)
        }
        if vm.loading {
            VStack(spacing: Spacing.s1) {
                ForEach(0..<6, id: \.self) { _ in RoundedRectangle(cornerRadius: Radius.control).fill(Color.DS.bgSunken).frame(height: 56) }
            }
            .padding(Spacing.gutter)
            Spacer()
        } else if vm.visible.isEmpty && !vm.query.trimmed.isEmpty {
            VStack(spacing: Spacing.s1) {
                Text(localized("guests.no_results", vm.query.trimmed)).devetFont(DevetType.serifHeadline).foregroundStyle(Color.DS.textPrimary)
                Text("guests.no_results_body").devetFont(DevetType.callout).foregroundStyle(Color.DS.textSecondary)
            }
            .multilineTextAlignment(.center).frame(maxWidth: .infinity, maxHeight: .infinity).padding(Spacing.gutter)
        } else {
            List {
                ForEach(vm.visible) { g in
                    GuestRowView(guest: g, names: vm.spec.displayNames, eventLang: vm.eventLang, selected: vm.selected.contains(g.id), selecting: vm.selecting)
                        .contentShape(Rectangle())
                        .onTapGesture { if vm.selecting { vm.toggle(g.id) } else { vm.open(g) } }
                        .onLongPressGesture { vm.toggle(g.id) }
                        .listRowBackground(vm.selected.contains(g.id) ? Color.DS.brandSubtle : Color.DS.bgCanvas)
                        .listRowInsets(EdgeInsets(top: Spacing.s1, leading: Spacing.gutter, bottom: Spacing.s1, trailing: Spacing.gutter))
                        // Swipe left: Edit / Delete (delete for the owner only), screens.md §6.
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if vm.isOwner {
                                Button(role: .destructive) { vm.askDelete([g.id]) } label: { Text("events.menu.delete") }
                            }
                            Button { vm.open(g) } label: { Text("events.menu.edit") }.tint(Color.DS.brandPrimary)
                        }
                }
                Color.clear.frame(height: 72).listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { await vm.load() }
        }
    }

    /// Multi-select top bar + actions: Assign table · Side · Delete (owner), screens.md §6.
    private var selectionBar: some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            HStack {
                Text(localized("guests.selected", "\(vm.selected.count)")).devetFont(DevetType.headline).foregroundStyle(Color.DS.textPrimary)
                Spacer()
                LinkButton(title: "guests.done") { vm.clearSelection() }
            }
            HStack(spacing: Spacing.s1) {
                Chip(title: Text("guests.bulk.table"), selected: false) { vm.bulkTable = true }
                Chip(title: Text("guest.side"), selected: false) { sidePicker = true }
                if vm.isOwner { Chip(title: Text("events.menu.delete"), selected: false) { vm.askDelete(Array(vm.selected)) } }
            }
        }
        .padding(.horizontal, Spacing.s2).padding(.vertical, Spacing.s1)
        .background(Color.DS.bgSurface)
    }
}

/// "84/100" ring; gold near the limit, red when full.
private struct LimitRing: View {
    let count: Int
    let limit: Int?
    let level: LimitLevel

    var body: some View {
        let color: Color = switch level { case .normal: Color.DS.brandPrimary; case .near: Color.DS.accentGoldStrong; case .full: Color.DS.feedbackDanger }
        let progress = limit.map { $0 > 0 ? min(1, Double(count) / Double($0)) : 0 } ?? 0
        ZStack {
            Circle().stroke(Color.DS.borderHairline, lineWidth: 4)
            Circle().trim(from: 0, to: progress).stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
            Text(verbatim: limit.map { "\(count)/\($0)" } ?? "\(count)").devetFont(DevetType.footnote).foregroundStyle(Color.DS.textPrimary)
        }
        .frame(width: 64, height: 64)
        .accessibilityIdentifier("limitRing")
    }
}

/// Status pill: always text, colour only helps (design.md §2.2).
struct StatusPill: View {
    let guest: Guest

    var body: some View {
        let (colors, text): (StatusColors, String) = switch guest.status {
        case .coming: (Color.DS.statusComing, localized("status.coming", "\(guest.rsvpCount)"))
        case .declined: (Color.DS.statusDeclined, NSLocalizedString("status.declined", comment: ""))
        case .viewed: (Color.DS.statusViewed, NSLocalizedString("status.viewed", comment: ""))
        case .pending: (Color.DS.statusPending, NSLocalizedString("status.pending", comment: ""))
        case .unsent: (Color.DS.statusUnsent, NSLocalizedString("status.unsent", comment: ""))
        }
        HStack(spacing: Spacing.s0_5) {
            Circle().fill(colors.fg).frame(width: 6, height: 6)
            Text(text).devetFont(DevetType.caption).foregroundStyle(colors.text).lineLimit(1)
        }
        .padding(.horizontal, Spacing.s1).padding(.vertical, Spacing.s0_5)
        .background(Capsule().fill(colors.bg))
    }
}

private struct GuestRowView: View {
    let guest: Guest
    let names: DisplayNames
    let eventLang: String
    let selected: Bool
    let selecting: Bool

    var body: some View {
        let g = guest
        let line2 = [
            plural("guests.people", g.invitedCount),
            g.tableNo.flatMap { $0.trimmed.isEmpty ? nil : localized("guests.table_short", $0) },
            g.side == .none ? nil : NSLocalizedString(g.side.labelKey, comment: ""),
        ].compactMap { $0 }.joined(separator: " · ")
        HStack(spacing: Spacing.s1_5) {
            if selecting {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title3)
                    .foregroundStyle(selected ? Color.DS.brandPrimary : Color.DS.borderControl)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(names.displayName(g.name, g.salutation, withFamily: g.withFamily, lang: g.lang ?? eventLang))
                    .devetFont(DevetType.headline).foregroundStyle(Color.DS.textPrimary)
                Text(line2).devetFont(DevetType.footnote).foregroundStyle(Color.DS.textSecondary)
            }
            Spacer(minLength: Spacing.s1)
            StatusPill(guest: g)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Edit sheet (screens.md §6.1).
private struct EditGuestSheet: View {
    @ObservedObject var vm: GuestListViewModel

    var body: some View {
        if let e = vm.editing {
            let form = Binding(get: { vm.editing?.form ?? e.form }, set: { new in vm.edit { $0 = new } })
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    Text("guests.edit.title").devetFont(DevetType.serifHeadline).foregroundStyle(Color.DS.textPrimary)
                    ChipRow(label: "guest.salutation", items: Salutation.allCases, title: { Text(LocalizedStringKey($0.labelKey)) }, selected: e.form.salutation) { v in vm.edit { $0.salutation = v } }
                    DevetTextField(label: "guest.name", icon: DevetIcon.user, text: form.name, contentType: .name,
                                   isError: e.nameError, supporting: e.nameError ? "guest.error.name" : nil)
                    Toggle(isOn: form.withFamily) { Text("guest.with_family").devetFont(DevetType.body) }.tint(Color.DS.brandPrimary)
                    CountStepper(value: form.count)
                    PhoneField(phone: form.phone, issue: e.phoneProblem, duplicateOf: nil)
                    ChipRow(label: "guest.side", items: Side.allCases, title: { Text(LocalizedStringKey($0.labelKey)) }, selected: e.form.side) { v in vm.edit { $0.side = v } }
                    DevetTextField(label: "guest.table", icon: "tablecells", text: form.table)
                    ChipRow(label: "guest.lang", items: [nil] + SystemAppLanguage.supported.map(Optional.some),
                            title: { $0.map { Text(LocalizedStringKey("lang.\($0)")) } ?? Text("guest.lang.event") }, selected: e.form.lang) { v in vm.edit { $0.lang = v } }
                    GreetingPreview(names: vm.spec.displayNames, form: e.form, eventLang: vm.eventLang)
                    PrimaryButton(title: "common.save", loading: e.saving) { Task { await vm.saveEdit() } }
                    if vm.isOwner {
                        LinkButton(title: "guests.delete") { vm.askDelete([e.guest.id]) }.frame(maxWidth: .infinity)
                    }
                }
                .padding(Spacing.gutter)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.DS.bgCanvas.ignoresSafeArea())
            .presentationDetents([.large])
        }
    }
}

/// Empty state of [6]: three ways to add guests.
private struct EmptyGuests: View {
    let onAdd: (Int) -> Void

    var body: some View {
        VStack(spacing: Spacing.s1_5) {
            Spacer()
            EnvelopeArt().stroke(Color.DS.accentGold, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                .frame(width: 160, height: 124).accessibilityHidden(true)
            Text("guests.empty.title").devetFont(DevetType.serifHeadline).foregroundStyle(Color.DS.textPrimary)
            Text("guests.empty.body").devetFont(DevetType.body).foregroundStyle(Color.DS.textSecondary).multilineTextAlignment(.center)
            PrimaryButton(title: "guests.add.manual") { onAdd(0) }.padding(.top, Spacing.s2)
            LinkButton(title: "guests.add.contacts") { onAdd(1) }
            LinkButton(title: "guests.add.excel") { onAdd(2) }
            Spacer()
        }
        .padding(Spacing.gutter)
    }
}
