import Testing
import SwiftUI
@testable import HyzerKit

@Suite("Design tokens — gradient + hex init")
struct DesignTokenTests {

    // MARK: - Color(hex:)

    @Test("parses six-digit hex into sRGB components")
    func test_colorHex_parsesSixDigitHex() {
        let teal = Color(hex: "#30D5C8")
        let components = teal.resolve(in: EnvironmentValues())
        #expect(abs(components.red   - 48.0/255.0)  < 0.001)
        #expect(abs(components.green - 213.0/255.0) < 0.001)
        #expect(abs(components.blue  - 200.0/255.0) < 0.001)
    }

    @Test("accepts hex without leading hash")
    func test_colorHex_acceptsBareHex() {
        let black = Color(hex: "0A0A0C")
        let components = black.resolve(in: EnvironmentValues())
        #expect(abs(components.red   - 10.0/255.0) < 0.001)
        #expect(abs(components.green - 10.0/255.0) < 0.001)
        #expect(abs(components.blue  - 12.0/255.0) < 0.001)
    }

    // MARK: - Gradient token smoke tests
    //
    // LinearGradient's internal stops aren't publicly inspectable, so these tests
    // exercise construction — a trap in `Color(hex:)` would fire on first access.

    @Test("hyzerPrimary gradient constructs without trapping")
    func test_gradientPrimary_constructs() {
        _ = LinearGradient.hyzerPrimary
    }

    @Test("hyzerHalo gradient constructs without trapping")
    func test_gradientHalo_constructs() {
        _ = LinearGradient.hyzerHalo
    }
}
