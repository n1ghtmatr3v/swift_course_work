import Foundation
import MapKit
import Combine

struct SearchSuggestion: Identifiable, Hashable
{
    let id = UUID()
    let title: String
    let subtitle: String
    let completion: MKLocalSearchCompletion?
    let coordinate: CLLocationCoordinate2D?

    var displayText: String
    {
        subtitle.isEmpty ? title : "\(title), \(subtitle)"
    }

    static func == (lhs: SearchSuggestion, rhs: SearchSuggestion) -> Bool
    {
        lhs.title == rhs.title && lhs.subtitle == rhs.subtitle
    }

    func hash(into hasher: inout Hasher)
    {
        hasher.combine(title)
        hasher.combine(subtitle)
    }
}

@MainActor
final class SearchAddress: NSObject, ObservableObject, MKLocalSearchCompleterDelegate
{
    @Published var startResults: [SearchSuggestion] = []
    @Published var endResults: [SearchSuggestion] = []

    private let startCompleter = MKLocalSearchCompleter()
    private let endCompleter = MKLocalSearchCompleter()

    private var currentStartQuery = ""
    private var currentEndQuery = ""

    private var startFallbackTask: Task<Void, Never>?
    private var endFallbackTask: Task<Void, Never>?

    override init()
    {
        super.init()

        configure(startCompleter)
        configure(endCompleter)

        startCompleter.delegate = self
        endCompleter.delegate = self
    }

    func updateStartQuery(_ text: String)
    {
        updateQuery(text, field: .start)
    }

    func updateEndQuery(_ text: String)
    {
        updateQuery(text, field: .end)
    }

    func clearStartResults()
    {
        startFallbackTask?.cancel()
        currentStartQuery = ""
        startResults = []
        startCompleter.queryFragment = ""
    }

    func clearEndResults()
    {
        endFallbackTask?.cancel()
        currentEndQuery = ""
        endResults = []
        endCompleter.queryFragment = ""
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter)
    {
        let field: SearchField
        let query: String

        if completer === startCompleter {
            field = .start
            query = currentStartQuery
        } else {
            field = .end
            query = currentEndQuery
        }

        let suggestions = Self.rankAndDeduplicate(
            completer.results.map {
                SearchSuggestion(
                    title: $0.title,
                    subtitle: $0.subtitle,
                    completion: $0,
                    coordinate: nil
                )
            },
            query: query
        )

        setResults(suggestions, for: field)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error)
    {
        if completer === startCompleter {
            startResults = []
        } else if completer === endCompleter {
            endResults = []
        }
    }

    func resolveSuggestion(_ suggestion: SearchSuggestion) async -> CLLocationCoordinate2D?
    {
        if let coordinate = suggestion.coordinate {
            return coordinate
        }

        if let completion = suggestion.completion {
            let request = MKLocalSearch.Request(completion: completion)
            request.region = Self.searchRegion()
            request.resultTypes = Self.resultTypes(for: suggestion.displayText)

            do {
                let response = try await MKLocalSearch(request: request).start()

                if let coordinate = Self.bestCoordinate(
                    from: response.mapItems,
                    query: suggestion.displayText
                ) {
                    return coordinate
                }
            } catch {
            }
        }

        return await searchCoordinate(for: suggestion.displayText)
    }

    func bestMatch(for text: String) async -> SearchSuggestion?
    {
        let trimmed = Self.cleanedQuery(text)

        guard trimmed.isEmpty == false else {
            return nil
        }

        return await Self.fetchFallbackSuggestions(for: trimmed).first
    }

    func searchCoordinate(for text: String) async -> CLLocationCoordinate2D?
    {
        let trimmed = Self.cleanedQuery(text)

        guard trimmed.isEmpty == false else {
            return nil
        }

        if let suggestion = await bestMatch(for: trimmed),
           let coordinate = suggestion.coordinate {
            return coordinate
        }

        return await Self.searchNominatimCoordinate(for: trimmed)
    }

