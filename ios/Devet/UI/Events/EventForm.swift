import SwiftUI

// Form blocks shared by the create wizard and the edit page (screens.md §3). Same rules as Android EventForm.

/// Locale of the language the UI shows (per-app language may differ from the region).
var uiLocale: Locale { Locale(identifier: Bundle.main.preferredLocalizations.first ?? "az") }

/// "3 avqust 2027, 17:00" in Baku time, month names in the UI language.
func formatEventDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = uiLocale
    f.timeZone = EventRules.zone
    f.dateFormat = "d MMMM yyyy, HH:mm"
    return f.string(from: date)
}

/// Plural catalog string with one count (`{count}` → `%lld`).
func plural(_ key: String, _ count: Int) -> String {
    String.localizedStringWithFormat(NSLocalizedString(key, comment: ""), count)
}

/// Large selectable card with a check mark (event type, language).
struct ChoiceCard: View {
    let title: Text
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                title.devetFont(DevetType.headline).foregroundStyle(Color.DS.textPrimary)
                Spacer()
                if selected { Image(systemName: "checkmark").foregroundStyle(Color.DS.brandPrimary) }
            }
            .padding(.horizontal, Spacing.s2)
            .frame(minHeight: 60)
            .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(selected ? Color.DS.brandSubtle : Color.DS.bgSurface))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(selected ? Color.DS.brandPrimary : Color.DS.borderHairline, lineWidth: selected ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

struct TypeChoices: View {
    let selected: EventType?
    let onSelect: (EventType) -> Void

    var body: some View {
        VStack(spacing: Spacing.s1_5) {
            ForEach(EventType.allCases) { t in
                ChoiceCard(title: Text(LocalizedStringKey(t.labelKey)), selected: selected == t) { onSelect(t) }
                    .accessibilityIdentifier("type_\(t.rawValue)")
            }
        }
    }
}

struct NamesFields: View {
    @Binding var draft: EventDraft
    let showRequired: Bool

    var body: some View {
        let missing = showRequired && draft.titleNames.trimmed.isEmpty
        VStack(spacing: Spacing.s2) {
            DevetTextField(
                label: "create.names", icon: DevetIcon.user, text: limited(\.titleNames, EventRules.maxTitle),
                isError: missing, supporting: missing ? "create.names_required" : "create.names_hint"
            )
            DevetTextField(label: "create.parents", icon: DevetIcon.user, text: limited(\.hostNames, EventRules.maxHosts), supporting: "create.parents_help")
        }
    }

    private func limited(_ path: WritableKeyPath<EventDraft, String>, _ max: Int) -> Binding<String> {
        Binding(get: { draft[keyPath: path] }, set: { draft[keyPath: path] = String($0.prefix(max)) })
    }
}

/// Date + time in Baku time; days before today cannot be picked (§15.4). Like Android, the date starts empty
/// and has to be chosen.
struct DateTimeFields: View {
    @Binding var startsAt: Date?
    let now: Date
    let showPastHint: Bool

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = EventRules.zone
        return c
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            if let value = startsAt {
                let binding = Binding(get: { value }, set: { startsAt = $0 })
                Text("create.date").devetFont(DevetType.footnote).foregroundStyle(Color.DS.textSecondary)
                DatePicker("", selection: binding, in: calendar.startOfDay(for: now)..., displayedComponents: .date)
                    .datePickerStyle(.graphical).labelsHidden().tint(Color.DS.brandPrimary)
                    .environment(\.timeZone, EventRules.zone).environment(\.locale, uiLocale)
                    .padding(Spacing.s1)
                    .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.DS.bgSurface))
                HStack {
                    Text("create.time").devetFont(DevetType.body).foregroundStyle(Color.DS.textPrimary)
                    Spacer()
                    DatePicker("", selection: binding, displayedComponents: .hourAndMinute).labelsHidden()
                        .environment(\.timeZone, EventRules.zone).environment(\.locale, Locale(identifier: "en_GB"))
                }
                .padding(.horizontal, Spacing.s2)
                .frame(minHeight: Sizes.controlHeight)
                .background(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).fill(Color.DS.bgSunken))
            } else {
                Text("create.date").devetFont(DevetType.footnote).foregroundStyle(Color.DS.textSecondary)
                Button {
                    // Tomorrow 18:00 Baku as the starting point of the picker.
                    let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
                    startsAt = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow)
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: DevetIcon.chevronRight).foregroundStyle(Color.DS.textSecondary)
                    }
                    .padding(.horizontal, Spacing.s2)
                    .frame(minHeight: Sizes.controlHeight)
                    .background(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).fill(Color.DS.bgSunken))
                    .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).stroke(Color.DS.borderControl, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("create.date"))
                .accessibilityIdentifier("date")
            }
            if showPastHint {
                Text("create.past_hint").devetFont(DevetType.footnote).foregroundStyle(Color.DS.feedbackDanger)
            }
        }
    }
}

