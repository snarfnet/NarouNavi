import SwiftUI
import Translation

private let topAdUnitID    = "ca-app-pub-9404799280370656/9765382403"
private let bottomAdUnitID = "ca-app-pub-9404799280370656/7689658066"

struct AnimeRankingView: View {
    @State private var animes: [AnimeItem] = []
    @State private var translatedDesc: [Int: String] = [:]
    @State private var isLoading = false
    @State private var isTranslating = false
    @State private var selected: AnimeItem?
    @State private var translationConfig: TranslationSession.Configuration?

    let columns = [GridItem(.flexible())]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                AdBannerView(adUnitID: topAdUnitID).frame(height: 50)

                HStack {
                    Text("異世界アニメ")
                        .font(.title3.bold()).foregroundColor(.primary)
                    Spacer()
                    if isTranslating {
                        HStack(spacing: 4) {
                            ProgressView().scaleEffect(0.7)
                            Text("翻訳中...").font(.caption2).foregroundColor(.secondary)
                        }
                    } else {
                        Text("人気順").font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)

                if isLoading {
                    Spacer(); ProgressView(); Spacer()
                } else if animes.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "tv.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("データを取得できませんでした")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button("再読み込み") { Task { await load() } }
                            .font(.subheadline)
                            .foregroundColor(.purple)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(animes) { anime in
                                AnimeCard(anime: anime, translated: translatedDesc[anime.id])
                                    .onTapGesture { selected = anime }
                            }
                        }
                        .padding(12)
                    }
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
        } catch {}
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
            // 翻訳失敗時は英語のまま表示
        }
        isTranslating = false
    }
}

struct AnimeCard: View {
    let anime: AnimeItem
    let translated: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "play.tv.fill")
                    .foregroundColor(.purple.opacity(0.7))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(anime.displayTitle)
                    .font(.subheadline.bold()).foregroundColor(.primary).lineLimit(2)
                if !anime.seasonDisplay.isEmpty {
                    Text(anime.seasonDisplay).font(.caption).foregroundColor(.secondary)
                }
                if let score = anime.score {
                    Text("★ \(score)点").font(.caption.bold()).foregroundColor(.orange)
                }
                if let desc = translated ?? anime.description {
                    Text(desc).font(.caption).foregroundColor(.secondary).lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
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
                    Text(anime.displayTitle).font(.title3.bold()).foregroundColor(.primary)
                    HStack(spacing: 10) {
                        if let score = anime.score { StatPill(icon: "star.fill", value: "\(score)点") }
                        if let ep = anime.episodes { StatPill(icon: "tv", value: "\(ep)話") }
                        StatPill(icon: "person.2", value: anime.popularity.formatted())
                    }
                    if !anime.seasonDisplay.isEmpty {
                        Text(anime.seasonDisplay).font(.subheadline).foregroundColor(.purple)
                    }
                    if let desc = translated ?? anime.description {
                        Text(desc).font(.body).foregroundColor(.primary).lineSpacing(4)
                    }
                }
                .padding(20)
            }
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }.foregroundColor(.purple)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
