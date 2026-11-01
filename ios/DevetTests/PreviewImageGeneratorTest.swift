import XCTest
@testable import Devet

final class PreviewImageGeneratorTest: XCTestCase {
    private let generator = PreviewImageGenerator()

    func testGeneratesValidImage() {
        let params = PreviewParams(
            displayName: "Elçin müəllim və ailəsi",
            code: "K7D2M9QX",
            lang: "az",
            templateBgColor: "#faf7f2"
        )
        let preview = generator.generate(params: params)

        XCTAssertEqual(preview.image.size.width, 1200)
        XCTAssertEqual(preview.image.size.height, 630)
        XCTAssertFalse(preview.bytes.isEmpty)
    }

    func testCompressesTo80KB() {
        let params = PreviewParams(
            displayName: "Elçin müəllim və ailəsi",
            code: "K7D2M9QX",
            lang: "az",
            templateBgColor: "#faf7f2"
        )
        let preview = generator.generate(params: params)

        XCTAssertLessThanOrEqual(preview.bytes.count, 80 * 1024, "Image size \(preview.bytes.count) exceeds 80 KB")
    }

    func testHandlesAllLanguages() {
        ["az", "ru", "en", "tr"].forEach { lang in
            let params = PreviewParams(
                displayName: "Test Name",
                code: "CODE123",
                lang: lang,
                templateBgColor: "#ffffff"
            )
            let preview = generator.generate(params: params)

            XCTAssertEqual(preview.image.size.width, 1200)
            XCTAssertFalse(preview.bytes.isEmpty)
        }
    }

    func testHandlesDarkAndLightBackgrounds() {
        let darkParams = PreviewParams(
            displayName: "Dark Test",
            code: "DRK12345",
            lang: "az",
            templateBgColor: "#1a1a1a"
        )
        let darkPreview = generator.generate(params: darkParams)

        let lightParams = PreviewParams(
            displayName: "Light Test",
            code: "LGT12345",
            lang: "az",
            templateBgColor: "#ffffff"
        )
        let lightPreview = generator.generate(params: lightParams)

        XCTAssertFalse(darkPreview.bytes.isEmpty)
        XCTAssertFalse(lightPreview.bytes.isEmpty)
    }

    func testReturnsCorrectCode() {
        let params = PreviewParams(
            displayName: "Test",
            code: "TESTCODE",
            lang: "az",
            templateBgColor: "#ffffff"
        )
        let preview = generator.generate(params: params)

        XCTAssertEqual(preview.code, "TESTCODE")
    }

    func testHandlesSpecialCharacters() {
        let params = PreviewParams(
            displayName: "Rəşad Əliyev və ailəsi",
            code: "K7D2M9QX",
            lang: "az",
            templateBgColor: "#faf7f2"
        )
        let preview = generator.generate(params: params)

        XCTAssertEqual(preview.image.size.width, 1200)
        XCTAssertLessThanOrEqual(preview.bytes.count, 80 * 1024)
    }

    func testHandlesInvalidColorGracefully() {
        let params = PreviewParams(
            displayName: "Test",
            code: "TEST",
            lang: "az",
            templateBgColor: "invalid-color"
        )
        let preview = generator.generate(params: params)

        XCTAssertEqual(preview.image.size.width, 1200)
        XCTAssertFalse(preview.bytes.isEmpty)
    }

    func testTruncatesToMaxLength() {
        let longName = String(repeating: "A", count: 100)
        let params = PreviewParams(
            displayName: longName,
            code: "TEST",
            lang: "az",
            templateBgColor: "#ffffff"
        )
        let preview = generator.generate(params: params)

        XCTAssertEqual(preview.image.size.width, 1200)
        XCTAssertLessThanOrEqual(preview.bytes.count, 80 * 1024)
    }
}
