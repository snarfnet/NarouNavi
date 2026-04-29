import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NovelRankingView()
                .tabItem { Label("小説", systemImage: "book.fill") }
            AnimeRankingView()
                .tabItem { Label("アニメ", systemImage: "play.tv.fill") }
            FavoritesView()
                .tabItem { Label("お気に入り", systemImage: "star.fill") }
        }
        .tint(.purple)
    }
}
