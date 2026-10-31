import SwiftUI

/// Screen [3] Create event: six steps, then the success screen (spec/screens.md §3).
struct CreateEventView: View {
    @StateObject var vm: CreateEventViewModel
    let onClose: () -> Void
    let onCreated: () -> Void
    let onChooseTemplate: (String) -> Void
    @State private var attempted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let id = vm.createdId {
                Created(onChooseTemplate: { onChooseTemplate(id) }, onClose: onClose)
            } else {
                wizard
            }
        }
        .background(Color.DS.bgCanvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: vm.createdId) { id in if id != nil { onCreated() } }
        .onChange(of: vm.step) { _ in attempted = false }
    }

    private var question: LocalizedStringKey {
        ["create.q1", "create.q2", "create.q3", "create.q4", "create.q5", "create.q6"].map { LocalizedStringKey($0) }[vm.step - 1]
    }

    private var wizard: some View {
        VStack(spacing: 0) {
            HStack {
                if vm.step > 1 {
                    Button(action: vm.back) {
                        Image(systemName: "chevron.left").font(.title3).foregroundStyle(Color.DS.textPrimary).frame(width: Sizes.touchMin, height: Sizes.touchMin)
                    }
                    .accessibilityLabel(Text("common.back"))
                } else {
                    Color.clear.frame(width: Sizes.touchMin, height: Sizes.touchMin)
                }
                Spacer()
                Text(localized("create.step", "\(vm.step)", "\(CreateEventViewModel.steps)"))
                    .devetFont(DevetType.footnote).foregroundStyle(Color.DS.textSecondary).accessibilityIdentifier("stepLabel")
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.title3.weight(.light)).foregroundStyle(Color.DS.textPrimary).frame(width: Sizes.touchMin, height: Sizes.touchMin)
                }
                .accessibilityLabel(Text("common.close"))
            }
            .padding(.horizontal, Spacing.s1)
            // Thin gold progress line.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.DS.borderHairline)
                    Capsule().fill(Color.DS.accentGold).frame(width: geo.size.width * CGFloat(vm.step) / CGFloat(CreateEventViewModel.steps))
                }
            }
            .frame(height: 3)
            .padding(.horizontal, Spacing.gutter)
            .animation(reduceMotion ? nil : .easeOut(duration: Motion.slow), value: vm.step)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    Text(question).devetFont(DevetType.serifHeadline).foregroundStyle(Color.DS.textPrimary)
                    switch vm.step {
                    case 1: TypeChoices(selected: vm.draft.type) { vm.draft.type = $0 }
                    case 2: NamesFields(draft: $vm.draft, showRequired: attempted)
                    case 3: DateTimeFields(startsAt: $vm.draft.startsAt, now: vm.now, showPastHint: attempted && !vm.canNext)
                    case 4: VenueFields(draft: $vm.draft, showRequired: attempted)
                    case 5: LanguageChoices(selected: vm.draft.defaultLang) { vm.draft.defaultLang = $0 }
                    default: TablematesToggle(on: $vm.draft.showTablemates)
                    }
                    if let error = vm.error {
                        ErrorBanner(message: LocalizedStringKey(NSLocalizedString("create.error", comment: "") + (error == .network ? "\n" + error.messageText : "")))
                    }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.s3)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: Spacing.s1) {
                // Stays tappable on an invalid step so a tap can show what is missing (same as Android).
                PrimaryButton(title: vm.isLast ? "create.button" : "common.next", enabled: vm.canNext || !attempted, loading: vm.creating) {
                    attempted = true
                    Task { await vm.next() }
                }
                .accessibilityIdentifier("next")
                if vm.creating { Text("create.creating").devetFont(DevetType.footnote).foregroundStyle(Color.DS.textSecondary) }
                if vm.step > 1 { LinkButton(title: "common.back", action: vm.back) }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.s2)
        }
    }
}

private struct Created: View {
    let onChooseTemplate: () -> Void
    let onClose: () -> Void
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.s1_5) {
            Spacer()
            // One-time sparkle (design.md §5); with Reduce Motion the mark is static.
            EnvelopeArt().stroke(Color.DS.accentGold, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                .frame(width: 160, height: 124)
                .scaleEffect(shown || reduceMotion ? 1 : 0.6)
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: shown)
                .accessibilityHidden(true)
            Text("create.success.title").devetFont(DevetType.serifTitle).foregroundStyle(Color.DS.textPrimary).multilineTextAlignment(.center)
            Text("create.success.body").devetFont(DevetType.body).foregroundStyle(Color.DS.textSecondary).multilineTextAlignment(.center)
            PrimaryButton(title: "create.success.choose_template", action: onChooseTemplate).padding(.top, Spacing.s2)
            LinkButton(title: "common.close", action: onClose)
            Spacer()
        }
        .padding(Spacing.gutter)
        .onAppear { shown = true }
        .accessibilityIdentifier("created")
    }
}
