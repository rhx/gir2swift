//
//  gtk2swiftdoc.swift
//  gir2swift
//
//  Created by Rene Hexel on 3/10/19.
//

/// State for parsing `gtk-doc` style strings
fileprivate enum State: Equatable {
    /// pass characters through as they are
    case passThrough
    /// inside an identifier escaped with a backtick
    case backtickedIdentifier
    /// inside an `@` or `#` symbol to be converted for DocC
    case docCSymbol
    /// inside a list of function arguments
    case functionArguments
    /// at the beginning of a language block to be quoted
    case quotedLanguagePreamble
    /// inside a `<!-- language="X" -->` comment
    case checkForLanguage
    /// get the language name out of a `<!-- language="X" -->` comment
    case getLanguage
    /// inside a quoted language block
    case quotedLanguage
    /// inside a named anchor
    case anchor
    /// inside a local hyperref
    case href
}

/// Convert the given String to SwiftDoc
/// - Returns: String in SwiftDoc format
/// - Parameters:
///   - thing: The GIR thing to generate documentation for
///   - gtkDoc: String in `gtk-doc` format
///   - linePrefix: String to prefix each line with (e.g. indentation and/or "///")
public func gtkDoc2SwiftDoc(for thing: GIR.Thing, _ gtkDoc: String, linePrefix: String = "/// ") -> String {
    var output = ""
    var language: Substring = "" // language name for a ``` quoted language block
    var state = State.passThrough
    let s = gtkDoc.startIndex
    let e = gtkDoc.endIndex
    let n = gtkDoc.count
    output.reserveCapacity(n+n/4)
    var i = s
    guard i < e else { return output }
    var j = gtkDoc.index(after: i)
    var p = s // previous index
    var idStart = s
    var wasNewLine = true
//    var wasNonID = true
    func prev() { j = i ; i = p }
    func next() { p = i ; i = j ; j = i < e ? gtkDoc.index(after: i) : e }
    func flush() {
        if idStart <= i {
            output.append(contentsOf: gtkDoc[idStart...i])
        }
        idStart = j
        next()
    }
    while i < e {
        let c = gtkDoc[i]
        if wasNewLine { output.append(linePrefix) }
        wasNewLine = false
        switch state {
        case .passThrough:
            let nl = c.isNewline
            guard !nl && !c.isWhitespace else {
                wasNewLine = nl
                flush()
                continue
            }
            switch c {
            case "%":
                let sub = gtkDoc[j..<e]
                var offset = 0
                var constant = ""
                for (original, replacement) in [
                    ("NULL", "`nil`"),
                    ("TRUE", "`true`"),
                    ("FALSE", "`false`")
                ] {
                    if sub.hasPrefix(original) {
                        offset = original.count
                        constant = replacement
                    }
                }
                guard offset == 0 else {
                    output.append(contentsOf: gtkDoc[idStart..<i])
                    p = i
                    output += constant
                    i = gtkDoc.index(j, offsetBy: offset)
                    idStart = i
                    j = i != e ? gtkDoc.index(after: i) : e
                    continue
                }
                fallthrough
            case "@", "#":
                guard j != e else { flush() ; continue }
                let next = gtkDoc[j]
                guard next == "_" || next.isLetter || next.isNumber ||
                        (c == "%" && next != "." && !next.isWhitespace && !next.isNewline) else { break }
                output.append(contentsOf: gtkDoc[idStart..<i])
                idStart = j
                state = .docCSymbol
            case "(":
                let previous = gtkDoc[p]
                guard previous == "_" || previous.isLetter || previous.isNumber else {
                    flush() ; continue
                }
                state = .functionArguments
                output.append("`")
                flush()
                continue
            case ":": // possibly a signal denoted by `::`
                guard j < e && gtkDoc[j] == ":" else { flush() ; continue }
                output.append(contentsOf: gtkDoc[idStart..<i])
                i = gtkDoc.index(after: j)
                idStart = i
                guard i < e else { break }
                output.append("`")
                state = .backtickedIdentifier
                continue
            case "|":
                guard j < e && gtkDoc[j] == "[" else { flush() ; continue }
                output.append(contentsOf: gtkDoc[idStart..<i])
                if !gtkDoc[p].isNewline { output.append("\n\(linePrefix)") }
                j = gtkDoc.index(after: j)
                idStart = j
                state = .quotedLanguagePreamble
            case "{":
                guard j < e && gtkDoc[j] == "#" else { flush() ; continue }
                output.append(contentsOf: gtkDoc[idStart..<i])
                i = gtkDoc.index(after: j)
                idStart = i
                guard i < e else { break }
                output.append("<a name=\"")
                state = .anchor
            case "[":
                guard gtkDoc[p] == "]" && j < e &&
                    (gtkDoc[j] == "_" || gtkDoc[j] == "-" || gtkDoc[j].isLetter || gtkDoc[j].isNumber) else { flush() ; continue }
                output.append(contentsOf: gtkDoc[idStart..<i])
                idStart = j
                output.append("(#")
                state = .href
            case "<":
                i = p
                flush()
                output.append("<")
                continue
            case ">":
                i = p
                flush()
                output.append(">")
                continue
            default:
                break
            }
        case .backtickedIdentifier, .docCSymbol:
            if c == "_" || c == "-" || c == ":" || c.isLetter || c.isNumber { break }
            if c == "." {
                guard j == e else { break }
                p = i
            }
            if gtkDoc[p] == "." { prev() }
            if state == .backtickedIdentifier {
                output.append(contentsOf: gtkDoc[idStart..<i])
                output.append("`")
            } else {
                appendDocC(for: thing, String(gtkDoc[idStart..<i]), to: &output)
            }
            idStart = i
            state = .passThrough
            continue
        case .functionArguments:
            guard !c.isNewline else {   // convert newlines to spaces in function arguments
                output.append(contentsOf: gtkDoc[idStart..<i])
                output.append(" ")
                idStart = j
                break
            }
            guard c == ")" else { break }
            flush()
            output.append("`")
            state = .passThrough
            continue
        case .quotedLanguagePreamble:
            guard !c.isWhitespace else { break }
            guard c == "<" && j < e && gtkDoc[j] == "!" else {
                output.append("```")
                output.append("\n\(linePrefix)")
                if idStart < e && gtkDoc[idStart].isNewline { idStart = gtkDoc.index(after: idStart) }
                state = .quotedLanguage
                continue
            }
            state = .checkForLanguage
        case .checkForLanguage:
            guard c != ">" else {
                output.append("```\(language)")
                idStart = j
                language = ""
                state = .quotedLanguage
                next()
                if i >= e || !gtkDoc[i].isNewline { output.append("\n\(linePrefix)") }
                continue
            }
            guard c == "=" && j < e && gtkDoc[j] == "\"" else { break }
            idStart = gtkDoc.index(after: j)
            i = j
            j = idStart
            state = .getLanguage
        case .getLanguage:
            guard c == "\"" else { break }
            language = gtkDoc[idStart..<i]
            if !language.isEmpty {
                output.append("(\(language) Language Example):\n\(linePrefix)")
            }
            idStart = j
            state = .checkForLanguage
        case .quotedLanguage:
            guard !c.isNewline else {
                wasNewLine = true
                flush()
                continue
            }
            guard c == "]" && j < e && gtkDoc[j] == "|" else { break }
            let previous = gtkDoc[p]
            output.append(contentsOf: gtkDoc[idStart..<i])
            if !previous.isNewline { output.append("\n\(linePrefix)") }
            output.append("```")
            i = gtkDoc.index(after: j)
            idStart = i
            if i >= e || !gtkDoc[i].isNewline { output.append("\n\(linePrefix)") }
            j = i >= e ? i : gtkDoc.index(after: i)
            state = .passThrough
            continue
        case .anchor:
            if c == "\"" {
                output.append(contentsOf: gtkDoc[idStart..<i])
                output.append("\\")
                idStart = i
            }
            guard c != "}" && !c.isNewline else {
                output.append(contentsOf: gtkDoc[idStart..<i])
                output.append("\"></a>")
                if c == "}" {
                    idStart = j
                    next()
                } else {
                    idStart = i
                }
                state = .passThrough
                continue
            }
        case .href:
            guard c != "]" && !c.isNewline else {
                output.append(contentsOf: gtkDoc[idStart..<i])
                output.append(")")
                if c == "]" {
                    idStart = j
                    next()
                } else {
                    idStart = i
                }
                state = .passThrough
                continue
            }
        }
        next()
    }
    if idStart < e { output.append(contentsOf: gtkDoc[idStart..<e]) }
    if state == .backtickedIdentifier {
        output.append("`")
    } else if state == .functionArguments {
        output.append(")`")
    }
    return output
}

