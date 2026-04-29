import SwiftUI

private let topAdUnitID    = "ca-app-pub-9404799280370656/9765382403"
private let bottomAdUnitID = "ca-app-pub-9404799280370656/7689658066"

struct FavoritesView: View {
    @State private var favorites: [FavoriteNovel] = []

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                AdBannerView(adUnitID: topAdUnitID).frame(height: 50)

                HStack {
                    Text("お気に入り").font(.title3.bold()).foregroundColor(.primary)
                    Spacer()
                    Text("\(favorites.count)件").font(.caption).foregroundColor(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)

                if favorites.isEmpty {
                    Spacer()
                    Text("お気に入りがありません\n小説詳細の★から追加しよう")
                        .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                    Spacer()
                } else {
                    List {
                        ForEach(favorites) { fav in
                            Link(destination: URL(string: "https://ncode.syosetu.com/\(fav.ncode.lowercased())/")!) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(fav.title).font(.subheadline.bold()).foregroundColor(.primary)
                                    Text(fav.writer).font(.caption).foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { indexSet in
                            favorites.remove(atOffsets: indexSet)
                            save()
                        }
                    }
                    .listStyle(.plain)
                }

                AdBannerView(adUnitID: bottomAdUnitID).frame(height: 50)
            }
        }
        .onAppear { load() }
    }

    private func load() {
        guard let d = UserDefaults.standard.data(forKey: "narou_favorites"),
              let items = try? JSONDecoder().decode([FavoriteNovel].self, from: d) else { return }
        favorites = items
    }

    private func save() {
        if let d = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(d, forKey: "narou_favorites")
        }
    }
}
