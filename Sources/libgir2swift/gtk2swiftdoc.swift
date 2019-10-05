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
}

/// Convert the given String to SwiftDoc
/// - Parameter gtkDoc: String in `gtk-doc` format
/// - Parameter linePrefix: string to prefix each line with (e.g. indentation and/or "///")
/// - Returns: String in SwiftDoc format
public func gtkDoc2SwiftDoc(_ gtkDoc: String, linePrefix: String = "/// ") -> String {
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
    var wasNonID = true
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
                if sub.hasPrefix("NULL") {
                    flush()
                    p = i
                    output += "`nil`"
                    i = gtkDoc.index(i, offsetBy: 4)
                    idStart = i
                    continue
                } else if sub.hasPrefix("TRUE") {
                    flush()
                    p = i
                    output += "`true`"
                    i = gtkDoc.index(i, offsetBy: 4)
                    idStart = i
                    continue
                } else if sub.hasPrefix("FALSE") {
                    flush()
                    p = i
                    output += "`false`"
                    i = gtkDoc.index(i, offsetBy: 4)
                    idStart = i
                    continue
                }
                fallthrough
            case "@", "#":
                output.append(contentsOf: gtkDoc[idStart..<i])
                output.append("`")
                idStart = j
                state = .backtickedIdentifier
            case "(":
                let previous = gtkDoc[p]
                guard previous == "_" || previous.isLetter || previous.isNumber else {
                    flush() ; continue
                }
                state = .functionArguments
                output.append("`")
                flush()
                continue
            case ":":
                guard j < e && gtkDoc[j] == ":" else { break }
                output.append(contentsOf: gtkDoc[idStart..<i])
                output.append("`")
                i = gtkDoc.index(after: j)
                idStart = i
                state = .backtickedIdentifier
                continue
            case "|":
                guard j < e && gtkDoc[j] == "[" else { break }
                output.append(contentsOf: gtkDoc[idStart..<i])
                if !gtkDoc[p].isNewline { output.append("\n\(linePrefix)") }
                j = gtkDoc.index(after: j)
                idStart = j
                state = .quotedLanguagePreamble
            default:
                break
            }
        case .backtickedIdentifier:
            if c == "_" || c == ":" || c == "." || c.isLetter || c.isNumber { break }
            if gtkDoc[p] == "." { prev() }
            output.append(contentsOf: gtkDoc[idStart..<i])
            output.append("`")
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
        case .quotedLanguagePreamble:
            guard !c.isWhitespace else { break }
            guard c == "<" && j < e && gtkDoc[j] == "!" else {
                output.append("```")
                if !gtkDoc[idStart].isNewline { output.append("\n\(linePrefix)") }
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
