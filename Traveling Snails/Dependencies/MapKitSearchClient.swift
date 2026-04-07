//
//  MapKitSearchClient.swift
//  Traveling Snails
//

import Dependencies
import Foundation
import MapKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - POI Category Mapping

enum POICategoryLabel: String, Sendable {
    case restaurant = "Restaurant"
    case cafe = "Café"
    case bakery = "Bakery"
    case brewery = "Brewery"
    case winery = "Winery"
    case distillery = "Distillery"
    case foodMarket = "Food Market"
    case unknown = ""

    init(from category: MKPointOfInterestCategory?) {
        guard let category else { self = .unknown; return }
        switch category {
        case .restaurant: self = .restaurant
        case .cafe: self = .cafe
        case .bakery: self = .bakery
        case .brewery: self = .brewery
        case .winery: self = .winery
        case .distillery: self = .distillery
        case .foodMarket: self = .foodMarket
        default: self = .unknown
        }
    }
}

// MARK: - Search Result

struct RestaurantSearchResult: Equatable, Identifiable, Sendable {
    let id: String
    var name: String
    var address: String
    var city: String
    var state: String
    var postalCode: String
    var country: String
    var phone: String
    var websiteURL: String
    var latitude: Double
    var longitude: Double
    var category: String
    var timeZoneIdentifier: String
    var priceLevel: Int

    func toRestaurantItem(collectionID: Collection.ID) -> RestaurantItem {
        RestaurantItem(
            collectionID: collectionID,
            title: name,
            cuisine: "",
            category: category,
            phone: phone,
            address: address,
            city: city,
            state: state,
            postalCode: postalCode,
            country: country,
            latitude: latitude,
            longitude: longitude,
            priceLevel: priceLevel,
            websiteURL: websiteURL,
            timeZoneIdentifier: timeZoneIdentifier,
            externalID: id
        )
    }
}

// MARK: - Client

struct MapKitSearchClient {
    var search: @Sendable (String) async throws -> [RestaurantSearchResult]
    var generateSnapshot: @Sendable (Double, Double, String) async -> Data?
    var fetchBrandImage: @Sendable (String) async -> Data?
}

extension MapKitSearchClient: DependencyKey {
    static let liveValue = MapKitSearchClient(
        search: { query in
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            // Don't restrict resultTypes or POI filter — Apple Maps' natural language
            // search handles restaurant queries well on its own. Restricting to specific
            // POI categories can miss results that Maps would otherwise find (e.g. a
            // restaurant categorized as .nightlife or with no category at all).

            let search = MKLocalSearch(request: request)
            let response = try await search.start()

            return response.mapItems.compactMap { mapItem -> RestaurantSearchResult? in
                restaurantSearchResult(from: mapItem)
            }
        },
        generateSnapshot: { latitude, longitude, title in
            await generateMapSnapshot(
                latitude: latitude,
                longitude: longitude,
                title: title
            )
        },
        fetchBrandImage: { websiteURL in
            await fetchBrandImageFromWebsite(websiteURL)
        }
    )

    static let testValue = MapKitSearchClient(
        search: { _ in [] },
        generateSnapshot: { _, _, _ in nil },
        fetchBrandImage: { _ in nil }
    )
}

// MARK: - Brand Image Fetching

private func fetchBrandImageFromWebsite(_ websiteURL: String) async -> Data? {
    guard var baseURL = URL(string: websiteURL) else { return nil }

    // Upgrade the base URL to HTTPS to avoid ATS blocks
    baseURL = upgradeToHTTPS(baseURL)

    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 5
    config.timeoutIntervalForResource = 8
    let session = URLSession(configuration: config)

    guard let (htmlData, response) = try? await session.data(from: baseURL),
          let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200,
          let html = String(data: htmlData, encoding: .utf8) else {
        return nil
    }

    // Try sources in priority order — prefer icons/logos over og:image
    // og:image is often a hero photo or random image, not a logo
    let candidates: [String?] = [
        extractLinkHref(from: html, rel: "apple-touch-icon"),
        extractLinkHref(from: html, rel: "apple-touch-icon-precomposed"),
        extractLinkHref(from: html, rel: "icon", preferLargest: true),
        extractMetaContent(from: html, property: "og:image"),
        extractLinkHref(from: html, rel: "shortcut icon"),
    ]

    // Minimum 1KB — skip tiny favicons and tracking pixels that look bad as cover art
    let minImageSize = 1024

    for candidate in candidates {
        guard let urlString = candidate, !urlString.isEmpty else { continue }

        // Resolve relative URLs against the base
        guard var imageURL = URL(string: urlString, relativeTo: baseURL) else { continue }

        // Upgrade http to https to avoid ATS blocks
        imageURL = upgradeToHTTPS(imageURL)

        if let data = await downloadImage(from: imageURL, session: session, minSize: minImageSize) {
            return data
        }
    }

    // Last resort: apple-touch-icon.png (common convention, often 180x180)
    let touchIconURL = baseURL.appendingPathComponent("apple-touch-icon.png")
    if let data = await downloadImage(from: touchIconURL, session: session, minSize: minImageSize) {
        return data
    }

    return nil
}

