//
//  String+Substring.swift
//  gir2swift
//
//  Created by Rene Hexel on 25/04/2016.
//  Copyright © 2016, 2017, 2018, 2019, 2020 Rene Hexel. All rights reserved.
//
//

public extension StringProtocol {

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

    /// return the unprefixed version of the string
    /// (e.g. type without namespace)
    ///
    /// ```
    /// "gtk.is.neat".unprefixed() // "neat"
    /// ```
    ///
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

    /// Convers combination of *snake_case* and *kebab-case* to *camelCase*
    @inlinable var kebabSnakeCase2camelCase: String {
        return camelise { $0 == "-" || $0 == "_" }.deCapitalised
    }

    /// Converts combination of *snake_case* and *kebab-case* to *PascalCase*
    @inlinable var kebabSnakeCase2pascalCase: String {
        return camelise { $0 == "-" || $0 == "_" }.capitalised
    }

    /// Converts any arbitrary string to *camelCase*.
    /// - Parameter isSeparator: return true if an element is separator
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
}

