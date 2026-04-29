import Foundation

enum APIError: Error {
    case invalidURL, decodingError, networkError(Error)
}

class APIService {
    static func fetchNovels(order: String = "weekly", genreFilter: Int? = nil) async throws -> [NovelItem] {
        var urlStr = "https://api.syosetu.com/novelapi/api/?out=json&lim=30&order=\(order)"
        if let g = genreFilter { urlStr += "&genre=\(g)" }
        guard let url = URL(string: urlStr) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.setValue("NarouNavi/1.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw APIError.decodingError
        }
        return arr.dropFirst().compactMap { d -> NovelItem? in
            guard let ncode = d["ncode"] as? String, let title = d["title"] as? String else { return nil }
            return NovelItem(
                ncode: ncode,
                title: title,
                writer: d["writer"] as? String ?? "",
                story: d["story"] as? String ?? "",
                genre: d["genre"] as? Int ?? 0,
                weeklyUnique: d["weekly_unique"] as? Int ?? 0,
                globalPoint: d["global_point"] as? Int ?? 0,
                favCount: d["fav_novel_cnt"] as? Int ?? 0,
                isComplete: (d["end"] as? Int ?? 0) == 1,
                isShort: (d["noveltype"] as? Int ?? 1) == 2
            )
        }
    }

    static func fetchIsekaiAnime() async throws -> [AnimeItem] {
        let query = """
        { Page(page:1,perPage:30){
            media(type:ANIME,tag:"Isekai",sort:POPULARITY_DESC,format_in:[TV],startDate_greater:20091231){
              id title{native romaji} coverImage{medium}
              description(asHtml:false) averageScore popularity episodes season seasonYear
            }
          }
        }
        """
        guard let url = URL(string: "https://graphql.anilist.co") else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["query": query])
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode == 429 {
            return []
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingError
        }
        // AniList returns errors field on failure — treat as empty result
        guard let dataObj = json["data"] as? [String: Any],
              let page = dataObj["Page"] as? [String: Any],
              let media = page["media"] as? [[String: Any]] else { return [] }
        return media.compactMap { d -> AnimeItem? in
            guard let id = d["id"] as? Int else { return nil }
            let t = d["title"] as? [String: Any]
            let c = d["coverImage"] as? [String: Any]
            return AnimeItem(
                id: id,
                titleNative: t?["native"] as? String,
                titleRomaji: t?["romaji"] as? String ?? "",
                coverImage: c?["medium"] as? String,
                description: d["description"] as? String,
                score: d["averageScore"] as? Int,
                popularity: d["popularity"] as? Int ?? 0,
                episodes: d["episodes"] as? Int,
                season: d["season"] as? String,
                seasonYear: d["seasonYear"] as? Int
            )
        }
    }
}
