import Foundation

/// Screen [9]: Statistika (T49I).
@MainActor
final class StatsViewModel: ObservableObject {
    @Published var sent = 0
    @Published var viewed = 0
    @Published var coming = 0
    @Published var declined = 0
    @Published var noAnswer = 0
    @Published var totalPeople = 0
    @Published var loading = false
    @Published var error: AuthFailure?

    private let eventId: String
    private let repo: any GuestListRepository

    init(eventId: String, repo: any GuestListRepository) {
        self.eventId = eventId
        self.repo = repo
    }

    func load() async {
        loading = true
        let result = await repo.list(eventId)

        guard case let .success(guests) = result else {
            error = (result as? AuthResult<[Guest]>)?.failure
            loading = false
            return
        }

        var sent = 0, viewed = 0, coming = 0, declined = 0, noAnswer = 0, totalPeople = 0

        for g in guests {
            if g.sentAt != nil { sent += 1 }
            if g.openedAt != nil { viewed += 1 }

            switch g.rsvpStatus {
            case "yes":
                coming += 1
                totalPeople += g.rsvpCount
            case "no":
                declined += 1
            case "pending":
                noAnswer += 1
            default:
                break
            }
        }

        self.sent = sent
        self.viewed = viewed
        self.coming = coming
        self.declined = declined
        self.noAnswer = noAnswer
        self.totalPeople = totalPeople
        loading = false
    }
}
