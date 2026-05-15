import XCTest
@testable import BetterKhmer

final class BetterKhmerTests: XCTestCase {
    private static let fixturesDir: URL = {
        let here = URL(fileURLWithPath: #file)
        return here
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fixtures")
    }()

    private func loadLines(_ name: String) throws -> [String] {
        let url = Self.fixturesDir.appendingPathComponent(name)
        let txt = try String(contentsOf: url, encoding: .utf8)
        return txt.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    func testBasic() {
        XCTAssertEqual(normalize("ខ្មែរ"), "ខ្មែរ")
    }

    func testFixtures() throws {
        let inputs   = try loadLines("input.txt")
        let expected = try loadLines("expected.txt")
        XCTAssertEqual(inputs.count, expected.count)

        var failures = 0
        for (i, (inp, exp)) in zip(inputs, expected).enumerated() {
            let got = normalize(inp)
            if got != exp {
                failures += 1
                if failures <= 10 {
                    print("[\(i)] got \(got.unicodeScalars.map { String($0.value, radix: 16) }.joined(separator: " ")), want \(exp)")
                }
            }
        }
        XCTAssertEqual(failures, 0, "\(failures)/\(inputs.count) fixture failures")
    }
}
