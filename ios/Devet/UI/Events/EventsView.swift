import SwiftUI

/// Screen [2] My events (spec/screens.md §2).
struct EventsView: View {
    @StateObject var vm: EventsViewModel
    let reloadToken: Int
    let onSettings: () -> Void
    let onOpen: (EventSummary) -> Void
    let onCreate: () -> Void
    let onEdit: (EventSummary) -> Void
    let onJoin: () -> Void
    @State private var toast: LocalizedStringKey?

    var body: some View {
        let list = vm.showArchive ? vm.archived : vm.active
        VStack(spacing: 0) {
            HStack {
                if vm.showArchive {
                    Button { vm.showArchive = false } label: {
                        Image(systemName: "chevron.left").font(.title3).foregroundStyle(Color.DS.textPrimary).frame(width: Sizes.touchMin, height: Sizes.touchMin)
                    }
                    .accessibilityLabel(Text("common.back"))
                }
                Text(vm.showArchive ? "events.archive.title" : "events.title")
                    .devetFont(DevetType.serifDisplay).foregroundStyle(Color.DS.textPrimary).accessibilityIdentifier("eventsTitle")
                Spacer()
                Button(action: onSettings) {
                    Image(systemName: DevetIcon.user).font(.title3.weight(.light)).foregroundStyle(Color.DS.textPrimary)
                        .frame(width: Sizes.touchMin, height: Sizes.touchMin)
                }
                .accessibilityLabel(Text("settings.title"))
                .accessibilityIdentifier("settings")
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.s2)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    if vm.loading {
                        ForEach(0..<2, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.DS.bgSunken).frame(height: 200)
                        }
                    } else if list.isEmpty && !vm.showArchive && vm.error == nil {
                        EmptyEvents(onCreate: onCreate, onJoin: onJoin)
                    } else {
                        if let error = vm.error {
                            ErrorBanner(message: LocalizedStringKey(NSLocalizedString("events.load_error", comment: "") + " " + error.messageText))
                            LinkButton(title: "common.retry") { Task { await vm.load() } }
                        }
                        ForEach(list) { e in
                            EventCard(
                                event: e, archived: vm.showArchive, canUnarchive: vm.canUnarchive(e),
                                onOpen: { onOpen(e) }, onEdit: { onEdit(e) }, onDelete: { vm.deleteTarget = e },
                                onArchive: { vm.setArchived(e, !vm.showArchive) }
                            )
                        }
                        if !vm.showArchive && !vm.archived.isEmpty {
                            LinkButton(title: LocalizedStringKey(localized("events.archive", "\(vm.archived.count)"))) { vm.showArchive = true }
                                .accessibilityIdentifier("archiveLink")
                        }
                    }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.s2)
            }
            .refreshable { await vm.load() }

            if !vm.showArchive && !vm.loading && !vm.active.isEmpty {
                VStack(spacing: Spacing.s1) {
                    PrimaryButton(title: "events.new", action: onCreate).accessibilityIdentifier("newEvent")
                    LinkButton(title: "events.join", action: onJoin)
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.s2)
            }
        }
        .background(Color.DS.bgCanvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task(id: reloadToken) { await vm.load() }
        .overlay(alignment: .top) {
            if let toast {
                ToastBanner(message: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task { try? await Task.sleep(nanoseconds: 3_000_000_000); self.toast = nil }
            }
        }
        .animation(.easeOut(duration: Motion.base), value: toast != nil)
        .onChange(of: vm.deletedMessage) { shown in if shown { toast = "events.deleted"; vm.deletedMessage = false } }
        .onChange(of: vm.actionError) { error in if let error { toast = error.messageKey; vm.actionError = nil } }
        .alert(
            vm.deleteTarget.map { localized("events.delete.title", $0.titleNames) } ?? "",
            isPresented: Binding(get: { vm.deleteTarget != nil }, set: { if !$0 { vm.deleteTarget = nil } }),
            presenting: vm.deleteTarget
        ) { _ in
            Button(role: .destructive) { Task { await vm.confirmDelete() } } label: { Text("events.delete.confirm") }
            Button(role: .cancel) { vm.deleteTarget = nil } label: { Text("common.cancel") }
        } message: { target in
            Text(plural("events.delete.body", target.guestCount))
        }
    }
}

