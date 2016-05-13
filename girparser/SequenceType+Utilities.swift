//
//  SequenceType+Utilities.swift
//  Gtk3Swift
//
//  Created by Rene Hexel on 26/03/2016.
//  Copyright © 2016 Rene Hexel. All rights reserved.
//
extension SequenceType {
    /// Returns the first element where the comparison function returns `true`
    /// or `nil` if the comparisun functoin always returns `false`.
    ///
    /// - Complexity: O(`self.count`).
    @warn_unused_result
    public func findFirstWhere(@noescape found: Generator.Element -> Bool) -> Generator.Element? {
        for element in self { if found(element) { return element } }
        return nil
    }
}


extension SequenceType where Generator.Element: Hashable {
    /// return a set containing the elements from the given sequence
    public var asSet: Set<Generator.Element> {
        var set = Set<Generator.Element>()
        self.forEach { set.insert($0) }
        return set
    }
}
