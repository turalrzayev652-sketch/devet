import Foundation

/// Files from the repository checkout. The simulator shares the host file system, so tests read the specs directly.
enum RepoFiles {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // DevetTests
        .deletingLastPathComponent() // ios
        .deletingLastPathComponent()

    static func text(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    static func json(_ path: String) throws -> [String: Any] {
        let data = try Data(contentsOf: root.appendingPathComponent(path))
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

extension String {
    /// Capture groups of every match of `pattern`.
    func matches(_ pattern: String) -> [[String]] {
        let regex = try! NSRegularExpression(pattern: pattern)
        let ns = self as NSString
        return regex.matches(in: self, range: NSRange(location: 0, length: ns.length)).map { m in
            (0..<m.numberOfRanges).map { m.range(at: $0).location == NSNotFound ? "" : ns.substring(with: m.range(at: $0)) }
        }
    }
}