struct VenueFields: View {
    @Binding var draft: EventDraft
    let showRequired: Bool

    var body: some View {
        let status = mapStatus(draft.mapsURL)
        VStack(alignment: .leading, spacing: Spacing.s2) {
            DevetTextField(
                label: "create.venue", icon: "building.2",
                text: Binding(get: { draft.venueName }, set: { draft.venueName = String($0.prefix(EventRules.maxVenue)) }),
                isError: showRequired && draft.venueName.trimmed.isEmpty
            )
            DevetTextField(label: "create.address", icon: "mappin.and.ellipse", text: $draft.venueAddress, supporting: "create.address_hint")
            DevetTextField(
                label: "create.map_link", icon: "map", text: $draft.mapsURL, keyboard: .URL, contentType: .URL,
                isError: status == .invalid, supporting: status == .invalid ? "create.map_invalid" : "create.map_help"
            )
            // System paste button: no "allow paste" prompt (iOS 16+); its label comes from the system in the UI language.
            PasteButton(payloadType: String.self) { strings in
                if let pasted = strings.first { Task { @MainActor in draft.mapsURL = pasted.trimmed } }
            }
            .tint(Color.DS.brandPrimary)
            .labelStyle(.titleAndIcon)
            .buttonBorderShape(.capsule)
            switch status {
            case .coordsFound: Strip(text: "create.coords_ok", icon: "checkmark", fg: Color.DS.feedbackSuccess, bg: Color.DS.feedbackSuccessBg)
            case .noCoords: Strip(text: "create.no_coords", icon: DevetIcon.alert, fg: Color.DS.feedbackWarning, bg: Color.DS.feedbackWarningBg)
            default: EmptyView()
            }
        }
    }
}

private struct Strip: View {
    let text: LocalizedStringKey
    let icon: String
    let fg: Color
    let bg: Color

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s1) {
            Image(systemName: icon).accessibilityHidden(true)
            Text(text).devetFont(DevetType.callout)
            Spacer(minLength: 0)
        }
        .foregroundStyle(fg)
        .padding(Spacing.s1_5)
        .background(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).fill(bg))
        .accessibilityIdentifier("mapStatus")
    }
}

struct LanguageChoices: View {
    let selected: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s1_5) {
            ForEach(SystemAppLanguage.supported, id: \.self) { lang in
                ChoiceCard(title: Text(LocalizedStringKey("lang.\(lang)")), selected: selected == lang) { onSelect(lang) }
            }
            Text("create.lang_help").devetFont(DevetType.callout).foregroundStyle(Color.DS.textSecondary)
        }
    }
}

/// Toggle + mini preview of the guest page's table block, on and off (screens.md §3 step 6).
struct TablematesToggle: View {
    @Binding var on: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Toggle(isOn: $on) {
                VStack(alignment: .leading, spacing: Spacing.s0_5) {
                    Text("create.tablemates").devetFont(DevetType.headline).foregroundStyle(Color.DS.textPrimary)
                    Text("create.tablemates_help").devetFont(DevetType.footnote).foregroundStyle(Color.DS.textSecondary)
                }
            }
            .tint(Color.DS.brandPrimary)
            .padding(Spacing.s2)
            .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.DS.bgSurface))
            .accessibilityIdentifier("tablemates")
            Text("create.preview_label").devetFont(DevetType.caption).foregroundStyle(Color.DS.textSecondary)
            VStack(spacing: Spacing.s0_5) {
                Text("create.your_table").devetFont(DevetType.footnote).foregroundStyle(Color.DS.textSecondary)
                Text(verbatim: "12").devetFont(DevetType.serifTitle).foregroundStyle(Color.DS.brandPrimary)
                Text(on ? "create.mates" : "create.mates_off").devetFont(DevetType.callout)
                    .foregroundStyle(on ? Color.DS.textPrimary : Color.DS.textSecondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.s2)
            .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.DS.bgSurface))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(Color.DS.accentGold, lineWidth: 1))
        }
    }
}
