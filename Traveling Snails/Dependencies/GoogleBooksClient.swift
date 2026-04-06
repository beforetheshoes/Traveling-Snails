//
//  GoogleBooksClient.swift
//  Traveling Snails
//

import Dependencies
import Foundation

struct BookSearchResult: Equatable, Identifiable, Sendable {
    let id: String
    var title: String
    var authors: [String]
    var publisher: String
    var publishedDate: String
    var pageCount: Int
    var description: String
    var isbn: String
    var thumbnailURL: String
    var categories: [String]
    var averageRating: Double
    var language: String
    var previewLink: String
    var infoLink: String

    var authorDisplay: String {
        authors.joined(separator: ", ")
    }

    func toBookItem(collectionID: Collection.ID) -> BookItem {
        BookItem(
            collectionID: collectionID,
            title: title,
            author: authorDisplay,
            isbn: isbn,
            publisher: publisher,
            publishedDate: publishedDate,
            pageCount: pageCount,
            description: description,
            coverImageURL: thumbnailURL,
            externalID: id
        )
    }
}

struct GoogleBooksClient {
    var search: @Sendable (String) async throws -> [BookSearchResult]
    var fetchDetail: @Sendable (String) async throws -> BookSearchResult
}

extension GoogleBooksClient: DependencyKey {
    static let liveValue: GoogleBooksClient = {
        let apiKey = APIKeys.googleBooks

        if apiKey.isEmpty {
            // Fallback to Open Library when no API key
            return GoogleBooksClient(
                search: { query in
                    let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
                    let url = URL(string: "https://openlibrary.org/search.json?q=\(encoded)&limit=20&fields=key,title,author_name,first_publish_year,number_of_pages_median,publisher,isbn,cover_i")!
                    let (data, _) = try await URLSession.shared.data(from: url)
                    let response = try JSONDecoder().decode(OpenLibrarySearchResponse.self, from: data)
                    return response.docs.map { $0.toSearchResult() }
                },
                fetchDetail: { workKey in
                    let url = URL(string: "https://openlibrary.org\(workKey).json")!
                    let (data, _) = try await URLSession.shared.data(from: url)
                    let work = try JSONDecoder().decode(OpenLibraryWork.self, from: data)
                    return work.toSearchResult(key: workKey)
                }
            )
        }

        return GoogleBooksClient(
            search: { query in
                let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
                let url = URL(string: "https://www.googleapis.com/books/v1/volumes?q=\(encoded)&maxResults=20&key=\(apiKey)")!
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(GoogleBooksResponse.self, from: data)
                return (response.items ?? []).map { $0.toSearchResult() }
            },
            fetchDetail: { volumeID in
                let url = URL(string: "https://www.googleapis.com/books/v1/volumes/\(volumeID)?key=\(apiKey)")!
                let (data, _) = try await URLSession.shared.data(from: url)
                let item = try JSONDecoder().decode(GoogleBooksItem.self, from: data)
                return item.toSearchResult()
            }
        )
    }()

    static let testValue = GoogleBooksClient(
        search: { _ in [] },
        fetchDetail: { _ in
            BookSearchResult(
                id: "test", title: "Test Book", authors: ["Test Author"],
                publisher: "Test Publisher", publishedDate: "2024", pageCount: 200,
                description: "A test book", isbn: "1234567890", thumbnailURL: "",
                categories: [], averageRating: 0, language: "en",
                previewLink: "", infoLink: ""
            )
        }
    )
}

extension DependencyValues {
    var googleBooksClient: GoogleBooksClient {
        get { self[GoogleBooksClient.self] }
        set { self[GoogleBooksClient.self] = newValue }
    }
}

// MARK: - Google Books API Response Types

private struct GoogleBooksResponse: Decodable {
    let items: [GoogleBooksItem]?
}

private struct GoogleBooksItem: Decodable {
    let id: String
    let volumeInfo: VolumeInfo?

