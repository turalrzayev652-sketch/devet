import Foundation

/// Screen 8b: Qonaq-qonaq WhatsApp axını (T48I).
struct SendState: Equatable {
    var guests: [Guest] = []
    var currentIndex: Int = 0
    var sentCount: Int = 0
    var dailyWarning: Bool = false
    var allDone: Bool = false
    var loading: Bool = false
    var error: AuthFailure?
}

@MainActor
final class SendViewModel: ObservableObject {
    @Published private(set) var state = SendState()

    private let eventId: String
    private let repo: any GuestListRepository
    private let events: any EventRepository
    private let displayNames: DisplayNames

    init(eventId: String, repo: any GuestListRepository, events: any EventRepository, displayNames: DisplayNames) {
        self.eventId = eventId
        self.repo = repo
        self.events = events
        self.displayNames = displayNames
    }

    func load() async {
        state.loading = true

        // Load unsent guests with phones
        let result = await repo.list(eventId)
        guard case let .success(allGuests) = result else {
            state.loading = false
            state.error = (result as? AuthResult<[Guest]>)?.failure
            return
        }

        let unsent = allGuests.filter { $0.sentAt == nil && $0.phoneE164 != nil }
        state.guests = unsent
        state.allDone = unsent.isEmpty
        state.loading = false
    }

    func currentGuest() -> Guest? {
        guard state.currentIndex < state.guests.count else { return nil }
        return state.guests[state.currentIndex]
    }

    /// wa.me linki
    func buildWaLink(phone: String, message: String) -> URL? {
        let phoneClean = phone.replacingOccurrences(of: "+", with: "")
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://wa.me/\(phoneClean)?text=\(encoded)")
    }

    /// WhatsApp mesajı
    func buildMessage(guest: Guest, eventTitle: String, eventType: String, baseUrl: String) -> String {
        let displayName = displayNames.displayName(guest.name, guest.salutation, withFamily: guest.withFamily, lang: guest.lang)
        let link = "\(baseUrl)/i/\(guest.code)"

        let template: String
        switch eventType.lowercased() {
        case "wedding":
            template = "Hörmətli {display_name}! {title_names} toyuna dəvətlisiniz. Dəvətnamə: {link}"
        case "engagement":
            template = "Hörmətli {display_name}! {title_names} nişanına dəvətlisiniz. Dəvətnamə: {link}"
        case "henna":
            template = "Hörmətli {display_name}! {title_names} xınayaxdısına dəvətlisiniz. Dəvətnamə: {link}"
        case "birthday":
            template = "Hörmətli {display_name}! {title_names} ad gününə dəvətlisiniz. Dəvətnamə: {link}"
        case "jubilee":
            template = "Hörmətli {display_name}! {title_names} yubileyinə dəvətlisiniz. Dəvətnamə: {link}"
        default:
            template = "Hörmətli {display_name}! {title_names} dəvətlisiniz. Dəvətnamə: {link}"
        }

        return template
            .replacingOccurrences(of: "{display_name}", with: displayName)
            .replacingOccurrences(of: "{title_names}", with: eventTitle)
            .replacingOccurrences(of: "{link}", with: link)
    }

    func confirmSent(_ guest: Guest) async {
        let result = await repo.markSent(guest.id)
        if case .success = result {
            state.sentCount += 1
            state.currentIndex += 1
            state.allDone = state.currentIndex >= state.guests.count
        }
    }

    func skip() {
        state.currentIndex += 1
        state.allDone = state.currentIndex >= state.guests.count
    }
}
