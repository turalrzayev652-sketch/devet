import SwiftUI

/// Screen [9]: Statistika (spec/screens.md §9, T49I).
struct StatsView: View {
    @StateObject private var viewModel: StatsViewModel

    init(eventId: String, repo: any GuestListRepository) {
        _viewModel = StateObject(wrappedValue: StatsViewModel(eventId: eventId, repo: repo))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: .md) {
                Text("Statistika")
                    .font(.system(size: 28, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.loading {
                    ProgressView()
                        .frame(maxHeight: .infinity)
                        .padding()
                    return
                }

                // 5 stat cards
                VStack(spacing: .md) {
                    StatCard(label: "Göndərildi", value: "\(viewModel.sent)", color: .accentColor)
                    StatCard(label: "Baxdı", value: "\(viewModel.viewed)", color: .orange)
                    StatCard(label: "Gəlir", value: "\(viewModel.coming) (\(viewModel.totalPeople) nəfər)", color: .green)
                    StatCard(label: "Gəlmir", value: "\(viewModel.declined)", color: .red)
                    StatCard(label: "Cavab yoxdur", value: "\(viewModel.noAnswer)", color: .gray)
                }

                Divider().padding(.vertical, .md)

                // Funnel
                Text("Dəvətlərin yolu")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                FunnelBar(label: "Göndərildi", count: viewModel.sent, percent: 100)
                FunnelBar(label: "Baxdı", count: viewModel.viewed, percent: viewModel.sent > 0 ? (viewModel.viewed * 100) / viewModel.sent : 0)
                FunnelBar(label: "Cavab verdi", count: viewModel.coming + viewModel.declined, percent: viewModel.sent > 0 ? ((viewModel.coming + viewModel.declined) * 100) / viewModel.sent : 0)
            }
            .padding(.md)
        }
        .task { await viewModel.load() }
    }
}

struct StatCard: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: .sm) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct FunnelBar: View {
    let label: String
    let count: Int
    let percent: Int

    var body: some View {
        VStack(spacing: .xs) {
            HStack(spacing: .sm) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(maxWidth: .infinity * CGFloat(percent) / 100, alignment: .leading)
                }
                .frame(height: 24)

                Text("\(label): \(count)")
                    .font(.body)
            }
        }
    }
}

#Preview {
    StatsView(eventId: "demo-1", repo: FakeGuestList())
}
