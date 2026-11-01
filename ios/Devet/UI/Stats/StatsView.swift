import SwiftUI

/// Screen [9]: Statistika (spec/screens.md §9, T49I).
struct StatsView: View {
    @StateObject private var viewModel: StatsViewModel

    init(eventId: String, repo: any GuestListRepository) {
        _viewModel = StateObject(wrappedValue: StatsViewModel(eventId: eventId, repo: repo))
    }

    private var answered: Int { viewModel.coming + viewModel.declined }

    private func percent(_ value: Int) -> Int {
        viewModel.sent > 0 ? (value * 100) / viewModel.sent : 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.s2) {
                Text("Statistika")
                    .font(.system(size: 28, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.loading {
                    ProgressView().padding()
                } else {
                    VStack(spacing: Spacing.s2) {
                        StatCard(label: "Göndərildi", value: "\(viewModel.sent)", color: .accentColor)
                        StatCard(label: "Baxdı", value: "\(viewModel.viewed)", color: .orange)
                        StatCard(label: "Gəlir", value: "\(viewModel.coming) (\(viewModel.totalPeople))", color: .green)
                        StatCard(label: "Gəlmir", value: "\(viewModel.declined)", color: .red)
                        StatCard(label: "Cavab yoxdur", value: "\(viewModel.noAnswer)", color: .gray)
                    }

                    Divider().padding(.vertical, Spacing.s2)

                    Text("Dəvətlərin yolu")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    FunnelBar(label: "Göndərildi", count: viewModel.sent, percent: viewModel.sent > 0 ? 100 : 0)
                    FunnelBar(label: "Baxdı", count: viewModel.viewed, percent: percent(viewModel.viewed))
                    FunnelBar(label: "Cavab verdi", count: answered, percent: percent(answered))
                }
            }
            .padding(Spacing.s2)
        }
        .task { await viewModel.load() }
    }
}

struct StatCard: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.s1) {
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
        VStack(alignment: .leading, spacing: Spacing.s0_5) {
            Text("\(label): \(count)")
                .font(.body)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * CGFloat(min(max(percent, 0), 100)) / 100)
                }
            }
            .frame(height: 24)
        }
    }
}

#if DEBUG
#Preview {
    StatsView(eventId: "demo-1", repo: DemoGuests.shared)
}
#endif
