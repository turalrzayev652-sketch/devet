import SwiftUI

/// Screen 8b: Qonaq-qonaq göndərmə axını (T48I).
struct SendView: View {
    @StateObject private var viewModel: SendViewModel
    @Environment(\.openURL) private var openURL
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

    private func message(for guest: Guest) -> String {
        viewModel.buildMessage(guest: guest, eventTitle: eventTitle, eventType: eventType, baseUrl: baseUrl)
    }

    private func openWhatsApp(for guest: Guest) {
        if let link = viewModel.buildWaLink(phone: guest.phoneE164 ?? "", message: message(for: guest)) {
            openURL(link)
        }
        showConfirm = true
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.state.guests.isEmpty {
                ProgressView(value: Double(viewModel.state.sentCount), total: Double(viewModel.state.guests.count))
                    .padding(Spacing.s2)
                Text("\(viewModel.state.sentCount) / \(viewModel.state.guests.count)")
                    .font(.system(size: 12)).foregroundColor(.gray)
                    .padding(.horizontal, Spacing.s2).padding(.bottom, Spacing.s2)
            }

            if viewModel.state.loading {
                ProgressView().frame(maxHeight: .infinity)
            } else if viewModel.state.allDone {
                VStack(spacing: Spacing.s2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64)).foregroundColor(.green)
                    Text("Bütün dəvətlər göndərildi")
                        .font(.headline)
                    Button("Statistikaya bax") { onComplete() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxHeight: .infinity)
                .padding()
            } else if let guest = viewModel.currentGuest() {
                ScrollView {
                    VStack(spacing: Spacing.s2) {
                        VStack(spacing: Spacing.s1) {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Text(String(guest.name.prefix(2)).uppercased())
                                        .font(.headline).foregroundColor(.white)
                                )
                            Text(guest.name).font(.headline)
                            Text(guest.phoneE164 ?? "").font(.body).foregroundColor(.gray)
                        }

                        Text(message(for: guest))
                            .font(.body)
                            .padding(Spacing.s2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(Spacing.s2)
                }

                if showConfirm {
                    VStack(spacing: Spacing.s2) {
                        Text("Göndərildi?").font(.headline)
                        Button("Bəli, növbəti") {
                            Task {
                                await viewModel.confirmSent(guest)
                                showConfirm = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Xeyr, yenidən") { openWhatsApp(for: guest) }
                    }
                    .padding()
                } else {
                    HStack(spacing: Spacing.s2) {
                        Button("Keç") { viewModel.skip() }
                            .frame(maxWidth: .infinity)
                        Button(action: { openWhatsApp(for: guest) }) {
                            Text("WhatsApp").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(Spacing.s2)
                }
            } else {
                Spacer()
            }
        }
        .task { await viewModel.load() }
    }
}
