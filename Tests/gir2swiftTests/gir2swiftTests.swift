import XCTest
@testable import libgir2swift

final class gir2swiftTests: XCTestCase {
    func testGtkDoc2SwiftDoc() throws {
        let input = "Test"
        let expected = "/// \(input)"
        let output = gtkDoc2SwiftDoc(input)
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocNewline() throws {
        let input = "1\n2\n"
        let expected = "/// 1\n/// 2\n"
        let output = gtkDoc2SwiftDoc(input)
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocFunction() throws {
        let input = "Test function() example"
        let expected = "Test `function()` example"
        let output = gtkDoc2SwiftDoc(input, linePrefix: "")
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocFunctionParameters() throws {
        let input = "Test function(int x,\n    char *j) example"
        let expected = "Test `function(int x,     char *j)` example"
        let output = gtkDoc2SwiftDoc(input, linePrefix: "")
        XCTAssertEqual(output, expected)
    }
    
    func testGtkDoc2SwiftDocParam() throws {
        let input = "Test @param example"
        let expected = "Test `param` example"
        let output = gtkDoc2SwiftDoc(input, linePrefix: "")
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocConst() throws {
        let input = "Test %CONSTANT example"
        let expected = "Test `CONSTANT` example"
        let output = gtkDoc2SwiftDoc(input, linePrefix: "")
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocSignal() throws {
        let input = "Test ::SIGNAL example"
        let expected = "Test `SIGNAL` example"
        let output = gtkDoc2SwiftDoc(input, linePrefix: "")
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocObjectSignal() throws {
        let input = "Test #Object::SIGNAL example"
        let expected = "Test `Object::SIGNAL` example"
        let output = gtkDoc2SwiftDoc(input, linePrefix: "")
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocObjectProperty() throws {
        let input = "Test #Object:property example"
        let expected = "Test `Object:property` example"
        let output = gtkDoc2SwiftDoc(input, linePrefix: "")
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocStructField() throws {
        let input = "Test #Struct.field example"
        let expected = "Test `Struct.field` example"
        let output = gtkDoc2SwiftDoc(input, linePrefix: "")
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocTripleQuoted() throws {
        let input = "Test |[block]| example"
        let expected = "Test \n```\nblock\n```\n example"
        let output = gtkDoc2SwiftDoc(input, linePrefix: "")
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocTripleQuotedLinePrefix() throws {
        let input = "Test |[block]| example"
        let expected = "/// Test \n/// ```\n/// block\n/// ```\n///  example"
        let output = gtkDoc2SwiftDoc(input)
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocTripleQuotedNewline() throws {
        let input = "Test \n|[\nblock\n]|\n example"
        let expected = "Test \n```\nblock\n```\n example"
        let output = gtkDoc2SwiftDoc(input, linePrefix: "")
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocTripleQuotedNewlineLinePrefix() throws {
        let input = "Test \n|[\nblock\n]|\n example"
        let expected = "/// Test \n/// ```\n/// block\n/// ```\n///  example"
        let output = gtkDoc2SwiftDoc(input)
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocTripleQuotedNewlinesLinePrefix() throws {
        let input = "Test \n|[\nA\nB\n]|\n example"
        let expected = "/// Test \n/// ```\n/// A\n/// B\n/// ```\n///  example"
        let output = gtkDoc2SwiftDoc(input)
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocTripleQuotedLanguage() throws {
        let input = "Test \n|[<!-- language=\"C\" -->\nblock\n]|\n example"
        let expected = "Test \n(C Language Example):\n```C\nblock\n```\n example"
        let output = gtkDoc2SwiftDoc(input, linePrefix: "")
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocTripleQuotedLanguageWhitespace() throws {
        let input = "Test \n|[  <!-- language=\"CSS\" -->\nblock\n]|\n example"
        let expected = "Test \n(CSS Language Example):\n```CSS\nblock\n```\n example"
        let output = gtkDoc2SwiftDoc(input, linePrefix: "")
        XCTAssertEqual(output, expected)
    }

    static var allTests = [
        ("testGtkDoc2SwiftDoc", testGtkDoc2SwiftDoc),
        ("testGtkDoc2SwiftDocNewline", testGtkDoc2SwiftDocNewline),
        ("testGtkDoc2SwiftDocFunction", testGtkDoc2SwiftDocFunction),
        ("testGtkDoc2SwiftDocFunctionParameters", testGtkDoc2SwiftDocFunctionParameters),
        ("testGtkDoc2SwiftDocParam", testGtkDoc2SwiftDocParam),
        ("testGtkDoc2SwiftDocConst", testGtkDoc2SwiftDocConst),
        ("testGtkDoc2SwiftDocSignal", testGtkDoc2SwiftDocSignal),
        ("testGtkDoc2SwiftDocObjectSignal", testGtkDoc2SwiftDocObjectSignal),
        ("testGtkDoc2SwiftDocObjectProperty", testGtkDoc2SwiftDocObjectProperty),
        ("testGtkDoc2SwiftDocStructField", testGtkDoc2SwiftDocStructField),
        ("testGtkDoc2SwiftDocTripleQuoted", testGtkDoc2SwiftDocTripleQuoted),
        ("testGtkDoc2SwiftDocTripleQuotedLinePrefix", testGtkDoc2SwiftDocTripleQuotedLinePrefix),
        ("testGtkDoc2SwiftDocTripleQuotedNewline", testGtkDoc2SwiftDocTripleQuotedNewline),
        ("testGtkDoc2SwiftDocTripleQuotedNewlineLinePrefix", testGtkDoc2SwiftDocTripleQuotedNewlineLinePrefix),
        ("testGtkDoc2SwiftDocTripleQuotedNewlinesLinePrefix", testGtkDoc2SwiftDocTripleQuotedNewlinesLinePrefix),
        ("testGtkDoc2SwiftDocTripleQuotedLanguage", testGtkDoc2SwiftDocTripleQuotedLanguage),
        ("testGtkDoc2SwiftDocTripleQuotedLanguageWhitespace", testGtkDoc2SwiftDocTripleQuotedLanguageWhitespace),
    ]
}
