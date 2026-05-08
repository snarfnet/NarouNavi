import SwiftUI

private let topAdUnitID = "ca-app-pub-9404799280370656/9765382403"
private let bottomAdUnitID = "ca-app-pub-9404799280370656/7689658066"

enum NovelOrder: String, CaseIterable {
    case weekly = "weekly", total = "hyoka", new = "new"
    var label: String {
        switch self {
        case .weekly: return "週間"
        case .total: return "総合"
        case .new: return "新着"
        }
    }
}

enum GenreFilter: Int, CaseIterable {
    case all = 0, isekai = 102, isekaiRomance = 101, highFantasy = 202, action = 306
    var label: String {
        switch self {
        case .all: return "すべて"
        case .isekai: return "異世界"
        case .isekaiRomance: return "異世界恋愛"
        case .highFantasy: return "ファンタジー"
        case .action: return "アクション"
        }
    }
}

struct NovelRankingView: View {
    @State private var novels: [NovelItem] = []
    @State private var order: NovelOrder = .weekly
    @State private var genre: GenreFilter = .all
    @State private var searchText = ""
    @State private var completeOnly = false
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var selected: NovelItem?

    private var filteredNovels: [NovelItem] {
        novels.filter { novel in
            let matchesSearch = searchText.isEmpty ||
                novel.title.localizedCaseInsensitiveContains(searchText) ||
                novel.writer.localizedCaseInsensitiveContains(searchText) ||
                novel.story.localizedCaseInsensitiveContains(searchText)
            let matchesComplete = !completeOnly || novel.isComplete
            return matchesSearch && matchesComplete
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
                            imageName: "narou-novel",
                            title: "今読みたい小説ランキング",
                            subtitle: "なろう小説をジャンル・検索・完結で探せます。",
                            badge: "NOVEL"
                        )

                        controls

                        if isLoading {
                            ProgressView().padding(.vertical, 60)
                        } else if let err = errorMsg {
                            errorView(err)
                        } else {
                            insightStrip
                            LazyVStack(spacing: 10) {
                                ForEach(Array(filteredNovels.enumerated()), id: \.element.id) { i, novel in
                                    NovelRow(rank: i + 1, novel: novel)
                                        .onTapGesture { selected = novel }
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
        .sheet(item: $selected) { NovelDetailSheet(novel: $0) }
        .onChange(of: order) { Task { await load() } }
        .onChange(of: genre) { Task { await load() } }
        .task { await load() }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Picker("", selection: $order) {
                ForEach(NovelOrder.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            SearchField(text: $searchText, placeholder: "タイトル・作者・あらすじで検索")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(GenreFilter.allCases, id: \.self) { g in
                        chip(g.label, selected: genre == g) { genre = g }
                    }
                    chip("完結のみ", selected: completeOnly) { completeOnly.toggle() }
                }
            }
        }
    }

    private var insightStrip: some View {
        HStack(spacing: 8) {
            miniStat("表示", "\(filteredNovels.count)作", AppTheme.cyan)
            miniStat("完結", "\(filteredNovels.filter { $0.isComplete }.count)作", AppTheme.gold)
            miniStat("異世界", "\(filteredNovels.filter { $0.isIsekai }.count)作", AppTheme.violet)
        }
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

    private func chip(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13, weight: .black))
                .foregroundColor(selected ? AppTheme.ink : AppTheme.subtext)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(selected ? AppTheme.gold : AppTheme.panelSoft, in: Capsule())
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark").font(.system(size: 34)).foregroundColor(AppTheme.gold)
            Text(message).foregroundColor(AppTheme.subtext)
            Button("再読み込み") { Task { await load() } }
                .font(.headline)
                .foregroundColor(AppTheme.ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(AppTheme.gold, in: Capsule())
        }
        .padding(.vertical, 50)
    }

    private func load() async {
        isLoading = true
        errorMsg = nil
        do {
            novels = try await APIService.fetchNovels(
                order: order.rawValue,
                genreFilter: genre.rawValue == 0 ? nil : genre.rawValue
            )
        } catch {
            errorMsg = "ランキングの読み込みに失敗しました。"
        }
        isLoading = false
    }
}

struct NovelRow: View {
    let rank: Int
    let novel: NovelItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(rankColor)
                .frame(width: 38, height: 42)
                .background(AppTheme.panelSoft, in: RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 7) {
                Text(novel.title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.text)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(novel.writer).font(.caption).foregroundColor(AppTheme.subtext).lineLimit(1)
                    GenreTag(name: novel.genreName)
                    if novel.isComplete { statusTag("完結", color: .green) }
                }

