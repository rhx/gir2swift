//
//  File.swift
//  
//
//  Created by Mikoláš Stuchlík on 17.11.2020.
//

import Foundation

extension String {
    /// Remove the name space and return the base name of the receiver
    /// representing a fully qualified Swift type
    var withoutNameSpace: String {
        guard let dot = self.enumerated().filter({ $0.1 == "." }).last else {
            return self
        }
        return String(self[index(startIndex, offsetBy: dot.offset+1)..<endIndex])
    }
}

extension StringProtocol {
    /// Heuristic to check whether the receiver may be an escaping callback type
    @usableFromInline
    var maybeCallback: Bool {
        for suffix in GIR.callbackSuffixes {
            guard !hasSuffix(suffix) else { return true }
        }
        return false
    }

    /// Heuristic that returns an optional when the receiver may be a callback
    @usableFromInline
    var optionalWhenCallback: String {
        guard !hasSuffix("?") && !hasSuffix("!") && maybeCallback else { return String(self) }
        return self + "?"
    }

    /// Heuristic that returns an optional when the receiver may be a callback
    @usableFromInline
    var optionalWhenPointer: String {
        guard !hasSuffix("?") && !hasSuffix("!") && (hasSuffix("pointer") || maybeCallback) else { return String(self) }
        return self + "?"
    }

    /// Return `true` if the receiver represents a type name that should be a force-unwrapped optional
    @usableFromInline
    var doForceOptional: Bool {
        return GIR.forceUnwrapped.contains(String(self)) || maybeCallback
    }
}

/// Return a string of (leading) spaces preceding (and followed by) the given string
/// - Parameters:
///   - level: indentation level
///   - s: String to be indented
@usableFromInline
func indent(level: Int, _ s: String = "") -> String {
    return String(repeating: " ", count: level * 4) + s
}
