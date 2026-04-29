import SwiftUI

private let topAdUnitID    = "ca-app-pub-9404799280370656/9765382403"
private let bottomAdUnitID = "ca-app-pub-9404799280370656/7689658066"

enum NovelOrder: String, CaseIterable {
    case weekly = "weekly", total = "hyoka", new = "new"
    var label: String {
        switch self {
        case .weekly: return "週間"
        case .total:  return "総合"
        case .new:    return "新着"
        }
    }
}

enum GenreFilter: Int, CaseIterable {
    case all = 0, isekai = 102, isekaiRomance = 101, highFantasy = 202, action = 306
    var label: String {
        switch self {
        case .all:           return "全て"
        case .isekai:        return "異世界"
        case .isekaiRomance: return "異世界恋愛"
        case .highFantasy:   return "ファンタジー"
        case .action:        return "アクション"
        }
    }
}

struct NovelRankingView: View {
    @State private var novels: [NovelItem] = []
    @State private var order: NovelOrder = .weekly
    @State private var genre: GenreFilter = .all
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var selected: NovelItem?

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                AdBannerView(adUnitID: topAdUnitID).frame(height: 50)

                HStack {
                    Text("小説ランキング")
                        .font(.title3.bold()).foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 6)

                Picker("", selection: $order) {
                    ForEach(NovelOrder.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.bottom, 6)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(GenreFilter.allCases, id: \.self) { g in
                            Button(g.label) { genre = g }
                                .font(.caption.bold())
                                .foregroundColor(genre == g ? .white : .purple)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(genre == g ? Color.purple : Color.purple.opacity(0.1), in: Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 8)

                if isLoading {
                    Spacer(); ProgressView(); Spacer()
                } else if let err = errorMsg {
                    Spacer()
                    Text(err).foregroundColor(.red).font(.caption).padding()
                    Button("再試行") { Task { await load() } }.foregroundColor(.purple)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(novels.enumerated()), id: \.element.id) { i, novel in
                                NovelRow(rank: i + 1, novel: novel)
                                    .onTapGesture { selected = novel }
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                    }
                }

                AdBannerView(adUnitID: bottomAdUnitID).frame(height: 50)
            }
        }
        .sheet(item: $selected) { NovelDetailSheet(novel: $0) }
        .onChange(of: order) { Task { await load() } }
        .onChange(of: genre) { Task { await load() } }
        .task { await load() }
    }

    private func load() async {
        isLoading = true; errorMsg = nil
        do {
            novels = try await APIService.fetchNovels(
                order: order.rawValue,
                genreFilter: genre.rawValue == 0 ? nil : genre.rawValue
            )
        } catch { errorMsg = "読み込みに失敗しました" }
        isLoading = false
    }
}

struct NovelRow: View {
    let rank: Int
    let novel: NovelItem

    var rankColor: Color {
        switch rank {
        case 1: return Color(red: 0.85, green: 0.65, blue: 0.0)
        case 2: return Color(white: 0.55)
        case 3: return Color(red: 0.7, green: 0.4, blue: 0.1)
        default: return .secondary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(rank)")
                .font(.title3.bold()).foregroundColor(rankColor).frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(novel.title)
                    .font(.subheadline.bold()).foregroundColor(.primary).lineLimit(2)
                HStack(spacing: 6) {
                    Text(novel.writer).font(.caption).foregroundColor(.secondary)
                    GenreTag(name: novel.genreName)
                    if novel.isComplete {
                        Text("完結").font(.caption2).foregroundColor(.green)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(.green.opacity(0.12), in: Capsule())
                    }
                }
                Text(novel.story).font(.caption).foregroundColor(.secondary).lineLimit(2)
                HStack(spacing: 12) {
                    Label(novel.weeklyUnique.formatted(), systemImage: "eye")
                        .font(.caption2).foregroundColor(.orange)
                    Label(novel.favCount.formatted(), systemImage: "bookmark")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct GenreTag: View {
    let name: String
    var body: some View {
        Text(name)
            .font(.caption2).foregroundColor(.purple)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(.purple.opacity(0.12), in: Capsule())
    }
}

struct StatPill: View {
    let icon: String
    let value: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon); Text(value)
        }
        .font(.caption2).foregroundColor(.purple)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.purple.opacity(0.1), in: Capsule())
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
                    Text(novel.title).font(.title3.bold()).foregroundColor(.primary)
                    HStack {
                        Text(novel.writer).font(.subheadline).foregroundColor(.secondary)
                        Spacer()
                        GenreTag(name: novel.genreName)
                    }
                    HStack(spacing: 10) {
                        StatPill(icon: "eye",      value: "\(novel.weeklyUnique.formatted())/週")
                        StatPill(icon: "star",     value: "\(novel.globalPoint.formatted())pt")
                        StatPill(icon: "bookmark", value: novel.favCount.formatted())
                    }
                    Text(novel.story).font(.body).foregroundColor(.primary).lineSpacing(4)
                    Link(destination: novel.novelURL) {
                        HStack {
                            Spacer()
                            Text("なろうで読む").font(.headline).foregroundColor(.white)
                            Image(systemName: "arrow.up.right").foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .background(.purple, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(20)
            }
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }.foregroundColor(.purple)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { toggleFavorite() } label: {
                        Image(systemName: isSaved ? "star.fill" : "star").foregroundColor(.purple)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { checkFavorite() }
    }

    private func favorites() -> [FavoriteNovel] {
        guard let d = UserDefaults.standard.data(forKey: "narou_favorites"),
              let items = try? JSONDecoder().decode([FavoriteNovel].self, from: d) else { return [] }
        return items
    }
    private func checkFavorite() { isSaved = favorites().contains { $0.ncode == novel.ncode } }
    private func toggleFavorite() {
        var favs = favorites()
        if isSaved { favs.removeAll { $0.ncode == novel.ncode } }
        else { favs.append(FavoriteNovel(id: novel.ncode, title: novel.title, writer: novel.writer, ncode: novel.ncode)) }
        if let d = try? JSONEncoder().encode(favs) { UserDefaults.standard.set(d, forKey: "narou_favorites") }
        isSaved.toggle()
    }
}
