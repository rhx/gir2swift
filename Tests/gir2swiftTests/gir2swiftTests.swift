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

    func testGtkDoc2SwiftDocNullConstant() throws {
        let input = "Test %NULL example"
        let expected = "Test `nil` example"
        let output = gtkDoc2SwiftDoc(input, linePrefix: "")
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocTrueConstant() throws {
        let input = "Test %TRUE example"
        let expected = "Test `true` example"
        let output = gtkDoc2SwiftDoc(input, linePrefix: "")
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocFalseConstant() throws {
        let input = "Test %FALSE example"
        let expected = "Test `false` example"
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

    func testGtkDoc2SwiftDocStructEndOfSentence() throws {
        let input = "Test for #Struct. Example"
        let expected = "Test for `Struct`. Example"
        let output = gtkDoc2SwiftDoc(input, linePrefix: "")
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocStructEndOfFile() throws {
        let input = "Test for #Struct."
        let expected = "Test for `Struct`."
        let output = gtkDoc2SwiftDoc(input, linePrefix: "")
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocMarkdownHash() throws {
        let input = "# Hash example"
        let expected = input
        let output = gtkDoc2SwiftDoc(input, linePrefix: "")
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocMarkdownHashHash() throws {
        let input = "## HashHash example"
        let expected = input
        let output = gtkDoc2SwiftDoc(input, linePrefix: "")
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocMarkdownHashHashHash() throws {
        let input = "### HashHashHash example"
        let expected = input
        let output = gtkDoc2SwiftDoc(input, linePrefix: "")
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocMarkdownAnchor() throws {
        let input = "Anchor {#anchor-test} test"
        let expected = "Anchor <a name=\"anchor-test\"></a> test"
        let output = gtkDoc2SwiftDoc(input, linePrefix: "")
        XCTAssertEqual(output, expected)
    }

    func testGtkDoc2SwiftDocMarkdownHREF() throws {
        let input = "Anchor [anchor test][anchor-test] test"
        let expected = "Anchor [anchor test](#anchor-test) test"
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

    func testSubstringFunctions() {
        XCTAssertEqual("1*".trailingAsteriskCountIgnoringWhitespace, 1)
        XCTAssertEqual("1**".trailingAsteriskCountIgnoringWhitespace, 2)
        XCTAssertEqual("1* ".trailingAsteriskCountIgnoringWhitespace, 1)
        XCTAssertEqual("1 *".trailingAsteriskCountIgnoringWhitespace, 1)
        XCTAssertEqual("1 * ".trailingAsteriskCountIgnoringWhitespace, 1)
        XCTAssertEqual("1 ** ".trailingAsteriskCountIgnoringWhitespace, 2)
        XCTAssertEqual("1 * * ".trailingAsteriskCountIgnoringWhitespace, 2)
        XCTAssertEqual("1 * * *".trailingAsteriskCountIgnoringWhitespace, 3)
    }

    func testGIRTypes() {
        XCTAssertTrue(GIR.knownTypes.count >= 53)
        XCTAssertTrue(GIR.namedTypes.count >= 49)
        let ct = GIR.cintType
        let cint = GIR.namedTypes[ct.name]
        XCTAssertNotNil(cint)
        let ci = cint?.index(of: ct)
        XCTAssertNotNil(ci)
        let t = cint?[ci!]
        XCTAssertNotNil(t)
        XCTAssertTrue(ct === t)
        let ut = GIR.guintType
        let guints = GIR.namedTypes[ut.name]
        XCTAssertNotNil(guints)
        XCTAssertTrue(guints!.count > 1)
        XCTAssertTrue(guints!.contains(ut))
        XCTAssertTrue(GIR.numericConversions.count >= 2116)
        let e = "some_expression"
        let castTo   = ct.cast(expression: e, to: ut)
        let castFrom = ct.cast(expression: e, from: ut)
        let revTo    = ut.cast(expression: e, from: ct)
        let revFrom  = ut.cast(expression: e, to: ct)
        XCTAssertNotNil(castTo)
        XCTAssertNotNil(castFrom)
        XCTAssertEqual(castTo, revTo)
        XCTAssertEqual(castFrom, revFrom)
        XCTAssertEqual(castTo, "guint(\(e))")
        XCTAssertEqual(castFrom, "CInt(\(e))")
        let bt = GIR.boolType
        let gt = GIR.gbooleanType
        let b = "bool_expression"
        let bcastTo   = bt.cast(expression: b, to: gt)
        let bcastFrom = bt.cast(expression: b, from: gt)
        let brevTo    = gt.cast(expression: b, from: bt)
        let brevFrom  = gt.cast(expression: b, to: bt)
        XCTAssertNotNil(bcastTo)
        XCTAssertNotNil(bcastFrom)
        XCTAssertEqual(bcastTo, brevTo)
        XCTAssertEqual(bcastFrom, brevFrom)
        XCTAssertEqual(bcastTo, "gboolean((\(b)) ? 1 : 0)")
        XCTAssertEqual(bcastFrom, "((\(b)) != 0)")
    }

    static var allTests = [
        ("testGIRTypes", testGIRTypes),
        ("testGtkDoc2SwiftDoc", testGtkDoc2SwiftDoc),
        ("testGtkDoc2SwiftDocNewline", testGtkDoc2SwiftDocNewline),
        ("testGtkDoc2SwiftDocFunction", testGtkDoc2SwiftDocFunction),
        ("testGtkDoc2SwiftDocFunctionParameters", testGtkDoc2SwiftDocFunctionParameters),
        ("testGtkDoc2SwiftDocParam", testGtkDoc2SwiftDocParam),
        ("testGtkDoc2SwiftDocConst", testGtkDoc2SwiftDocConst),
        ("testGtkDoc2SwiftDocNullConstant", testGtkDoc2SwiftDocNullConstant),
        ("testGtkDoc2SwiftDocTrueConstant", testGtkDoc2SwiftDocTrueConstant),
        ("testGtkDoc2SwiftDocFalseConstant", testGtkDoc2SwiftDocFalseConstant),
        ("testGtkDoc2SwiftDocSignal", testGtkDoc2SwiftDocSignal),
        ("testGtkDoc2SwiftDocObjectSignal", testGtkDoc2SwiftDocObjectSignal),
        ("testGtkDoc2SwiftDocObjectProperty", testGtkDoc2SwiftDocObjectProperty),
        ("testGtkDoc2SwiftDocStructField", testGtkDoc2SwiftDocStructField),
        ("testGtkDoc2SwiftDocStructEndOfSentence", testGtkDoc2SwiftDocStructEndOfSentence),
        ("testGtkDoc2SwiftDocStructEndOfFile", testGtkDoc2SwiftDocStructEndOfFile),
        ("testGtkDoc2SwiftDocMarkdownHash", testGtkDoc2SwiftDocMarkdownHash),
        ("testGtkDoc2SwiftDocMarkdownHashHash", testGtkDoc2SwiftDocMarkdownHashHash),
        ("testGtkDoc2SwiftDocMarkdownHashHashHash", testGtkDoc2SwiftDocMarkdownHashHashHash),
        ("testGtkDoc2SwiftDocMarkdownAnchor", testGtkDoc2SwiftDocMarkdownAnchor),
        ("testGtkDoc2SwiftDocMarkdownHREF", testGtkDoc2SwiftDocMarkdownHREF),
        ("testGtkDoc2SwiftDocTripleQuoted", testGtkDoc2SwiftDocTripleQuoted),
        ("testGtkDoc2SwiftDocTripleQuotedLinePrefix", testGtkDoc2SwiftDocTripleQuotedLinePrefix),
        ("testGtkDoc2SwiftDocTripleQuotedNewline", testGtkDoc2SwiftDocTripleQuotedNewline),
        ("testGtkDoc2SwiftDocTripleQuotedNewlineLinePrefix", testGtkDoc2SwiftDocTripleQuotedNewlineLinePrefix),
        ("testGtkDoc2SwiftDocTripleQuotedNewlinesLinePrefix", testGtkDoc2SwiftDocTripleQuotedNewlinesLinePrefix),
        ("testGtkDoc2SwiftDocTripleQuotedLanguage", testGtkDoc2SwiftDocTripleQuotedLanguage),
        ("testGtkDoc2SwiftDocTripleQuotedLanguageWhitespace", testGtkDoc2SwiftDocTripleQuotedLanguageWhitespace),
        ("testSubstringFunctions", testSubstringFunctions),
    ]
}