/// Append a docC constant to the output string.
///
/// This function searches the known constants for the given constant and appends the
/// corresponding DocC reference to the output string.
///
/// - Parameters:
///   - symbol: The C symbol to convert to DocC and append.
///   - output: The output string to append to.
func appendDocC(for thing: GIR.Thing, _ symbol: String, to output: inout String) {
    let identifier: String
    let signal: String
    let memberComponents = symbol.split(separator: ":", omittingEmptySubsequences: false)
    if memberComponents.count == 3 && memberComponents[1].isEmpty { // a signal
        identifier = String(memberComponents[0])
        signal = String(memberComponents[2])
    } else {
        let name = memberComponents[0]
        let e = name.firstIndex(of: "(") ?? name.endIndex
        identifier = String(name[..<e])
        signal = ""
    }
    let hostingPrefix = "/" + GIR.docCHostingBasePath + (GIR.docCHostingBasePath.isEmpty ? "" : "/")
    if let type = GIR.knownCIdentifiers[identifier] ?? GIR.knownDataTypes[GIR.dottedPrefix + identifier] ?? GIR.knownDataTypes[identifier] {
        let possiblyEmptyNamespace = type.typeRef.namespace
        let namespace = possiblyEmptyNamespace.isEmpty ? GIR.prefix : possiblyEmptyNamespace
        guard signal.isEmpty && namespace == GIR.prefix else {
            let swiftName = type.name.swift
            let typePath = hostingPrefix + "/documentation/" + namespace.lowercased() + "/" + type.name.swift.lowercased()
            let methodSuffix: String
            if signal.isEmpty {
                methodSuffix = ""
            } else {
                methodSuffix = "/on" + signal.kebabSnakeCase2lowerCase + "(flags:handler:)"
            }
            output.append("[\(swiftName)](\(typePath)\(methodSuffix)")
            return
        }
        output.append("``" + type.swiftCamelCaseName + "``")
        return
    }
    if let enumeration = thing as? GIR.Enumeration {
        for value in enumeration.members {
            if value.name.swift == identifier {
                let swiftName = value.swiftCamelCaseName
                output.append("``" + thing.swiftCamelCaseName + "/" + swiftName + "``")
                return
            }
        }
    }
    if let method = thing as? GIR.Method {
        for argument in method.args {
            if argument.name.swift == identifier {
                let swiftName = argument.swiftCamelCaseName
                output.append("`" + swiftName + "`")
                return
            }
        }
    }
    output.append("`" + symbol + "`")
}
