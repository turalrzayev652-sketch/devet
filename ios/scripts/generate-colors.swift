// Writes Devet/Resources/Colors.xcassets from spec/design.md. Run from ios/:
//   swift scripts/generate-colors.swift ../spec/design.md Devet/Resources
// DesignTokensTests fails if the catalog drifts from design.md.
import Foundation
let md = try! String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
let out = CommandLine.arguments[2]
func camel(_ token: String) -> String {
  let parts = token.split(separator: ".").dropFirst().map(String.init)
  return parts.enumerated().map { $0.offset == 0 ? $0.element : $0.element.prefix(1).uppercased() + $0.element.dropFirst() }.joined()
}
typealias RGBA = (Double, Double, Double, Double)
func hex(_ h: String) -> RGBA {
  let v = Int(h.dropFirst(), radix: 16)!
  return (Double((v >> 16) & 255) / 255, Double((v >> 8) & 255) / 255, Double(v & 255) / 255, 1)
}
var sets: [(String, RGBA, RGBA)] = []
let colorRe = try! NSRegularExpression(pattern: "\\| `(color\\.[\\w.]+)` \\| `(#[0-9A-Fa-f]{6})` \\| `(#[0-9A-Fa-f]{6})` \\|")
let ns = md as NSString
for m in colorRe.matches(in: md, range: NSRange(location: 0, length: ns.length)) {
  sets.append((camel(ns.substring(with: m.range(at: 1))), hex(ns.substring(with: m.range(at: 2))), hex(ns.substring(with: m.range(at: 3)))))
}
sets.append(("bgOverlay", (31.0/255, 27.0/255, 36.0/255, 0.40), (0, 0, 0, 0.60)))
let p = "`(#[0-9A-Fa-f]{6})` / `(#[0-9A-Fa-f]{6})`"
let statusRe = try! NSRegularExpression(pattern: "\\| `(coming|declined|viewed|pending|unsent)` \\|[^|]*\\| \(p) \\| \(p) \\| \(p) \\|")
for m in statusRe.matches(in: md, range: NSRange(location: 0, length: ns.length)) {
  let name = ns.substring(with: m.range(at: 1))
  for (part, i) in [("Fg", 2), ("Text", 4), ("Bg", 6)] {
    sets.append(("status" + name.prefix(1).uppercased() + name.dropFirst() + part, hex(ns.substring(with: m.range(at: i))), hex(ns.substring(with: m.range(at: i + 1)))))
  }
}
func h8(_ v: Double) -> String { String(format: "0x%02X", Int((v * 255).rounded())) }
func comp(_ c: RGBA) -> [String: Any] {
  ["color-space": "srgb", "components": ["red": h8(c.0), "green": h8(c.1), "blue": h8(c.2), "alpha": String(format: "%.3f", c.3)]]
}
let fm = FileManager.default
let catalog = out + "/Colors.xcassets"
try? fm.removeItem(atPath: catalog)
try! fm.createDirectory(atPath: catalog, withIntermediateDirectories: true)
let info: [String: Any] = ["info": ["author": "xcode", "version": 1]]
func write(_ obj: Any, _ path: String) {
  let d = try! JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
  try! (String(data: d, encoding: .utf8)! + "\n").write(toFile: path, atomically: true, encoding: .utf8)
}
write(info, catalog + "/Contents.json")
for (name, l, d) in sets {
  let dir = "\(catalog)/\(name).colorset"
  try! fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
  write(["info": ["author": "xcode", "version": 1], "colors": [
    ["idiom": "universal", "color": comp(l)],
    ["idiom": "universal", "color": comp(d), "appearances": [["appearance": "luminosity", "value": "dark"]]],
  ]], dir + "/Contents.json")
}
print(sets.count, "colour sets")
print(sets.map { $0.0 }.joined(separator: " "))
