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
    public func findFirstWhere(@noescape found: Self.Generator.Element -> Bool) -> Self.Generator.Element? {
        for element in self { if found(element) { return element } }
        return nil
    }
}
