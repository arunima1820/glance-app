import XCTest
import SwiftUI
import UIKit
@testable import Glance

// MARK: - PaletteSchemeTests
// Covers: GlanceShared/Sources/Design/Palette.swift (Palette, PaletteScheme, PaletteSchemeID, Palettes)

@MainActor
final class PaletteSchemeTests: XCTestCase {

    func testRegistryResolvesEverySchemeIDIncludingDefault() {
        for id in PaletteSchemeID.allCases {
            XCTAssertEqual(Palettes.scheme(id).id, id, "Scheme \(id) must resolve to itself")
        }
        XCTAssertEqual(Palettes.scheme(Palettes.default).id, Palettes.default)
    }

    func testLightAndDarkPalettesDiffer() {
        for id in PaletteSchemeID.allCases {
            let scheme = Palettes.scheme(id)
            XCTAssertNotEqual(scheme.light, scheme.dark, "Scheme \(id) has identical light and dark palettes")
        }
    }

    func testPaletteForColorSchemePicksMatchingVariant() {
        for id in PaletteSchemeID.allCases {
            let scheme = Palettes.scheme(id)
            XCTAssertEqual(scheme.palette(for: .light), scheme.light)
            XCTAssertEqual(scheme.palette(for: .dark), scheme.dark)
        }
    }

    func testLightPalettesMeetWCAGContrast() {
        for id in PaletteSchemeID.allCases {
            assertContrast(Palettes.scheme(id).light, label: "\(id) light")
        }
    }

    func testDarkPalettesMeetWCAGContrast() {
        for id in PaletteSchemeID.allCases {
            assertContrast(Palettes.scheme(id).dark, label: "\(id) dark")
        }
    }

    // MARK: Helpers

    private func assertContrast(_ p: Palette, label: String, file: StaticString = #filePath, line: UInt = #line) {
        let pairs: [(name: String, fg: Color, bg: Color, minimum: CGFloat)] = [
            ("ink on paper", p.ink, p.paper, 7),
            ("ink on card", p.ink, p.card, 7),
            ("ink2 on paper", p.ink2, p.paper, 4.5),
            ("ink2 on card", p.ink2, p.card, 4.5),
            ("onMarker on markerDeep", p.onMarker, p.markerDeep, 4.5),
        ]
        for pair in pairs {
            let ratio = contrastRatio(pair.fg, pair.bg)
            XCTAssertGreaterThanOrEqual(ratio, pair.minimum,
                "\(label): \(pair.name) contrast \(String(format: "%.2f", Double(ratio))) < \(pair.minimum)",
                file: file, line: line)
        }
    }

    private func contrastRatio(_ a: Color, _ b: Color) -> CGFloat {
        let la = relativeLuminance(a), lb = relativeLuminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private func relativeLuminance(_ color: Color) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        _ = UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ c: CGFloat) -> CGFloat {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }
}
