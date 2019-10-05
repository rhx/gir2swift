import XCTest
@testable import libgir2swift

final class gir2swiftTests: XCTestCase {
    func testGtkDoc2SwiftDoc() throws {
        let input = "Test"
        let expected = "/// Test"
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
        let input = "Test Object::SIGNAL example"
        let expected = "Test `Object::SIGNAL` example"
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
    ]
}
