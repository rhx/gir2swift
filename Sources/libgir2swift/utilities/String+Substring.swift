//
//  String+Substring.swift
//  gir2swift
//
//  Created by Rene Hexel on 25/04/2016.
//  Copyright © 2016, 2017, 2018, 2019, 2020, 2021, 2024 Rene Hexel. All rights reserved.
//
//
import Foundation

public extension StringProtocol {
    /// Return the first character of a String as a SubSequence
    @inlinable var initial: SubSequence {
        self[startIndex...startIndex]
    }

    /// Return the first character of a String as an uppercase single-character String
    @inlinable var upperInitial: String {
        initial.uppercased()
    }

    /// Dotted prefix for the string (empty if none)
    ///
    /// ```
    /// "gtk.is.neat".dottedPrefix // "gtk."
    /// "neat".dottedPrefix // ""
    /// ```
    ///
    @inlinable var dottedPrefix: SubSequence {
        firstIndex(of: ".").flatMap { self[startIndex...$0] } ?? ""
    }

    /// Prefix for the string (empty if none)
    ///
    /// ```
    /// "gtk.is.neat".namespacePrefix // "gtk."
    /// "neat".namespacePrefix // ""
    /// ```
    ///
    @inlinable var namespacePrefix: SubSequence {
        firstIndex(of: ".").flatMap { self[startIndex..<$0] } ?? ""
    }

    /// return the unprefixed version of the string
    /// (e.g. type without namespace)
    @inlinable func unprefixed(separator: String = ".") -> String {
        components(separatedBy: separator).last ?? String(self)
    }

    /// return a prefixed version of the string
    ///
    /// ```
    /// "dolly".prefixed(with: "hello") // "hello.dolly"
    /// ```
    ///
    @inlinable func prefixed(with prefix: String, separator: String = ".") -> String {
        prefix.isEmpty ? String(self) : (prefix + separator + String(self))
    }

    /// return the string resulting from removing the given suffix
    ///
    /// ```
    /// "like a magic".stringByRemoving(suffix: "magic") // "like a "
    /// "like a magic".stringByRemoving(suffix: "coffee") // nil
    /// ```
    ///
    @inlinable func stringByRemoving(suffix s: String) -> String? {
        hasSuffix(s) ? String(self.dropLast(s.count)) : nil
    }

    /// return the string resulting from removing the same number of
    /// characters as the given substring.  This will crash if the
    /// receiver is not long enough to have the corresponding number of
    /// characters removed
    ///
    /// ```
    /// "like_a_magic".stringByRemovingAnEquivalentNumberOfCharactersAs(suffix: "magic") // "like_a_"
    /// "like_a_magic".stringByRemovingAnEquivalentNumberOfCharactersAs(suffix: "coffee") // "like_a"
    /// ```
    ///
    @inlinable func stringByRemovingAnEquivalentNumberOfCharactersAs(suffix s: String) -> String {
        String(self.dropLast(s.count))
    }

    /// return the substring after the first occurrence of the given character
    ///
    /// ```
    /// "gtk.is.neat".afterFirst(separator: ".") // "is.neat"
    /// "neat".afterFirst(separator: ".") // nil
    /// ```
    ///
    @inlinable func afterFirst(separator s: Character = "_") -> String? {
        let result = split(separator: s).dropFirst().joined(separator: String(s))
        return result.isEmpty ? nil : result
    }

    /// return the capidalised name of the receiver,
    /// without changing the case of subsequent letters
    ///
    /// ```
    /// "hello".capitalised // "Hello"
    /// ```
    ///
    /// Note: this is different from `capitalized` in the Swift standard library
    @inlinable var capitalised: String {
        guard let c = first, c.isLowercase else { return String(self) }
        return c.uppercased() + String(self[index(after: startIndex)...])
    }

    /// return the de-capidalised (lower-case first character) name of the receiver
    ///
    /// ```
    /// "HELLO".deCapitalised // "hELLO"
    /// ```
    ///
    @inlinable var deCapitalised: String {
        guard let c = first, c.isUppercase else { return String(self) }
        return c.lowercased() + String(self[index(after: startIndex)...])
    }

    /// Converts *snake_case* to *camelCase*
    @inlinable var snakeCase2camelCase: String { return camelise { $0 == "_" } }

    /// Converts *snake_CASE* to *camelCase*
    @inlinable var snakeCASE2camelCase: String {
        split(separator: "_").map {
            $0.count > 1 && $0 == $0.uppercased() ? $0.lowercased() : String($0)
        }.joined(separator: "_").cameliseConstant { $0 == "_" }
    }

    /// Convers combination of *snake_case* and *kebab-case* to *camelCase*
    @inlinable var kebabSnakeCase2camelCase: String {
        return camelise { $0 == "-" || $0 == "_" }.deCapitalised
    }

    /// Converts combination of *snake_case* and *kebab-case* to *PascalCase*
    @inlinable var kebabSnakeCase2pascalCase: String {
        return camelise { $0 == "-" || $0 == "_" }.capitalised
    }

    /// Convers combination of *snake_case* and *kebab-case* to *camelCase*
    @inlinable var kebabSnakeCase2lowerCase: String {
        return split { $0 == "-" || $0 == "_" }.joined().lowercased()
    }

