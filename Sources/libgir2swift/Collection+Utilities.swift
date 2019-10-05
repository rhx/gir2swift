//
//  Collection+Utilities.swift
//  gir2swift
//
//  Created by Rene Hexel on 17/05/2016.
//  Copyright © 2016, 2019 Rene Hexel. All rights reserved.
//
extension Collection {
    /// Returns the suffix from where the `found` function/closure first returns true
    ///
    /// - Complexity: O(`self.count`).
    public func takeFrom(indexWhere found: (Iterator.Element) -> Bool) -> SubSequence {
        var i = startIndex
        while i != endIndex {
            if found(self[i]) { break }
            i = index(after: i)
        }
        return suffix(from: i)
    }
}


extension BidirectionalCollection {
    /// Trims the suffix where the `found` function/closure keeps returning true
    ///
    /// - Complexity: O(`self.count`).
    public func trimWhile(_ found: (Iterator.Element) -> Bool) -> SubSequence {
        var i = endIndex
        if i != startIndex {
            repeat {
                i = index(before: i)
                if !found(self[i]) { return prefix(through: i) }
            } while i != startIndex
        }
        return prefix(upTo: i)
    }
}