/// Upgrade http:// URLs to https:// to avoid App Transport Security blocks
private func upgradeToHTTPS(_ url: URL) -> URL {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return url }
    if components.scheme == "http" {
        components.scheme = "https"
        return components.url ?? url
    }
    return url
}

private func downloadImage(from url: URL, session: URLSession, minSize: Int) async -> Data? {
    guard let (data, response) = try? await session.data(from: url),
          let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200,
          data.count >= minSize else {
        return nil
    }

    // Verify it's actually an image by checking the content type or data magic bytes
    let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
    let isImage = contentType.contains("image") || isImageData(data)
    guard isImage else { return nil }

    return data
}

private func isImageData(_ data: Data) -> Bool {
    guard data.count >= 4 else { return false }
    let bytes = [UInt8](data.prefix(4))

    // PNG: 89 50 4E 47
    if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 { return true }
    // JPEG: FF D8 FF
    if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF { return true }
    // GIF: 47 49 46
    if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 { return true }
    // ICO: 00 00 01 00
    if bytes[0] == 0x00 && bytes[1] == 0x00 && bytes[2] == 0x01 && bytes[3] == 0x00 { return true }
    // WEBP: starts with RIFF
    if bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 { return true }
    // SVG: starts with < (XML)
    if bytes[0] == 0x3C { return true }

    return false
}

private func extractMetaContent(from html: String, property: String) -> String? {
    // Match <meta property="og:image" content="..."> or <meta name="og:image" content="...">
    let patterns = [
        "meta[^>]*property\\s*=\\s*[\"']\(property)[\"'][^>]*content\\s*=\\s*[\"']([^\"']+)[\"']",
        "meta[^>]*content\\s*=\\s*[\"']([^\"']+)[\"'][^>]*property\\s*=\\s*[\"']\(property)[\"']",
    ]

    for pattern in patterns {
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            return String(html[range])
        }
    }
    return nil
}

private func extractLinkHref(from html: String, rel: String, preferLargest: Bool = false) -> String? {
    // Match <link rel="icon" href="..." sizes="...">
    let pattern = "link[^>]*rel\\s*=\\s*[\"']\(rel)[\"'][^>]*href\\s*=\\s*[\"']([^\"']+)[\"']"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }

    let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
    if matches.isEmpty { return nil }

    if preferLargest && matches.count > 1 {
        // Try to find the largest icon by parsing sizes attribute
        var best: (url: String, size: Int) = ("", 0)
        for match in matches {
            guard let hrefRange = Range(match.range(at: 1), in: html) else { continue }
            let href = String(html[hrefRange])
            let fullTag = String(html[Range(match.range, in: html)!])

            // Extract sizes like "180x180", "32x32"
            var size = 0
            if let sizeRegex = try? NSRegularExpression(pattern: "sizes\\s*=\\s*[\"'](\\d+)x\\d+[\"']", options: .caseInsensitive),
               let sizeMatch = sizeRegex.firstMatch(in: fullTag, range: NSRange(fullTag.startIndex..., in: fullTag)),
               let sizeRange = Range(sizeMatch.range(at: 1), in: fullTag) {
                size = Int(fullTag[sizeRange]) ?? 0
            }

            if size > best.size {
                best = (href, size)
            }
        }
        if !best.url.isEmpty { return best.url }
    }

    // Return first match
    guard let range = Range(matches[0].range(at: 1), in: html) else { return nil }
    return String(html[range])
}

// MARK: - MKMapItem → RestaurantSearchResult

private func restaurantSearchResult(from mapItem: MKMapItem) -> RestaurantSearchResult? {
    guard let name = mapItem.name, !name.isEmpty else { return nil }

    let coordinate: CLLocationCoordinate2D
    let address: String
    let city: String
    let state: String
    let postalCode: String
    let country: String

    if #available(iOS 26.0, macOS 26.0, *) {
        coordinate = mapItem.location.coordinate
        let reps = mapItem.addressRepresentations
        address = reps?.fullAddress(includingRegion: false, singleLine: true) ?? ""
        city = reps?.cityName ?? ""
        country = reps?.regionName ?? ""
        // MKAddressRepresentations doesn't expose state/postalCode as
        // structured fields yet. Parse from the full address if we can,
        // otherwise leave empty — these are optional display fields.
        state = ""
        postalCode = ""
    } else {
        let placemark = mapItem.placemark
        coordinate = placemark.coordinate

        let streetParts = [
            placemark.subThoroughfare,
            placemark.thoroughfare,
        ].compactMap { $0 }
        let streetAddress = streetParts.joined(separator: " ")
        let fullParts = [
            streetAddress.isEmpty ? nil : streetAddress,
            placemark.locality,
            placemark.administrativeArea,
        ].compactMap { $0 }
        address = fullParts.joined(separator: ", ")
        city = placemark.locality ?? ""
        state = placemark.administrativeArea ?? ""
        postalCode = placemark.postalCode ?? ""
        country = placemark.country ?? ""
    }

    let stableID: String
    if let identifier = mapItem.identifier {
        stableID = identifier.rawValue
    } else {
        stableID = "\(name)-\(coordinate.latitude)-\(coordinate.longitude)"
    }

    let categoryLabel = POICategoryLabel(from: mapItem.pointOfInterestCategory)

    return RestaurantSearchResult(
        id: stableID,
        name: name,
        address: address,
        city: city,
        state: state,
        postalCode: postalCode,
        country: country,
        phone: mapItem.phoneNumber ?? "",
        websiteURL: mapItem.url?.absoluteString ?? "",
        latitude: coordinate.latitude,
        longitude: coordinate.longitude,
        category: categoryLabel.rawValue,
        timeZoneIdentifier: mapItem.timeZone?.identifier ?? "",
        priceLevel: 0
    )
}

