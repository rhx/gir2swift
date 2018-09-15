import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(gir2swiftTests.allTests),
    ]
}
#endif