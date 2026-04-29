import Foundation

struct NovelItem: Identifiable {
    let ncode: String
    let title: String
    let writer: String
    let story: String
    let genre: Int
    let weeklyUnique: Int
    let globalPoint: Int
    let favCount: Int
    let isComplete: Bool
    let isShort: Bool

    var id: String { ncode }

    var genreName: String {
        switch genre {
        case 101: return "異世界恋愛"
        case 102: return "異世界"
        case 201: return "現実恋愛"
        case 202: return "ハイファンタジー"
        case 301: return "純文学"
        case 302: return "ドラマ"
        case 303: return "歴史"
        case 304: return "推理"
        case 305: return "ホラー"
        case 306: return "アクション"
        case 307: return "コメディー"
        case 401: return "VRゲーム"
        case 402: return "現実世界"
        case 403: return "ハイファンタジー"
        case 404: return "ローファンタジー"
        default: return "その他"
        }
    }

    var isIsekai: Bool { genre == 101 || genre == 102 }
    var novelURL: URL { URL(string: "https://ncode.syosetu.com/\(ncode.lowercased())/")! }
}

struct AnimeItem: Identifiable {
    let id: Int
    let titleNative: String?
    let titleRomaji: String
    let coverImage: String?
    let description: String?
    let score: Int?
    let popularity: Int
    let episodes: Int?
    let season: String?
    let seasonYear: Int?

    var displayTitle: String { titleNative ?? titleRomaji }

    var seasonDisplay: String {
        guard let season, let year = seasonYear else { return "" }
        let s: String
        switch season {
        case "WINTER": s = "冬"
        case "SPRING": s = "春"
        case "SUMMER": s = "夏"
        case "FALL":   s = "秋"
        default: s = season
        }
        return "\(year)年\(s)"
    }
}

struct FavoriteNovel: Codable, Identifiable {
    let id: String
    let title: String
    let writer: String
    let ncode: String
}