// MARK: - Map Snapshot Generation

private func generateMapSnapshot(
    latitude: Double,
    longitude: Double,
    title: String
) async -> Data? {
    let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    let region = MKCoordinateRegion(
        center: coordinate,
        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
    )

    let options = MKMapSnapshotter.Options()
    options.region = region
    options.size = CGSize(width: 400, height: 300)
    options.mapType = .standard
    options.showsBuildings = true
    options.pointOfInterestFilter = .includingAll

    let snapshotter = MKMapSnapshotter(options: options)

    do {
        let snapshot = try await snapshotter.start()
        // Drawing must happen on the main actor (UIKit/AppKit requirement)
        let data = await MainActor.run {
            drawAnnotatedSnapshot(snapshot: snapshot, coordinate: coordinate)
        }
        if data == nil {
            Logger.shared.error("Map snapshot drawing returned nil for (\(latitude), \(longitude))", category: .network)
        }
        return data
    } catch {
        Logger.shared.error("Map snapshot failed for (\(latitude), \(longitude)): \(error)", category: .network)
        return nil
    }
}

@MainActor
private func drawAnnotatedSnapshot(
    snapshot: MKMapSnapshotter.Snapshot,
    coordinate: CLLocationCoordinate2D
) -> Data? {
    let image = snapshot.image
    let pinPoint = snapshot.point(for: coordinate)

    #if os(iOS)
    UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale)
    image.draw(at: .zero)

    let pinSize: CGFloat = 24
    let pinRect = CGRect(
        x: pinPoint.x - pinSize / 2,
        y: pinPoint.y - pinSize,
        width: pinSize,
        height: pinSize
    )
    let path = UIBezierPath(ovalIn: pinRect)
    UIColor.systemTeal.setFill()
    path.fill()
    UIColor.white.setStroke()
    path.lineWidth = 2
    path.stroke()

    let iconConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
    if let icon = UIImage(systemName: "fork.knife", withConfiguration: iconConfig)?
        .withTintColor(.white, renderingMode: .alwaysOriginal) {
        let iconSize = icon.size
        let iconRect = CGRect(
            x: pinRect.midX - iconSize.width / 2,
            y: pinRect.midY - iconSize.height / 2,
            width: iconSize.width,
            height: iconSize.height
        )
        icon.draw(in: iconRect)
    }

    let annotatedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return annotatedImage?.jpegData(compressionQuality: 0.8)

    #elseif os(macOS)
    let annotatedImage = NSImage(size: image.size, flipped: false) { rect in
        image.draw(in: rect)

        let pinSize: CGFloat = 24
        let flippedY = rect.height - pinPoint.y
        let pinRect = NSRect(
            x: pinPoint.x - pinSize / 2,
            y: flippedY - pinSize,
            width: pinSize,
            height: pinSize
        )
        let path = NSBezierPath(ovalIn: pinRect)
        NSColor.systemTeal.setFill()
        path.fill()
        NSColor.white.setStroke()
        path.lineWidth = 2
        path.stroke()

        let iconConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        if let icon = NSImage(systemSymbolName: "fork.knife", accessibilityDescription: nil)?
            .withSymbolConfiguration(iconConfig) {
            let iconSize = icon.size
            let iconRect = NSRect(
                x: pinRect.midX - iconSize.width / 2,
                y: pinRect.midY - iconSize.height / 2,
                width: iconSize.width,
                height: iconSize.height
            )
            let tinted = NSImage(size: iconSize, flipped: false) { tintRect in
                icon.draw(in: tintRect)
                NSColor.white.set()
                tintRect.fill(using: .sourceAtop)
                return true
            }
            tinted.draw(in: iconRect)
        }

        return true
    }

    guard let tiffData = annotatedImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
        return nil
    }
    return jpegData
    #endif
}

extension DependencyValues {
    var mapKitSearchClient: MapKitSearchClient {
        get { self[MapKitSearchClient.self] }
        set { self[MapKitSearchClient.self] = newValue }
    }
}
