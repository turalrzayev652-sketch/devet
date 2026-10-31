import SwiftUI

// Fields of the guest form (screens.md §6.1), used by manual add (§7a) and later by guest edit (T46).

/// One selectable segment / chip.
struct Chip: View {
    let title: Text
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            title.devetFont(DevetType.callout)
                .foregroundStyle(selected ? Color.DS.brandPrimary : Color.DS.textPrimary)
                .padding(.horizontal, Spacing.s1_5).padding(.vertical, Spacing.s1)
                .frame(minHeight: Sizes.chipHeight)
                .background(Capsule().fill(selected ? Color.DS.brandSubtle : Color.DS.bgSurface))
                .overlay(Capsule().stroke(selected ? Color.DS.brandPrimary : Color.DS.borderHairline, lineWidth: selected ? 1.5 : 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

struct FieldLabel: View {
    let key: LocalizedStringKey
    var body: some View { Text(key).devetFont(DevetType.footnote).foregroundStyle(Color.DS.textSecondary) }
}

struct ChipRow<Item: Hashable>: View {
    let label: LocalizedStringKey
    let items: [Item]
    let title: (Item) -> Text
    let selected: Item
    let onSelect: (Item) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s0_5) {
            FieldLabel(key: label)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s1) {
                    ForEach(items, id: \.self) { item in Chip(title: title(item), selected: item == selected) { onSelect(item) } }
                }
            }
        }
    }
}

/// − n + for invited people (1–50).
struct CountStepper: View {
    @Binding var value: Int

    var body: some View {
        Stepper(value: $value, in: 1...GuestRules.maxCount) {
            HStack {
                Text("guest.count").devetFont(DevetType.body).foregroundStyle(Color.DS.textPrimary)
                Spacer()
                Text("\(value)").devetFont(DevetType.headline).foregroundStyle(Color.DS.textPrimary).monospacedDigit()
            }
        }
    }
}

/// "Dəvətnamədə belə görünəcək" — greeting in the guest's language (screens.md §6.1).
struct GreetingPreview: View {
    let names: DisplayNames
    let form: GuestForm
    let eventLang: String

    var body: some View {
        if !form.name.trimmed.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.s0_5) {
                Text("guest.preview").devetFont(DevetType.caption).foregroundStyle(Color.DS.textSecondary)
                Text(names.greeting(form.name, form.salutation, withFamily: form.withFamily, lang: form.lang ?? eventLang))
                    .devetFont(DevetType.serifHeadline).foregroundStyle(Color.DS.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.s2)
            .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.DS.bgSurface))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(Color.DS.accentGold, lineWidth: 1))
        }
    }
}

struct PhoneField: View {
    @Binding var phone: String
    let issue: PhoneIssue
    let duplicateOf: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s0_5) {
            DevetTextField(
                label: "guest.phone", icon: "phone", text: $phone, keyboard: .phonePad, contentType: .telephoneNumber,
                isError: issue != .none,
                supporting: issue == .invalid ? "phone.error.invalid" : issue == .notMobile ? "phone.error.not_mobile" : LocalizedStringKey(stringLiteral: "+994")
            )
            if let duplicateOf {
                Label(localized("guest.duplicate", duplicateOf), systemImage: DevetIcon.alert)
                    .devetFont(DevetType.footnote).foregroundStyle(Color.DS.feedbackWarning)
            }
        }
    }
}
