import XCTest
import SwiftUI
import UIKit
@testable import Glance

// MARK: - ColorHexTests
// Covers: GlanceShared/Sources/Models/ThemePalette.swift (Color(hex:))

@MainActor
final class ColorHexTests: XCTestCase {

    func testHashPrefixedRedParses() {
        assertRGB(Color(hex: "#FF0000"), 1, 0, 0)
    }

    func testHexWithoutHashParses() {
        assertRGB(Color(hex: "00FF00"), 0, 1, 0)
    }

    func testLowercaseHexParses() {
        assertRGB(Color(hex: "#5e86a3"), 94.0 / 255, 134.0 / 255, 163.0 / 255)
    }

    func testInvalidHexFallsBackToBlack() {
        assertRGB(Color(hex: "zzz"), 0, 0, 0)
    }

    // MARK: Helpers

    private func assertRGB(_ color: Color, _ red: CGFloat, _ green: CGFloat, _ blue: CGFloat,
                           file: StaticString = #filePath, line: UInt = #line) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        XCTAssertTrue(UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a), file: file, line: line)
        XCTAssertEqual(r, red, accuracy: 0.01, "red", file: file, line: line)
        XCTAssertEqual(g, green, accuracy: 0.01, "green", file: file, line: line)
        XCTAssertEqual(b, blue, accuracy: 0.01, "blue", file: file, line: line)
    }
}
