import SwiftUI

/// Screen 8b: Qonaq-qonaq göndərmə axını (T48I).
struct SendView: View {
    @StateObject private var viewModel: SendViewModel
    let eventTitle: String
    let eventType: String
    let baseUrl: String
    let onComplete: () -> Void

    @State private var showConfirm = false

    init(eventId: String, repo: any GuestListRepository, events: any EventRepository,
         displayNames: DisplayNames, eventTitle: String, eventType: String, baseUrl: String, onComplete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: SendViewModel(eventId: eventId, repo: repo, events: events, displayNames: displayNames))
        self.eventTitle = eventTitle
        self.eventType = eventType
        self.baseUrl = baseUrl
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            if !viewModel.state.guests.isEmpty {
                ProgressView(value: Double(viewModel.state.sentCount) / Double(viewModel.state.guests.count))
                    .padding(.md)
                Text("\(viewModel.state.sentCount) / \(viewModel.state.guests.count) göndərildi")
                    .font(.system(size: 12)).foregroundColor(.gray)
                    .padding(.horizontal, .md).padding(.bottom, .md)
            }

            if viewModel.state.allDone {
                // Completion
                VStack(spacing: .md) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64)).foregroundColor(.green)
                    Text("Bütün dəvətlər göndərildi")
                        .font(.headline)
                    Button("Statistikaya bax") { onComplete() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxHeight: .infinity)
                .padding()
                return
            }

            if let guest = viewModel.state.currentGuest() {
                ScrollView {
                    VStack(spacing: .md) {
                        // Guest card
                        VStack(spacing: .sm) {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Text(String(guest.name.prefix(2)).uppercased())
                                        .font(.headline).foregroundColor(.white)
                                )
                            Text(guest.name).font(.headline)
                            Text(guest.phoneE164 ?? "Telefon yoxdur").font(.body).foregroundColor(.gray)
                        }

                        // Message
                        Text("Mesaj:")
                            .font(.caption).foregroundColor(.gray)
                        Text(viewModel.buildMessage(guest: guest, eventTitle: eventTitle, eventType: eventType, baseUrl: baseUrl))
                            .font(.body)
                            .padding(.md)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.md)
                }

                HStack(spacing: .md) {
                    Button("Keç") { viewModel.skip() }
                        .frame(maxWidth: .infinity)

                    Button(action: { showConfirm = true }) {
                        Text("WhatsApp-da göndər")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.md)

                if let link = viewModel.buildWaLink(phone: guest.phoneE164 ?? "", message: viewModel.buildMessage(guest: guest, eventTitle: eventTitle, eventType: eventType, baseUrl: baseUrl)) {
                    Link("Linki aç", destination: link)
                        .frame(maxWidth: .infinity)
                        .padding(.md)
                        .hidden()  // Hidden, opened by user confirmation
                }
            }

            // Confirmation sheet
            if showConfirm, let guest = viewModel.state.currentGuest() {
                VStack(spacing: .md) {
                    Text("Göndərildi?")
                        .font(.headline)

                    if let link = viewModel.buildWaLink(phone: guest.phoneE164 ?? "", message: viewModel.buildMessage(guest: guest, eventTitle: eventTitle, eventType: eventType, baseUrl: baseUrl)) {
                        Link("✓ WhatsApp-da açıldı", destination: link)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(8)
                    }

                    Button("Bəli, növbəti") {
                        Task {
                            await viewModel.confirmSent(guest)
                            showConfirm = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)

                    Button("Xeyr, yenidən") { showConfirm = false }
                        .frame(maxWidth: .infinity)
                }
                .padding()
            }
        }
        .task { await viewModel.load() }
    }
}
