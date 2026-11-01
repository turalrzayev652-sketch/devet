import Foundation

/// Screen 8a: Göndərmədən əvvəl adları yoxlayın (T47I).
/// Hər qonaq üçün preview şəkli yaradır və yükləyir.

struct PreviewWarning: Identifiable {
    let type: String  // "no_phone", "empty_name"
    let count: Int
    var id: String { "\(type)-\(count)" }
}

@MainActor
final class PreviewListViewModel: ObservableObject {
    @Published private(set) var guests: [Guest] = []
    @Published private(set) var previews: [String: PreviewImage] = [:]
    @Published private(set) var warnings: [PreviewWarning] = []
    @Published private(set) var uploadProgress = ""
    @Published private(set) var uploadError: AuthFailure?
    @Published private(set) var loading = false
    @Published private(set) var allReady = false

    private let eventId: String
    private let repo: any GuestListRepository
    private let events: any EventRepository
    private let storage: any StorageRepository
    private let displayNames: DisplayNames
    private let generator = PreviewImageGenerator()

    init(eventId: String, repo: any GuestListRepository, events: any EventRepository,
         storage: any StorageRepository, displayNames: DisplayNames) {
        self.eventId = eventId
        self.repo = repo
        self.events = events
        self.storage = storage
        self.displayNames = displayNames
    }

    func load() async {
        loading = true

        // Load guests
        let guestResult = await repo.list(eventId)
        guard case let .success(allGuests) = guestResult else {
            if case let .failure(error) = guestResult {
                uploadError = error
            }
            loading = false
            return
        }

        // Filter to those with phones
        guests = allGuests.filter { !($0.phoneE164?.isEmpty ?? true) }
        let noPhone = allGuests.count - guests.count
        if noPhone > 0 { warnings = [PreviewWarning(type: "no_phone", count: noPhone)] }

        // Load event for customization
        let eventResult = await events.get(eventId)
        guard case let .success(event) = eventResult else {
            if case let .failure(error) = eventResult {
                uploadError = error
            }
            loading = false
            return
        }

        loading = false
        await generateAndUploadPreviews(event: event)
    }

    private func generateAndUploadPreviews(event: EventDraft) async {
        var previewsMap: [String: PreviewImage] = [:]
        var warningsList: [PreviewWarning] = []

        for (idx, guest) in guests.enumerated() {
            uploadProgress = "\(idx) / \(guests.count)"

            if guest.name.trimmingCharacters(in: .whitespaces).isEmpty {
                warningsList.append(PreviewWarning(type: "empty_name", count: 1))
                continue
            }

            // Generate preview
            let displayName = displayNames.displayName(guest.name, guest.salutation, withFamily: guest.withFamily, lang: guest.lang ?? event.defaultLang)
            let params = PreviewParams(
                displayName: displayName,
                code: guest.code,
                lang: guest.lang ?? event.defaultLang,
                templateBgColor: nil
            )

            let preview = generator.generate(params: params)
            previewsMap[guest.code] = preview

            // Upload
            let uploadResult = await storage.uploadPreviewImage(preview.bytes, code: guest.code, eventId: eventId)
            if case let .failure(error) = uploadResult {
                uploadError = error
                uploadProgress = "\(idx) / \(guests.count) — xəta"
                return
            }
        }

        // Group warnings
        let groupedWarnings = Dictionary(grouping: warningsList, by: { $0.type })
            .map { type, items in PreviewWarning(type: type, count: items.count) }

        warnings = warnings.filter { $0.type == "no_phone" } + groupedWarnings
        previews = previewsMap
        uploadProgress = "\(guests.count) / \(guests.count)"
        uploadError = nil
        allReady = true
    }
}
