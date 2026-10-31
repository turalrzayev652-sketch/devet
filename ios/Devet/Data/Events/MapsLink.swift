import Foundation

/// Venue map link → coordinates (screens.md §3 step 4, §15.3). Rules: spec/test-vectors/README.md#maps,
/// cases: spec/test-vectors/maps.json. Same algorithm as Android `MapsLink`: the URL is split by hand so links
/// with spaces parse the same way as in the browser.
enum MapsLink {
    enum Result: Equatable {
        /// Link accepted; nil coordinates when the link carries none (short links, other hosts).
        case ok(lat: Double?, lng: Double?)
        case error(String)
    }

    private static let num = #"(-?\d{1,3}(?:\.\d+)?)"#
    private static let url = try! NSRegularExpression(pattern: #"^(https?)://([^/?#\s]+)([^?#]*)(?:\?([^#]*))?(?:#.*)?$"#, options: .caseInsensitive)
    private static let google = try! NSRegularExpression(pattern: #"^(?:www\.|maps\.)?google\.(?:[a-z]{2,3}|com?\.[a-z]{2})$"#)
    private static let pin = try! NSRegularExpression(pattern: "!3d\(num)!4d\(num)")
    private static let at = try! NSRegularExpression(pattern: "@\(num),\(num)(?:,|$)")
    private static let pair = try! NSRegularExpression(pattern: #"^\#(num),\s*\#(num)$"#)

    static func parse(_ input: String?) -> Result {
        let text = (input ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return .error("empty") }
        guard let m = groups(url, text) else { return .error("invalid_url") }
        let authority = m[2], path = m[3], query = m[4]
        var host = authority.split(separator: "@").last.map(String.init) ?? authority
        host = (host.split(separator: ":").first.map(String.init) ?? host).lowercased()
        if host.isEmpty { return .error("invalid_url") }
        guard isMapHost(host, path) else { return .ok(lat: nil, lng: nil) }

        var candidates: [[String]] = []
        if let p = groups(pin, decode(text, plus: false), whole: false) { candidates.append(p) }
        if let a = groups(at, decode(path, plus: false), whole: false) { candidates.append(a) }
        let params: [(String, String)] = query.split(separator: "&").filter { !$0.isEmpty }.map { item in
            let kv = item.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            return (decode(kv[0], plus: true), decode(kv.count > 1 ? kv[1] : "", plus: true))
        }
        for name in ["q", "query", "ll"] {
            guard let value = params.first(where: { $0.0 == name })?.1 else { continue }
            if let p = groups(pair, value.trimmingCharacters(in: .whitespaces)) { candidates.append(p) }
        }
        for c in candidates {
            if let lat = Double(c[1]), let lng = Double(c[2]), abs(lat) <= 90, abs(lng) <= 180 { return .ok(lat: lat, lng: lng) }
        }
        return .ok(lat: nil, lng: nil)
    }

    private static func isMapHost(_ host: String, _ path: String) -> Bool {
        if ["waze.com", "www.waze.com", "maps.apple.com"].contains(host) { return true }
        return groups(google, host) != nil && (host.hasPrefix("maps.") || path.hasPrefix("/maps"))
    }

    /// Capture groups ("" for a group that did not take part). `whole`: the pattern is anchored by itself.
    private static func groups(_ regex: NSRegularExpression, _ s: String, whole: Bool = true) -> [String]? {
        guard let m = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        return (0..<m.numberOfRanges).map { i in Range(m.range(at: i), in: s).map { String(s[$0]) } ?? "" }
    }

    /// Percent-decoding that keeps the text as is on a stray `%`.
    private static func decode(_ s: String, plus: Bool) -> String {
        let t = plus ? s.replacingOccurrences(of: "+", with: " ") : s
        return t.removingPercentEncoding ?? t
    }
}