                Text(novel.story)
                    .font(.caption)
                    .foregroundColor(AppTheme.subtext)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Label(novel.weeklyUnique.formatted(), systemImage: "eye")
                    Label(novel.favCount.formatted(), systemImage: "bookmark.fill")
                    Label("\(novel.globalPoint.formatted())pt", systemImage: "star.fill")
                }
                .font(.caption2)
                .foregroundColor(AppTheme.gold)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundColor(AppTheme.subtext)
        }
        .padding(13)
        .background(AppTheme.panel.opacity(0.86), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
    }

    private var rankColor: Color {
        switch rank {
        case 1: return AppTheme.gold
        case 2: return AppTheme.cyan
        case 3: return AppTheme.rose
        default: return AppTheme.subtext
        }
    }

    private func statusTag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
    }
}

struct GenreTag: View {
    let name: String
    var body: some View {
        Text(name)
            .font(.caption2.bold())
            .foregroundColor(AppTheme.cyan)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppTheme.cyan.opacity(0.12), in: Capsule())
    }
}

struct StatPill: View {
    let icon: String
    let value: String
    var body: some View {
        Label(value, systemImage: icon)
            .font(.caption.bold())
            .foregroundColor(AppTheme.gold)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(AppTheme.gold.opacity(0.12), in: Capsule())
    }
}

struct NovelDetailSheet: View {
    let novel: NovelItem
    @Environment(\.dismiss) var dismiss
    @State private var isSaved = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(novel.title).font(.title2.bold()).foregroundColor(AppTheme.text)
                    HStack {
                        Text(novel.writer).foregroundColor(AppTheme.subtext)
                        Spacer()
                        GenreTag(name: novel.genreName)
                    }
                    HStack(spacing: 8) {
                        StatPill(icon: "eye", value: "\(novel.weeklyUnique.formatted())/週")
                        StatPill(icon: "star", value: "\(novel.globalPoint.formatted())pt")
                        StatPill(icon: "bookmark", value: novel.favCount.formatted())
                    }
                    Text(novel.story).foregroundColor(AppTheme.text).lineSpacing(4)
                    Link(destination: novel.novelURL) {
                        Label("なろうで読む", systemImage: "arrow.up.right")
                            .font(.headline)
                            .foregroundColor(AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.gold, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }.foregroundColor(AppTheme.gold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { toggleFavorite() } label: {
                        Image(systemName: isSaved ? "star.fill" : "star").foregroundColor(AppTheme.gold)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { checkFavorite() }
    }

    private func favorites() -> [FavoriteNovel] {
        guard let data = UserDefaults.standard.data(forKey: "narou_favorites"),
              let items = try? JSONDecoder().decode([FavoriteNovel].self, from: data) else { return [] }
        return items
    }

    private func checkFavorite() {
        isSaved = favorites().contains { $0.ncode == novel.ncode }
    }

    private func toggleFavorite() {
        var favs = favorites()
        if isSaved {
            favs.removeAll { $0.ncode == novel.ncode }
        } else {
            favs.append(FavoriteNovel(id: novel.ncode, title: novel.title, writer: novel.writer, ncode: novel.ncode))
        }
        if let data = try? JSONEncoder().encode(favs) {
            UserDefaults.standard.set(data, forKey: "narou_favorites")
        }
        isSaved.toggle()
    }
}
