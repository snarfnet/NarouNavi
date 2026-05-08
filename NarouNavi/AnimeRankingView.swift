import SwiftUI
import Translation

private let topAdUnitID = "ca-app-pub-9404799280370656/9765382403"
private let bottomAdUnitID = "ca-app-pub-9404799280370656/7689658066"

struct AnimeRankingView: View {
    @State private var animes: [AnimeItem] = []
    @State private var translatedDesc: [Int: String] = [:]
    @State private var searchText = ""
    @State private var highScoreOnly = false
    @State private var isLoading = false
    @State private var isTranslating = false
    @State private var selected: AnimeItem?
    @State private var translationConfig: TranslationSession.Configuration?

    private var filteredAnimes: [AnimeItem] {
        animes.filter { anime in
            let matchesSearch = searchText.isEmpty ||
                anime.displayTitle.localizedCaseInsensitiveContains(searchText) ||
                anime.titleRomaji.localizedCaseInsensitiveContains(searchText)
            let matchesScore = !highScoreOnly || (anime.score ?? 0) >= 75
            return matchesSearch && matchesScore
        }
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                AdBannerView(adUnitID: topAdUnitID).frame(height: 50)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        HeroImageCard(
                            imageName: "narou-anime",
                            title: "異世界アニメランキング",
                            subtitle: "人気度・評価・話数を見ながら次に観る作品を選べます。",
                            badge: "ANIME"
                        )

                        SearchField(text: $searchText, placeholder: "アニメ名で検索")

                        HStack(spacing: 8) {
                            miniStat("表示", "\(filteredAnimes.count)本", AppTheme.cyan)
                            miniStat("高評価", "\(animes.filter { ($0.score ?? 0) >= 75 }.count)本", AppTheme.gold)
                            Button {
                                highScoreOnly.toggle()
                            } label: {
                                Text(highScoreOnly ? "高評価のみ" : "すべて表示")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundColor(highScoreOnly ? AppTheme.ink : AppTheme.subtext)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(highScoreOnly ? AppTheme.gold : AppTheme.panel, in: RoundedRectangle(cornerRadius: 16))
                            }
                        }

                        if isTranslating {
                            Label("説明文を翻訳中", systemImage: "text.bubble")
                                .font(.caption.bold())
                                .foregroundColor(AppTheme.subtext)
                        }

                        if isLoading {
                            ProgressView().padding(.vertical, 60)
                        } else if animes.isEmpty {
                            emptyView
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredAnimes) { anime in
                                    AnimeCard(anime: anime, translated: translatedDesc[anime.id])
                                        .onTapGesture { selected = anime }
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
        .sheet(item: $selected) { anime in
            AnimeDetailSheet(anime: anime, translated: translatedDesc[anime.id])
        }
        #if !targetEnvironment(simulator)
        .translationTask(translationConfig) { session in
            await runTranslation(session: session)
        }
        #endif
        .task { await load() }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tv.slash")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.subtext)
            Text("アニメ情報を取得できませんでした。")
                .foregroundColor(AppTheme.subtext)
            Button("再読み込み") { Task { await load() } }
                .font(.headline)
                .foregroundColor(AppTheme.ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(AppTheme.gold, in: Capsule())
        }
        .padding(.vertical, 50)
    }

    private func miniStat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 18, weight: .black, design: .rounded)).foregroundColor(color)
            Text(title).font(.system(size: 11, weight: .bold)).foregroundColor(AppTheme.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.panel.opacity(0.82), in: RoundedRectangle(cornerRadius: 16))
    }

    private func load() async {
        isLoading = true
        do {
            animes = try await APIService.fetchIsekaiAnime()
            if !animes.isEmpty {
                translationConfig = TranslationSession.Configuration(
                    source: Locale.Language(identifier: "en"),
                    target: Locale.Language(identifier: "ja")
                )
            }
        } catch {
            animes = []
        }
        isLoading = false
    }

    private func runTranslation(session: TranslationSession) async {
        isTranslating = true
        do {
            for anime in animes {
                guard let desc = anime.description, !desc.isEmpty else { continue }
                let response = try await session.translate(desc)
                translatedDesc[anime.id] = response.targetText
            }
        } catch {
            // 翻訳できない場合は英語説明のまま表示します。
        }
        isTranslating = false
    }
}

struct AnimeCard: View {
    let anime: AnimeItem
    let translated: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            poster

            VStack(alignment: .leading, spacing: 6) {
                Text(anime.displayTitle)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.text)
                    .lineLimit(2)

                if !anime.seasonDisplay.isEmpty {
                    Text(anime.seasonDisplay)
                        .font(.caption.bold())
                        .foregroundColor(AppTheme.cyan)
                }

                HStack(spacing: 8) {
                    if let score = anime.score {
                        StatPill(icon: "star.fill", value: "\(score)点")
                    }
                    if let episodes = anime.episodes {
                        StatPill(icon: "tv", value: "\(episodes)話")
                    }
                }

                if let desc = translated ?? anime.description {
                    Text(desc.replacingOccurrences(of: "<br>", with: "\n"))
                        .font(.caption)
                        .foregroundColor(AppTheme.subtext)
                        .lineLimit(2)
                }
            }

            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundColor(AppTheme.subtext)
        }
        .padding(12)
        .background(AppTheme.panel.opacity(0.86), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
    }

    private var poster: some View {
        AsyncImage(url: anime.coverImage.flatMap(URL.init(string:))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                ZStack {
                    LinearGradient(colors: [AppTheme.violet.opacity(0.35), AppTheme.cyan.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "play.tv.fill").foregroundColor(AppTheme.cyan)
                }
            }
        }
        .frame(width: 68, height: 92)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct AnimeDetailSheet: View {
    let anime: AnimeItem
    let translated: String?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 14) {
                        AnimeCard(anime: anime, translated: nil).posterForDetail
                        VStack(alignment: .leading, spacing: 8) {
                            Text(anime.displayTitle).font(.title2.bold()).foregroundColor(AppTheme.text)
                            if !anime.seasonDisplay.isEmpty {
                                Text(anime.seasonDisplay).foregroundColor(AppTheme.cyan)
                            }
                            HStack(spacing: 8) {
                                if let score = anime.score { StatPill(icon: "star.fill", value: "\(score)点") }
                                if let ep = anime.episodes { StatPill(icon: "tv", value: "\(ep)話") }
                            }
                        }
                    }
                    if let desc = translated ?? anime.description {
                        Text(desc.replacingOccurrences(of: "<br>", with: "\n"))
                            .foregroundColor(AppTheme.text)
                            .lineSpacing(4)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }.foregroundColor(AppTheme.gold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private extension AnimeCard {
    var posterForDetail: some View {
        AsyncImage(url: anime.coverImage.flatMap(URL.init(string:))) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFill()
            default: AppTheme.panelSoft
            }
        }
        .frame(width: 96, height: 132)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