    /// Converts any arbitrary string to *camelCase*.
    /// - Parameter isSeparator: return true if an element is separator
    /// - Returns: camelised String.
    @inlinable func camelise(_ isSeparator: (Element) -> Bool) -> String {
        var result: String = String()
        result.reserveCapacity(self.count)

        var previousCharacterWasSeparator: Bool = false

        forEach { character in
            guard !isSeparator(character) else {
                previousCharacterWasSeparator = true
                return
            }

            result.append(
                previousCharacterWasSeparator ? character.uppercased().first! : character
            )

            previousCharacterWasSeparator = false
        }

        return result
    }

    /// Converts any arbitrary constant name to *camelCase*.
    ///
    /// This method works similar to `camelise`
    /// but leaves single-character components as-is.
    ///
    /// - Parameter isSeparator: return true if an element is separator
    /// - Returns: camelised String.
    @inlinable func cameliseConstant(_ isSeparator: (Element) -> Bool) -> String {
        var result: String = String()
        result.reserveCapacity(self.count)

        var previousCharacterWasSeparator: Bool = false
        var i = startIndex
        var nextCharacter = i == endIndex ? nil : self[i]
        while let character = nextCharacter {
            let j = index(after: i)
            nextCharacter = j == endIndex ? nil : self[j]
            i = j
            guard !isSeparator(character) else {
                previousCharacterWasSeparator = true
                continue
            }

            if previousCharacterWasSeparator,
               let nextCharacter, !isSeparator(nextCharacter) && nextCharacter == nextCharacter.uppercased().first {
                result.append(character.uppercased().first!)
            } else {
                result.append(character)
            }

            previousCharacterWasSeparator = false
        }

        return result
    }

    /// Return the number of trailing asterisks to count, ignoring white space
    ///
    /// ```
    /// "char * * ** *".trailingAsteriskCountIgnoringWhitespace // 5
    /// ```
    ///
    @inlinable var trailingAsteriskCountIgnoringWhitespace: Int { self.countTrailing(character: "*", ignoringWhiteSpace: true) }

    /// Count the number of specific trailing characters
    /// - Parameters:
    ///   - character: The trailing character to match
    ///   - string: The String (or SubString) to examine
    /// - Returns: The numbber of trailing characters matching the given character
    @inlinable func countTrailing(character searched: Element, ignoringWhiteSpace: Bool = false) -> Int {
        var counted: Int = 0
        for character in reversed() {
            if character == searched {
                counted += 1
                continue
            }

            if character.isWhitespace && ignoringWhiteSpace {
                continue
            } else {
                break
            }
        }

        return counted
    }

    /// Returns string without leading and trailing whitespaces and newlines
    var trimmed: String { return trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }

    /// Return the splittable prefix
    /// - Parameter prefixes: the prefixes to check for
    /// - Returns: The splittable substring index
    @inlinable func splittablePrefixIndex<S: StringProtocol>(from prefixes: [S]) -> Index? {
        for prefix in prefixes {
            if hasPrefix(prefix) {
                return index(startIndex, offsetBy: prefix.count)
            }
        }
        return nil
    }

    /// Replaces all occurances with given substring by empty string
    ///
    /// ```
    /// " the meaning of life ".without("the meaning") // "of life"
    /// ```
    ///
    func without(_ substring: String) -> String {
        self.replacingOccurrences(of: substring, with: "").trimmed
    }

    /// Trims whitespaces and new lines and then returns string without given prefix, called recursively
    ///
    /// ```
    /// "  well, well, well! ".without(prefix: "well,") // "well!"
    /// ```
    ///
    func without(prefix: String) -> String {
        let ns = trimmed
        guard ns.hasPrefix(prefix) else { return ns }
        let len = prefix.count
        let s = ns.index(ns.startIndex, offsetBy: len)
        let e = ns.endIndex
        return String(ns[s..<e]).without(prefix: prefix)
    }

    /// Trims whitespaces and new lines and then returns string without any of provided prefixes, called recursively
    ///
    /// ```
    /// "  all your base ".without(prefixes: ["all", "your"]) // "base"
    /// ```
    ///
    func without(prefixes: [String]) -> String {
        let ns = trimmed
        return prefixes
            .first { ns.hasPrefix($0) }
            .flatMap {
                ns.without(prefix: $0)
            }?.without(prefixes: prefixes) ?? ns
    }

    /// Trims whitespaces and new lines and then returns string without given suffix, called recursively
    ///
    /// ```
    /// "  hello there ".without(suffix: "there") // "hello"
    /// ```
    ///
    func without(suffix: String) -> String {
        let ns = trimmed
        guard ns.hasSuffix(suffix) else { return ns }
        let len = suffix.count
        let s = ns.startIndex
        let e = ns.index(s, offsetBy: ns.count - len)
        return String(ns[s..<e]).without(suffix: suffix)
    }

    /// Trims whitespaces and new lines and then returns string without any of provided suffiex, called recursively
    ///
    /// ```
    /// "  you are a bold one ".without(suffixes: ["bond", "one"]) // "you are"
    /// ```
    ///
    func without(suffixes: [String]) -> String {
        let ns = trimmed
        return suffixes
            .first { ns.hasSuffix($0) }
            .flatMap {
                ns.without(suffix: $0)
            }?.without(suffixes: suffixes) ?? ns
    }
}
