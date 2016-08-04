//
//  Sequence+Utilities.swift
//  gir2swift
//
//  Created by Rene Hexel on 26/03/2016.
//  Copyright © 2016 Rene Hexel. All rights reserved.
//
extension Sequence {
    /// Returns the first element where the comparison function returns `true`
    /// or `nil` if the comparisun functoin always returns `false`.
    ///
    /// - Complexity: O(`self.count`).
    public func findFirstWhere(_ found: @noescape(Iterator.Element) -> Bool) -> Iterator.Element? {
        for element in self { if found(element) { return element } }
        return nil
    }
}


extension Sequence where Iterator.Element: Hashable {
    /// return a set containing the elements from the given sequence
    public var asSet: Set<Iterator.Element> {
        var set = Set<Iterator.Element>()
        self.forEach { set.insert($0) }
        return set
    }
}
