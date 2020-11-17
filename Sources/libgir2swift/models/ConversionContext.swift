//
//  File.swift
//  
//
//  Created by Mikoláš Stuchlík on 17.11.2020.
//

import Foundation
import SwiftLibXML

/// helper context class for tree traversal
class ConversionContext {
    /// Tree/indentation level
    let level: Int
    /// Parent context
    let parent: ConversionContext?
    /// Parent node in the XML tree
    let parentNode: XMLTree.Node!
    /// Dictionary of conversion functions for named nodes
    let conversion: [String : (XMLTree.Node) -> String]
    /// Array of strings representing code to be output
    var outputs: [String] = []
    
    /// Designated initialiser
    /// - Parameters:
    ///   - conversion: Dictionary of conversion functions/closures
    ///   - level: Level within the tree
    ///   - parent: Parent context (or `nil` if no parent)
    ///   - parentNode: Parent XML node (or `nil` if no parent)
    init(_ conversion: [String : (XMLTree.Node) -> String] = [:], level: Int = 0, parent: ConversionContext? = nil, parentNode: XMLTree.Node? = nil) {
        self.level = level
        self.parent = parent
        self.parentNode = parentNode
        self.conversion = conversion
    }

    /// push a context
    func push(node: XMLTree.Node, _ fs: [String : (XMLTree.Node) -> String]) -> ConversionContext {
        return ConversionContext(fs, level: node.level+1, parent: self, parentNode: node)
    }
}