extension AuthFailure {
    /// Plain text of `messageKey` for building longer sentences.
    var messageText: String {
        switch self {
        case .invalidCredentials: NSLocalizedString("auth.error.invalid_credentials", comment: "")
        case .userAlreadyExists: NSLocalizedString("auth.error.email_taken", comment: "")
        case .weakPassword: NSLocalizedString("auth.error.weak_password", comment: "")
        case .rateLimited: NSLocalizedString("auth.error.rate_limited", comment: "")
        case .linkInvalid: NSLocalizedString("auth.error.link_invalid", comment: "")
        case .network: NSLocalizedString("common.error.network", comment: "")
        case .forbidden: NSLocalizedString("common.error.forbidden", comment: "")
        case .emailNotConfirmed, .unauthorized, .notConfigured, .unknown: NSLocalizedString("common.error.unknown", comment: "")
        }
    }
}

private struct EventCard: View {
    let event: EventSummary
    let archived: Bool
    let canUnarchive: Bool
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onArchive: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Template thumbnail arrives with templates (T44); until then a decorative band.
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.DS.brandSubtle)
                BotanicalArt().padding(Spacing.s1)
                HStack {
                    Text(event.role == .owner ? "events.role.owner" : "events.role.cohost")
                        .devetFont(DevetType.caption).foregroundStyle(Color.DS.textPrimary)
                        .padding(.horizontal, Spacing.s1).padding(.vertical, Spacing.s0_5)
                        .background(Capsule().fill(Color.DS.bgSurface))
                    Spacer()
                    Menu {
                        Button(action: onEdit) { Text("events.menu.edit") }
                        if !archived || canUnarchive {
                            Button(action: onArchive) { Text(archived ? "events.menu.unarchive" : "events.menu.archive") }
                        }
                        if event.role == .owner {
                            Button(role: .destructive, action: onDelete) { Text("events.menu.delete") }
                        }
                    } label: {
                        Image(systemName: "ellipsis").foregroundStyle(Color.DS.textPrimary).frame(width: Sizes.touchMin, height: Sizes.touchMin)
                    }
                    .accessibilityLabel(Text("events.menu"))
                }
                .padding(Spacing.s1)
            }
            .frame(height: 88)
            VStack(alignment: .leading, spacing: Spacing.s0_5) {
                Text(LocalizedStringKey(event.type.labelKey)).devetFont(DevetType.caption).foregroundStyle(Color.DS.brandPrimary)
                    .padding(.horizontal, Spacing.s1).padding(.vertical, Spacing.s0_5).background(Capsule().fill(Color.DS.brandSubtle))
                Text(event.titleNames).devetFont(DevetType.serifTitle).foregroundStyle(Color.DS.textPrimary)
                Text("\(formatEventDate(event.startsAt)) · \(event.venueName)").devetFont(DevetType.footnote).foregroundStyle(Color.DS.textSecondary)
                Text("\(plural("events.stat.coming", event.comingPeople)) · \(plural("events.stat.no_answer", event.noAnswer))")
                    .devetFont(DevetType.footnote).foregroundStyle(Color.DS.textPrimary)
            }
            .padding(Spacing.s2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.DS.bgSurface))
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("event_\(event.id)")
    }
}

private struct EmptyEvents: View {
    let onCreate: () -> Void
    let onJoin: () -> Void

    var body: some View {
        VStack(spacing: Spacing.s1_5) {
            EnvelopeArt().stroke(Color.DS.accentGold, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                .frame(width: 160, height: 124).accessibilityHidden(true)
            Text("events.empty.title").devetFont(DevetType.serifHeadline).foregroundStyle(Color.DS.textPrimary).multilineTextAlignment(.center)
            Text("events.empty.body").devetFont(DevetType.body).foregroundStyle(Color.DS.textSecondary).multilineTextAlignment(.center)
            PrimaryButton(title: "events.empty.create", action: onCreate).padding(.top, Spacing.s2)
            LinkButton(title: "events.join", action: onJoin)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.s8)
        .accessibilityIdentifier("emptyEvents")
    }
}
