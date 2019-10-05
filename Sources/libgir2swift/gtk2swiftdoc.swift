//
//  gtk2swiftdoc.swift
//  gir2swift
//
//  Created by Rene Hexel on 3/10/19.
//

/// State for parsing `gtk-doc` style strings
fileprivate enum State: Equatable {
    case passThrough
    case backtickedIdentifier
    case functionArguments
    indirect case nestedQuote(closing: String, enclosing: State)
}

/// Convert the given String to SwiftDoc
/// - Parameter gtkDoc: String in `gtk-doc` format
/// - Parameter linePrefix: string to prefix each line with (e.g. indentation and/or "///")
/// - Returns: String in SwiftDoc format
public func gtkDoc2SwiftDoc(_ gtkDoc: String, linePrefix: String = "/// ") -> String {
    var output = ""
    var state = State.passThrough
    let s = gtkDoc.startIndex
    let e = gtkDoc.endIndex
    output.reserveCapacity(gtkDoc.count)
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
        output.append(contentsOf: gtkDoc[idStart...i])
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
                flush() ; continue
            }
            switch c {
            case "%":
                let sub = gtkDoc[j..<e]
                if sub.hasPrefix("NULL") {
                    flush()
                    p = i
                    output += "`nil`"
                    i = gtkDoc.index(j, offsetBy: 4)
                    idStart = i
                    continue
                } else if sub.hasPrefix("TRUE") {
                    flush()
                    p = i
                    output += "`true`"
                    i = gtkDoc.index(j, offsetBy: 4)
                    idStart = i
                    continue
                } else if sub.hasPrefix("FALSE") {
                    flush()
                    p = i
                    output += "`false`"
                    i = gtkDoc.index(j, offsetBy: 4)
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
                guard j < e && gtkDoc[j] == ":" else { fallthrough }
                output.append(contentsOf: gtkDoc[idStart..<i])
                output.append("`")
                i = gtkDoc.index(after: j)
                idStart = i
                state = .backtickedIdentifier
                continue
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
        //        case .nestedQuote(closing: let cl, enclosing: let state)
        default:
            print("State \(state) for '\(gtkDoc[idStart...i])")
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
