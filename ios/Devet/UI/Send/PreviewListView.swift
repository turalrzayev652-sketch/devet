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
            Text("Adları yoxlayın")
                .font(.system(size: 28, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.s2)

            if !viewModel.warnings.isEmpty {
                HStack(spacing: Spacing.s1) {
                    ForEach(viewModel.warnings) { warning in
                        Text("\(warning.type == "no_phone" ? "Telefon yoxdur" : "Boş ad"): \(warning.count)")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.855, green: 0.463, blue: 0.024))
                            .cornerRadius(16)
                    }
                    Spacer()
                }
                .padding(.horizontal, Spacing.s2)
                .padding(.bottom, Spacing.s2)
            }

            if let error = viewModel.uploadError {
                VStack(spacing: Spacing.s2) {
                    Text("Yükləmə xətası: \(String(describing: error))")
                        .foregroundColor(.red)
                    Button("Yenidən cəhd et") { Task { await viewModel.load() } }
                }
                .frame(maxHeight: .infinity)
                .padding()
            } else if !viewModel.allReady {
                VStack(spacing: Spacing.s1) {
                    ProgressView().scaleEffect(1.5)
                    Text(viewModel.uploadProgress)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .frame(maxHeight: .infinity)
                .padding()
            } else {
                List(viewModel.guests) { guest in
                    HStack(spacing: Spacing.s2) {
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
                        VStack(alignment: .leading, spacing: 4) {
                            Text(guest.name)
                                .font(.system(size: 14, weight: .bold))
                            Text(guest.phoneE164 ?? "")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                }
                .listStyle(.plain)

                Button(action: onReady) {
                    Text("Hazırdır")
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(Spacing.s2)
            }
        }
        .task { await viewModel.load() }
    }
}

#if DEBUG
#Preview {
    PreviewListView(
        eventId: "demo-1",
        repo: DemoGuests.shared,
        events: DemoEvents(),
        storage: DemoStorageRepository(),
        displayNames: DisplayNames(forms: [:]),
        onReady: {}
    )
}
#endif
