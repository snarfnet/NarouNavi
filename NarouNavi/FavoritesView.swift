import SwiftUI

private let topAdUnitID = "ca-app-pub-9404799280370656/9765382403"
private let bottomAdUnitID = "ca-app-pub-9404799280370656/7689658066"

struct FavoritesView: View {
    @State private var favorites: [FavoriteNovel] = []

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                AdBannerView(adUnitID: topAdUnitID).frame(height: 50)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        HeroImageCard(
                            imageName: "narou-hero",
                            title: "あとで読む作品リスト",
                            subtitle: "気になった小説を保存して、いつでもなろうへ戻れます。",
                            badge: "FAVORITE"
                        )

                        HStack {
                            Text("保存中")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundColor(AppTheme.text)
                            Spacer()
                            Text("\(favorites.count)件")
                                .font(.caption.bold())
                                .foregroundColor(AppTheme.gold)
                        }

                        if favorites.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(favorites) { fav in
                                    Link(destination: URL(string: "https://ncode.syosetu.com/\(fav.ncode.lowercased())/")!) {
                                        favoriteRow(fav)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 70)
                }

                AdBannerView(adUnitID: bottomAdUnitID).frame(height: 50)
            }
        }
        .onAppear { load() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle")
                .font(.system(size: 42))
                .foregroundColor(AppTheme.gold)
            Text("お気に入りはまだありません")
                .font(.headline)
                .foregroundColor(AppTheme.text)
            Text("小説詳細の星マークから追加できます。")
                .font(.caption)
                .foregroundColor(AppTheme.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 46)
        .background(AppTheme.panel.opacity(0.82), in: RoundedRectangle(cornerRadius: 20))
    }

    private func favoriteRow(_ fav: FavoriteNovel) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "book.closed.fill")
                .foregroundColor(AppTheme.gold)
                .frame(width: 42, height: 42)
                .background(AppTheme.gold.opacity(0.13), in: RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 4) {
                Text(fav.title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.text)
                    .lineLimit(2)
                Text(fav.writer)
                    .font(.caption)
                    .foregroundColor(AppTheme.subtext)
            }
            Spacer()
            Image(systemName: "arrow.up.right").foregroundColor(AppTheme.subtext)
        }
        .padding(13)
        .background(AppTheme.panel.opacity(0.86), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: "narou_favorites"),
              let items = try? JSONDecoder().decode([FavoriteNovel].self, from: data) else { return }
        favorites = items
    }
}
