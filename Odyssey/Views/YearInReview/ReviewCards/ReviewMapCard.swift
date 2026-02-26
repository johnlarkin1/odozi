import SwiftUI

struct ReviewMapCard: View {
    let cities: [(city: String, count: Int)]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentTeal.opacity(0.2), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "map.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentTeal)

                Text("Places You've Been")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("\(cities.count)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(cities.count == 1 ? "city" : "cities")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    ForEach(cities.prefix(5), id: \.city) { item in
                        HStack {
                            Text(item.city)
                                .font(.body.weight(.medium))
                            Spacer()
                            Text("\(item.count) days")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 40)
                    }
                }

                Spacer()
                Spacer()
            }
        }
    }
}