    struct VolumeInfo: Decodable {
        let title: String?
        let authors: [String]?
        let publisher: String?
        let publishedDate: String?
        let pageCount: Int?
        let description: String?
        let industryIdentifiers: [IndustryIdentifier]?
        let imageLinks: ImageLinks?
        let categories: [String]?
        let averageRating: Double?
        let language: String?
        let previewLink: String?
        let infoLink: String?
    }

    struct IndustryIdentifier: Decodable {
        let type: String?
        let identifier: String?
    }

    struct ImageLinks: Decodable {
        let smallThumbnail: String?
        let thumbnail: String?
    }

    func toSearchResult() -> BookSearchResult {
        let info = volumeInfo
        let isbn = info?.industryIdentifiers?
            .first(where: { $0.type == "ISBN_13" })?
            .identifier
            ?? info?.industryIdentifiers?.first?.identifier
            ?? ""

        let thumbnail = (info?.imageLinks?.thumbnail ?? info?.imageLinks?.smallThumbnail ?? "")
            .replacingOccurrences(of: "http://", with: "https://")

        return BookSearchResult(
            id: id,
            title: info?.title ?? "",
            authors: info?.authors ?? [],
            publisher: info?.publisher ?? "",
            publishedDate: info?.publishedDate ?? "",
            pageCount: info?.pageCount ?? 0,
            description: info?.description ?? "",
            isbn: isbn,
            thumbnailURL: thumbnail,
            categories: info?.categories ?? [],
            averageRating: info?.averageRating ?? 0,
            language: info?.language ?? "",
            previewLink: (info?.previewLink ?? "").replacingOccurrences(of: "http://", with: "https://"),
            infoLink: (info?.infoLink ?? "").replacingOccurrences(of: "http://", with: "https://")
        )
    }
}

// MARK: - Open Library API Response Types (fallback)

private struct OpenLibrarySearchResponse: Decodable {
    let docs: [OpenLibraryDoc]
}

private struct OpenLibraryDoc: Decodable {
    let key: String?
    let title: String?
    let author_name: [String]?
    let first_publish_year: Int?
    let number_of_pages_median: Int?
    let publisher: [String]?
    let isbn: [String]?
    let cover_i: Int?

    func toSearchResult() -> BookSearchResult {
        let thumbnailURL: String
        if let coverID = cover_i {
            thumbnailURL = "https://covers.openlibrary.org/b/id/\(coverID)-M.jpg"
        } else {
            thumbnailURL = ""
        }

        return BookSearchResult(
            id: key ?? UUID().uuidString,
            title: title ?? "",
            authors: author_name ?? [],
            publisher: publisher?.first ?? "",
            publishedDate: first_publish_year.map { "\($0)" } ?? "",
            pageCount: number_of_pages_median ?? 0,
            description: "",
            isbn: isbn?.first ?? "",
            thumbnailURL: thumbnailURL,
            categories: [],
            averageRating: 0,
            language: "",
            previewLink: "",
            infoLink: ""
        )
    }
}

private struct OpenLibraryWork: Decodable {
    let title: String?
    let description: OpenLibraryDescription?
    let covers: [Int]?

    struct OpenLibraryDescription: Decodable {
        let value: String?

        init(from decoder: Decoder) throws {
            if let stringValue = try? decoder.singleValueContainer().decode(String.self) {
                value = stringValue
            } else {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                value = try container.decodeIfPresent(String.self, forKey: .value)
            }
        }

        enum CodingKeys: String, CodingKey {
            case value
        }
    }

    func toSearchResult(key: String) -> BookSearchResult {
        let thumbnailURL: String
        if let coverID = covers?.first {
            thumbnailURL = "https://covers.openlibrary.org/b/id/\(coverID)-M.jpg"
        } else {
            thumbnailURL = ""
        }

        return BookSearchResult(
            id: key, title: title ?? "", authors: [], publisher: "",
            publishedDate: "", pageCount: 0, description: description?.value ?? "",
            isbn: "", thumbnailURL: thumbnailURL, categories: [],
            averageRating: 0, language: "", previewLink: "", infoLink: ""
        )
    }
}
