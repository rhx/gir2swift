//
//  File.swift
//  
//
//  Created by Mikoláš Stuchlík on 17.11.2020.
//
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif
import SwiftLibXML

extension GIR {

    /// a class data type record
    public class Class: Record {
        /// String representation of `Class`es
        public override var kind: String { return "Class" }
        /// parent class name
        public let parent: String

        /// return the parent type of the given class
        public override var parentType: Record? {
            guard !parent.isEmpty else { return nil }
            return GIR.knownDataTypes[parent] as? GIR.Record
        }

        /// return the top level ancestor type of the given class
        public override var rootType: Record {
            guard parent != "" else { return self }
            guard let p = GIR.knownDataTypes[parent] as? GIR.Record else { return self }
            return p.rootType
        }

        /// Initialiser to construct a class type from XML
        /// - Parameters:
        ///   - node: `XMLElement` to construct this constant from
        ///   - index: Index within the siblings of the `node`
        override init(node: XMLElement, at index: Int) {
            var parent = node.attribute(named: "parent") ?? ""
            if parent.isEmpty {
                parent = node.children.lazy.filter { $0.name ==  "prerequisite" }.first?.attribute(named: "name") ?? ""
            }
            self.parent = parent
            super.init(node: node, at: index)
        }
    }
    
}
