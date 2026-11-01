import SwiftUI

/// Screen 8a: "Adları yoxlayın" (screens.md §8a).
struct PreviewListView: View {
    @StateObject private var viewModel: PreviewListViewModel
    let onReady: () -> Void

    init(eventId: String, repo: any GuestListRepository, events: any EventRepository,
         storage: any StorageRepository, displayNames: DisplayNames, onReady: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: PreviewListViewModel(
            eventId: eventId, repo: repo, events: events, storage: storage, displayNames: displayNames
        ))
        self.onReady = onReady
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("guests.preview_title", tableName: "Localizable")
                .font(.system(size: 28, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.md)

            // Warnings
            if !viewModel.warnings.isEmpty {
                HStack(spacing: .sm) {
                    ForEach(viewModel.warnings) { warning in
                        let label = warning.type == "no_phone"
                            ? String(format: NSLocalizedString("guests.warning_no_phone", tableName: "Localizable", value: "Telefon yoxdur: %d", comment: ""), warning.count)
                            : String(format: NSLocalizedString("guests.warning_empty_name", tableName: "Localizable", value: "Boş ad: %d", comment: ""), warning.count)

                        Text(label)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.855, green: 0.463, blue: 0.024))
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal, .md)
                .padding(.bottom, .md)
            }

            // Loading state
            if !viewModel.allReady {
                VStack(spacing: .sm) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("guests.preview_generating", tableName: "Localizable")
                        .font(.system(size: 14))
                    Text(viewModel.uploadProgress)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .frame(maxHeight: .infinity)
                .padding()
                return
            }

            // Error state
            if let error = viewModel.uploadError {
                VStack(spacing: .md) {
                    Text("Yükləmə xətası: \(error)")
                        .foregroundColor(.red)
                    Button(action: {
                        Task {
                            await viewModel.load()
                        }
                    }) {
                        Text("guests.retry_upload", tableName: "Localizable")
                    }
                }
                .padding()
                return
            }

            // Guest list
            List(viewModel.guests) { guest in
                HStack(spacing: .md) {
                    // Thumbnail
                    if let preview = viewModel.previews[guest.code] {
                        Image(uiImage: preview.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 63)
                            .cornerRadius(4)
                    } else {
                        Color.gray.opacity(0.2)
                            .frame(width: 120, height: 63)
                            .cornerRadius(4)
                    }

                    // Name + phone
                    VStack(alignment: .leading, spacing: 4) {
                        Text(guest.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(guest.name.trimmingCharacters(in: .whitespaces).isEmpty ? .red : .primary)

                        if let phone = guest.phoneE164, !phone.isEmpty {
                            Text(phone)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        } else {
                            Text("Telefon yoxdur")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                    }

                    Spacer()
                }
            }
            .listStyle(.plain)

            // "Ready" button
            Button(action: onReady) {
                Text("guests.ready_button", tableName: "Localizable")
                    .font(.system(size: 16, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.md)
        }
        .onAppear {
            Task {
                await viewModel.load()
            }
        }
    }
}

#Preview {
    PreviewListView(
        eventId: "demo-1",
        repo: FakeGuestList(),
        events: FakeEvents(),
        storage: FakeStorageRepository(),
        displayNames: DisplayNames(salutationForms: [:]),
        onReady: {}
    )
}