    private func configure(_ completer: MKLocalSearchCompleter)
    {
        completer.region = Self.searchRegion()
        completer.resultTypes = [.address, .pointOfInterest]
        completer.regionPriority = .required
    }

    private func updateQuery(_ text: String, field: SearchField)
    {
        let trimmed = Self.cleanedQuery(text)
        let completer = completer(for: field)

        fallbackTask(for: field)?.cancel()

        switch field {
        case .start:
            currentStartQuery = trimmed
        case .end:
            currentEndQuery = trimmed
        }

        guard trimmed.count >= 2 else {
            setResults([], for: field)
            completer.queryFragment = ""
            return
        }

        completer.region = Self.searchRegion()
        completer.resultTypes = Self.completerResultTypes(for: trimmed)
        completer.queryFragment = Self.completerQuery(for: trimmed)

        scheduleFallbackSearch(for: trimmed, field: field)
    }

    private func scheduleFallbackSearch(for query: String, field: SearchField)
    {
        guard query.count >= 3 else {
            return
        }

        let task = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: Self.fallbackDelay(for: query))
            } catch {
                return
            }

            let fallback = await Self.fetchFallbackSuggestions(for: query)

            guard Task.isCancelled == false else {
                return
            }

            self?.mergeFallbackResults(fallback, field: field, query: query)
        }

        setFallbackTask(task, for: field)
    }

    private func mergeFallbackResults(
        _ fallback: [SearchSuggestion],
        field: SearchField,
        query: String
    )
    {
        guard currentQuery(for: field) == query else {
            return
        }

        let merged = Self.rankAndDeduplicate(
            results(for: field) + fallback,
            query: query
        )

        setResults(merged, for: field)
    }

    private func currentQuery(for field: SearchField) -> String
    {
        switch field {
        case .start:
            return currentStartQuery
        case .end:
            return currentEndQuery
        }
    }

    private func results(for field: SearchField) -> [SearchSuggestion]
    {
        switch field {
        case .start:
            return startResults
        case .end:
            return endResults
        }
    }

    private func setResults(_ suggestions: [SearchSuggestion], for field: SearchField)
    {
        switch field {
        case .start:
            startResults = suggestions
        case .end:
            endResults = suggestions
        }
    }

    private func completer(for field: SearchField) -> MKLocalSearchCompleter
    {
        switch field {
        case .start:
            return startCompleter
        case .end:
            return endCompleter
        }
    }

    private func fallbackTask(for field: SearchField) -> Task<Void, Never>?
    {
        switch field {
        case .start:
            return startFallbackTask
        case .end:
            return endFallbackTask
        }
    }

    private func setFallbackTask(_ task: Task<Void, Never>, for field: SearchField)
    {
        switch field {
        case .start:
            startFallbackTask = task
        case .end:
            endFallbackTask = task
        }
    }

    private enum SearchField
    {
        case start
        case end
    }

    private enum SearchIntent
    {
        case address
        case metro
        case generic
    }

    private struct SearchVariant
    {
        let text: String
        let bonus: Int
        let resultTypes: MKLocalSearch.ResultType
    }

    private struct RankedSuggestion
    {
        let suggestion: SearchSuggestion
        let score: Int
    }

    private struct NominatimItem: Decodable
    {
        let lat: String
        let lon: String
    }

    private static func fetchFallbackSuggestions(for text: String) async -> [SearchSuggestion]
    {
        let trimmed = cleanedQuery(text)

        guard trimmed.isEmpty == false else {
            return []
        }

        let variants = makeSearchQueries(from: trimmed)
        var rankedByKey: [String: RankedSuggestion] = [:]

        for variant in variants {
            if Task.isCancelled {
                break
            }

            let items = await performSearch(
                query: variant.text,
                resultTypes: variant.resultTypes
            )

            for item in items.prefix(8) {
                guard let ranked = makeRankedSuggestion(
                    from: item,
                    originalQuery: trimmed,
                    bonus: variant.bonus
                ) else {
                    continue
                }

                let key = dedupKey(for: ranked.suggestion)

                if let current = rankedByKey[key], current.score >= ranked.score {
                    continue
                }

                rankedByKey[key] = ranked
            }

            if rankedByKey.count >= 8 {
                break
            }
        }

        return rankedByKey.values
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.suggestion.title.localizedCaseInsensitiveCompare(rhs.suggestion.title) == .orderedAscending
                }

                return lhs.score > rhs.score
            }
            .prefix(8)
            .map(\.suggestion)
    }

    private static func performSearch(
        query: String,
        resultTypes: MKLocalSearch.ResultType
    ) async -> [MKMapItem]
    {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = resultTypes
        request.region = searchRegion()

        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems
        } catch {
            return []
        }
    }

    private static func makeRankedSuggestion(
        from item: MKMapItem,
        originalQuery: String,
        bonus: Int
    ) -> RankedSuggestion?
    {
        let coordinate = item.location.coordinate

        guard isInsideAllowedRect(coordinate) else {
            return nil
        }

        let display = makeDisplayParts(from: item)

        guard display.title.isEmpty == false else {
            return nil
        }

        let score = bonus + score(
            item: SearchSuggestion(
                title: display.title,
                subtitle: display.subtitle,
                completion: nil,
                coordinate: coordinate
            ),
            query: originalQuery
        )

        return RankedSuggestion(
            suggestion: SearchSuggestion(
                title: display.title,
                subtitle: display.subtitle,
                completion: nil,
                coordinate: coordinate
            ),
            score: score
        )
    }

    private static func bestCoordinate(
        from items: [MKMapItem],
        query: String
    ) -> CLLocationCoordinate2D?
    {
        let ranked = items.compactMap {
            makeRankedSuggestion(from: $0, originalQuery: query, bonus: 0)
        }
        .sorted { lhs, rhs in
            lhs.score > rhs.score
        }

        return ranked.first?.suggestion.coordinate
    }

    private static func rankAndDeduplicate(
        _ items: [SearchSuggestion],
        query: String
    ) -> [SearchSuggestion]
    {
        var unique: [SearchSuggestion] = []
        var seen = Set<String>()

        for item in items {
            let key = dedupKey(for: item)

            if seen.insert(key).inserted {
                unique.append(item)
            }
        }

        return unique
            .sorted { lhs, rhs in
                let lhsScore = score(item: lhs, query: query)
                let rhsScore = score(item: rhs, query: query)

                if lhsScore == rhsScore {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }

                return lhsScore > rhsScore
            }
            .prefix(8)
            .map { $0 }
    }

    private static func score(item: SearchSuggestion, query: String) -> Int
    {
        let normalizedQuery = normalized(query)
        let title = normalized(item.title)
        let subtitle = normalized(item.subtitle)
        let haystack = normalized(item.title + " " + item.subtitle)
        let tokens = tokenized(normalizedQuery)
        let intent = detectIntent(for: normalizedQuery)

        var value = 0

        if title == normalizedQuery {
            value += 150
        }

        if haystack == normalizedQuery {
            value += 130
        }

        if title.hasPrefix(normalizedQuery) {
            value += 90
        }

        if haystack.hasPrefix(normalizedQuery) {
            value += 70
        }

        if haystack.contains(normalizedQuery) {
            value += 50
        }

        if tokens.isEmpty == false && tokens.allSatisfy({ haystack.contains($0) }) {
            value += 36
        }

        for token in tokens {
            if title == token {
                value += 32
            }

            if title.hasPrefix(token) {
                value += 22
            }

            if title.contains(token) {
                value += 14
            }

            if subtitle.contains(token) {
                value += 10
            }

            if token.count >= 4 && levenshteinClose(token, haystackWordSource: haystack) {
                value += 5
            }
        }

        switch intent {
        case .address:
            if looksLikeAddress(title) || looksLikeAddress(subtitle) {
                value += 28
            }
            if hasHouseNumber(haystack) {
                value += 14
            }
        case .metro:
            if looksLikeMetro(title) || looksLikeMetro(subtitle) {
                value += 34
            }
        case .generic:
            if looksLikeMetro(title) {
                value += 10
            }
            if looksLikeAddress(title) {
                value += 10
            }
        }

        if subtitle.contains("москва") || title.contains("москва") {
            value += 8
        }

        return value
    }

    private static func makeDisplayParts(from item: MKMapItem) -> (title: String, subtitle: String)
    {
        let shortAddress = clean(item.address?.shortAddress)
        let fullAddress = clean(item.address?.fullAddress)
        let fullSingleLine = clean(
            item.addressRepresentations?.fullAddress(
                includingRegion: true,
                singleLine: true
            )
        )
        let cityLine = compactJoin(
            uniqueValues(
                [
                    clean(item.addressRepresentations?.cityName),
                    clean(item.addressRepresentations?.cityWithContext)
                ]
            ),
            separator: ", "
        )

        let houseLine = compactJoin(
            uniqueValues(
                [
                    shortAddress,
                    clean(item.name)
                ]
            ),
            separator: ", "
        )

        let areaLine = cityLine

        let fallbackTitle = clean(item.name)
            ?? shortAddress
            ?? fullAddress
            ?? fullSingleLine
            ?? "Без названия"

        if houseLine.isEmpty == false {
            let preferredTitle = clean(item.name) ?? shortAddress
            let title = preferredTitle == houseLine ? houseLine : (preferredTitle ?? houseLine)
            let subtitle = compactJoin(
                uniqueValues([shortAddress, areaLine, fullAddress, fullSingleLine])
                    .filter { normalized($0) != normalized(title) },
                separator: ", "
            )
            return (title, subtitle)
        }

        let subtitle = compactJoin(
            uniqueValues([areaLine, fullAddress, fullSingleLine])
                .filter { normalized($0) != normalized(fallbackTitle) },
            separator: ", "
        )

        return (fallbackTitle, subtitle)
    }

    private static func makeSearchQueries(from text: String) -> [SearchVariant]
    {
        let trimmed = cleanedQuery(text)
        let expanded = expandAddressAbbreviations(in: trimmed)
        let containsMoscow = normalized(trimmed).contains("москва")
        let types = resultTypes(for: trimmed)

        var variants: [SearchVariant] = []

        appendVariant(
            &variants,
            text: trimmed,
            bonus: 120,
            resultTypes: types
        )

        if expanded != normalized(trimmed) {
            appendVariant(
                &variants,
                text: expanded,
                bonus: 114,
                resultTypes: types
            )
        }

        for ownershipVariant in ownershipVariants(from: expanded) {
            appendVariant(
                &variants,
                text: ownershipVariant,
                bonus: 108,
                resultTypes: types
            )
        }

        for houseWordVariant in houseWordVariants(from: expanded) {
            appendVariant(
                &variants,
                text: houseWordVariant,
                bonus: 106,
                resultTypes: types
            )
        }

        for streetPrefixVariant in streetPrefixVariants(from: expanded) {
            appendVariant(
                &variants,
                text: streetPrefixVariant,
                bonus: 104,
                resultTypes: types
            )
        }

        for relaxedVariant in relaxedAddressVariants(from: expanded) {
            appendVariant(
                &variants,
                text: relaxedVariant,
                bonus: 98,
                resultTypes: types
            )
        }

        if containsMoscow == false {
            appendVariant(
                &variants,
                text: "Москва \(trimmed)",
                bonus: 100,
                resultTypes: types
            )

            if expanded != normalized(trimmed) {
                appendVariant(
                    &variants,
                    text: "Москва \(expanded)",
                    bonus: 96,
                    resultTypes: types
                )
            }

            for ownershipVariant in ownershipVariants(from: expanded) {
                appendVariant(
                    &variants,
                    text: "Москва \(ownershipVariant)",
                    bonus: 92,
                    resultTypes: types
                )
            }

            for houseWordVariant in houseWordVariants(from: expanded) {
                appendVariant(
                    &variants,
                    text: "Москва \(houseWordVariant)",
                    bonus: 91,
                    resultTypes: types
                )
            }

            for streetPrefixVariant in streetPrefixVariants(from: expanded) {
                appendVariant(
                    &variants,
                    text: "Москва \(streetPrefixVariant)",
                    bonus: 90,
                    resultTypes: types
                )
            }

            for relaxedVariant in relaxedAddressVariants(from: expanded) {
                appendVariant(
                    &variants,
                    text: "Москва \(relaxedVariant)",
                    bonus: 88,
                    resultTypes: types
                )
            }
        }

        return variants
    }

    private static func resultTypes(for query: String) -> MKLocalSearch.ResultType
    {
        switch detectIntent(for: query) {
        case .address:
            return .address
        case .metro:
            return .pointOfInterest
        case .generic:
            return [.address, .pointOfInterest]
        }
    }

    private static func completerResultTypes(for query: String) -> MKLocalSearchCompleter.ResultType
    {
        switch detectIntent(for: query) {
        case .address:
            return .address
        case .metro:
            return .pointOfInterest
        case .generic:
            return [.address, .pointOfInterest]
        }
    }

    private static func completerQuery(for text: String) -> String
    {
        let expanded = expandAddressAbbreviations(in: text)
        return cleanedQuery(expanded)
    }

    private static func detectIntent(for query: String) -> SearchIntent
    {
        let value = normalized(query)

        if looksLikeMetro(value) {
            return .metro
        }

        if looksLikeAddress(value) || hasHouseNumber(value) {
            return .address
        }

        return .generic
    }

    private static func looksLikeAddress(_ text: String) -> Bool
    {
        let markers = [
            "улица",
            "ул",
            "проспект",
            "пр-кт",
            "проезд",
            "пр-д",
            "переулок",
            "пер",
            "шоссе",
            "наб",
            "набережная",
            "бульвар",
            "б-р",
            "площадь",
            "пл",
            "аллея",
            "тупик",
            "линия",
            "владение",
            "влад",
            "вл",
            "дом",
            "д ",
            "корпус",
            "корп",
            "строение",
            "стр",
            "квартал",
            "мкр"
        ]

        return markers.contains { text.contains($0) }
    }

    private static func looksLikeMetro(_ text: String) -> Bool
    {
        let markers = [
            "метро",
            "станция",
            "мцк",
            "мцд"
        ]

        return markers.contains { text.contains($0) }
    }

    private static func hasHouseNumber(_ text: String) -> Bool
    {
        firstNumber(in: text) != nil
    }

    private static func firstNumber(in text: String) -> String?
    {
        text
            .split(separator: " ")
            .map(String.init)
            .first { token in
                token.contains { $0.isNumber }
            }
    }

    private static func expandAddressAbbreviations(in text: String) -> String
    {
        let replacements: [String: String] = [
            "ул": "улица",
            "ул.": "улица",
            "пр-кт": "проспект",
            "пркт": "проспект",
            "просп": "проспект",
            "просп.": "проспект",
            "проспек": "проспект",
            "проспекь": "проспект",
            "проспекть": "проспект",
            "пр-д": "проезд",
            "прд": "проезд",
            "пер": "переулок",
            "пер.": "переулок",
            "вл": "владение",
            "вл.": "владение",
            "влад": "владение",
            "влад.": "владение",
            "наб": "набережная",
            "наб.": "набережная",
            "ш": "шоссе",
            "ш.": "шоссе",
            "б-р": "бульвар",
            "бул": "бульвар",
            "бул.": "бульвар",
            "пл": "площадь",
            "пл.": "площадь",
            "д": "дом",
            "д.": "дом",
            "корп": "корпус",
            "корп.": "корпус",
            "стр": "строение",
            "стр.": "строение",
            "мкр": "микрорайон"
        ]

        let tokens = normalized(text)
            .split(separator: " ")
            .map { token in
                replacements[String(token)] ?? String(token)
            }

        return tokens.joined(separator: " ")
    }

    private static func searchRegion() -> MKCoordinateRegion
    {
        let center = CLLocationCoordinate2D(
            latitude: (MapBorders.minLatitude + MapBorders.maxLatitude) / 2.0,
            longitude: (MapBorders.minLongitude + MapBorders.maxLongitude) / 2.0
        )

        let latitudeSpan = max(
            0.30,
            (MapBorders.maxLatitude - MapBorders.minLatitude) * 1.35
        )
        let longitudeSpan = max(
            0.42,
            (MapBorders.maxLongitude - MapBorders.minLongitude) * 1.30
        )

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: latitudeSpan,
                longitudeDelta: longitudeSpan
            )
        )
    }

    private static func fallbackDelay(for query: String) -> UInt64
    {
        let intent = detectIntent(for: query)

        switch intent {
        case .address:
            return 220_000_000
        case .metro:
            return 260_000_000
        case .generic:
            return 300_000_000
        }
    }

    private static func appendVariant(
        _ variants: inout [SearchVariant],
        text: String,
        bonus: Int,
        resultTypes: MKLocalSearch.ResultType
    )
    {
        let key = normalized(text)

        if key.isEmpty {
            return
        }

        if variants.contains(where: { normalized($0.text) == key }) {
            return
        }

        variants.append(
            SearchVariant(
                text: text,
                bonus: bonus,
                resultTypes: resultTypes
            )
        )
    }

    private static func ownershipVariants(from text: String) -> [String]
    {
        let variants = [
            text.replacingOccurrences(of: "владение", with: "вл"),
            text.replacingOccurrences(of: "владение", with: "влад"),
            text.replacingOccurrences(of: "влад ", with: "владение "),
            text.replacingOccurrences(of: "вл ", with: "владение ")
        ]

        return variants.filter { normalized($0) != normalized(text) }
    }

    private static func houseWordVariants(from text: String) -> [String]
    {
        var tokens = tokenized(text)

        guard tokens.contains("дом") == false,
              tokens.contains("владение") == false else {
            return []
        }

        for index in tokens.indices {
            guard tokens[index].contains(where: { $0.isNumber }) else {
                continue
            }

            let previous = index > tokens.startIndex ? tokens[tokens.index(before: index)] : ""
            if previous == "строение" || previous == "корпус" {
                continue
            }

            tokens.insert("дом", at: index)
            let variant = tokens.joined(separator: " ")
            return normalized(variant) == normalized(text) ? [] : [variant]
        }

        return []
    }

    private static func streetPrefixVariants(from text: String) -> [String]
    {
        let value = normalized(text)
        let streetMarkers = [
            "улица",
            "ул",
            "проспект",
            "проезд",
            "переулок",
            "шоссе",
            "набережная",
            "наб",
            "бульвар",
            "площадь",
            "аллея",
            "тупик",
            "линия"
        ]

        guard hasHouseNumber(value),
              streetMarkers.contains(where: { containsToken(value, $0) }) == false else {
            return []
        }

        return ["улица \(text)"]
    }

    private static func relaxedAddressVariants(from text: String) -> [String]
    {
        var variants: [String] = []

        let withoutBuilding = replaceRegex(
            in: text,
            pattern: "\\b(строение|стр|корпус|корп|владение|влад|вл)\\s*\\d+[а-яa-z0-9/-]*",
            template: ""
        )

        let cleanedWithoutBuilding = cleanedQuery(withoutBuilding)
        if normalized(cleanedWithoutBuilding) != normalized(text),
           cleanedWithoutBuilding.isEmpty == false {
            variants.append(cleanedWithoutBuilding)
        }

        let streetAndHouse = replaceRegex(
            in: text,
            pattern: "\\b(строение|стр|корпус|корп)\\s*\\d+[а-яa-z0-9/-]*",
            template: ""
        )

        let cleanedStreetAndHouse = cleanedQuery(streetAndHouse)
        if normalized(cleanedStreetAndHouse) != normalized(text),
           normalized(cleanedStreetAndHouse) != normalized(cleanedWithoutBuilding),
           cleanedStreetAndHouse.isEmpty == false {
            variants.append(cleanedStreetAndHouse)
        }

        return variants
    }

    private static func isInsideAllowedRect(_ coordinate: CLLocationCoordinate2D) -> Bool
    {
        coordinate.latitude >= MapBorders.minLatitude
            && coordinate.latitude <= MapBorders.maxLatitude
            && coordinate.longitude >= MapBorders.minLongitude
            && coordinate.longitude <= MapBorders.maxLongitude
    }

    private static func containsToken(_ text: String, _ token: String) -> Bool
    {
        tokenized(text).contains(token)
    }

    private static func dedupKey(for suggestion: SearchSuggestion) -> String
    {
        let coordinateKey: String

        if let coordinate = suggestion.coordinate {
            let latitude = String(format: "%.5f", coordinate.latitude)
            let longitude = String(format: "%.5f", coordinate.longitude)
            coordinateKey = "\(latitude)|\(longitude)"
        } else {
            coordinateKey = "completion"
        }

        return normalized(suggestion.title + " " + suggestion.subtitle) + "|" + coordinateKey
    }

    private static func clean(_ value: String?) -> String?
    {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ","))

        return trimmed.isEmpty ? nil : trimmed
    }

    private static func compactJoin(_ values: [String?], separator: String) -> String
    {
        values.compactMap(clean).joined(separator: separator)
    }

    private static func compactJoin(_ values: [String], separator: String) -> String
    {
        values.compactMap(clean).joined(separator: separator)
    }

    private static func searchNominatimCoordinate(for text: String) async -> CLLocationCoordinate2D?
    {
        let variants = makeSearchQueries(from: text).map(\.text)

        for query in variants {
            guard let coordinate = await fetchNominatimCoordinate(query: query) else {
                continue
            }

            return coordinate
        }

        return nil
    }

    private static func fetchNominatimCoordinate(query: String) async -> CLLocationCoordinate2D?
    {
        var components = URLComponents(string: "https://nominatim.openstreetmap.org/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "jsonv2"),
            URLQueryItem(name: "limit", value: "5"),
            URLQueryItem(name: "addressdetails", value: "1"),
            URLQueryItem(name: "countrycodes", value: "ru"),
            URLQueryItem(name: "accept-language", value: "ru")
        ]

        guard let url = components?.url else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue(
            "test-course-project/1.0 (student project)",
            forHTTPHeaderField: "User-Agent"
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            let items = try JSONDecoder().decode([NominatimItem].self, from: data)

            for item in items {
                guard let latitude = Double(item.lat),
                      let longitude = Double(item.lon) else {
                    continue
                }

                let coordinate = CLLocationCoordinate2D(
                    latitude: latitude,
                    longitude: longitude
                )

                if isInsideAllowedRect(coordinate) {
                    return coordinate
                }
            }
        } catch {
            return nil
        }

        return nil
    }

    private static func uniqueValues(_ values: [String?]) -> [String]
    {
        var result: [String] = []
        var seen = Set<String>()

        for value in values {
            guard let cleaned = clean(value) else {
                continue
            }

            let key = normalized(cleaned)

            if seen.insert(key).inserted {
                result.append(cleaned)
            }
        }

        return result
    }

    private static func tokenized(_ text: String) -> [String]
    {
        normalized(text)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.isEmpty == false }
    }

    private static func cleanedQuery(_ text: String) -> String
    {
        let expandedCompact = expandCompactAddressNotation(in: text)

        return expandedCompact
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalized(_ text: String) -> String
    {
        var value = text.lowercased()

        value = value.replacingOccurrences(of: ",", with: " ")
        value = value.replacingOccurrences(of: ".", with: " ")
        value = value.replacingOccurrences(of: "ё", with: "е")
        value = value.replacingOccurrences(of: "-", with: " ")

        while value.contains("  ") {
            value = value.replacingOccurrences(of: "  ", with: " ")
        }

        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func expandCompactAddressNotation(in text: String) -> String
    {
        var value = normalized(text)

        value = replaceRegex(
            in: value,
            pattern: "(?<=[\\p{L}])(?=\\d)",
            template: " "
        )
        value = replaceRegex(
            in: value,
            pattern: "(?<=\\d)(?=[\\p{L}])",
            template: " "
        )

        let replacements: [(String, String)] = [
            ("\\b(\\d+[а-яa-z0-9/-]*)\\s*[сc]\\s*(\\d+[а-яa-z0-9/-]*)\\b", "дом $1 строение $2"),
            ("\\b(\\d+[а-яa-z0-9/-]*)\\s*[кk]\\s*(\\d+[а-яa-z0-9/-]*)\\b", "дом $1 корпус $2"),
            ("\\bвл\\s*(\\d+[а-яa-z0-9/-]*)", "владение $1"),
            ("\\bвлад\\s*(\\d+[а-яa-z0-9/-]*)", "владение $1"),
            ("\\bвладение\\s*(\\d+[а-яa-z0-9/-]*)", "владение $1"),
            ("\\bд\\s*(\\d+[а-яa-z0-9/-]*)", "дом $1"),
            ("\\bк\\s*(\\d+[а-яa-z0-9/-]*)", "корпус $1"),
            ("\\bкорп\\s*(\\d+[а-яa-z0-9/-]*)", "корпус $1"),
            ("\\bс\\s*(\\d+[а-яa-z0-9/-]*)", "строение $1"),
            ("\\bстр\\s*(\\d+[а-яa-z0-9/-]*)", "строение $1")
        ]

        for (pattern, template) in replacements {
            value = replaceRegex(in: value, pattern: pattern, template: template)
        }

        while value.contains("  ") {
            value = value.replacingOccurrences(of: "  ", with: " ")
        }

        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replaceRegex(
        in text: String,
        pattern: String,
        template: String
    ) -> String
    {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: template
        )
    }

    private static func levenshteinClose(_ token: String, haystackWordSource: String) -> Bool
    {
        let words = haystackWordSource.split(separator: " ").map(String.init)

        for word in words {
            if abs(word.count - token.count) <= 2 {
                if levenshteinDistance(token, word) <= 2 {
                    return true
                }
            }
        }

        return false
    }

    private static func levenshteinDistance(_ a: String, _ b: String) -> Int
    {
        let a = Array(a)
        let b = Array(b)

        var dist = Array(
            repeating: Array(repeating: 0, count: b.count + 1),
            count: a.count + 1
        )

        for i in 0...a.count {
            dist[i][0] = i
        }

        for j in 0...b.count {
            dist[0][j] = j
        }

        for i in 1...a.count {
            for j in 1...b.count {
                if a[i - 1] == b[j - 1] {
                    dist[i][j] = dist[i - 1][j - 1]
                } else {
                    dist[i][j] = min(
                        dist[i - 1][j] + 1,
                        dist[i][j - 1] + 1,
                        dist[i - 1][j - 1] + 1
                    )
                }
            }
        }

        return dist[a.count][b.count]
    }
}
