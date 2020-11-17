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

    /// a field is a Property
    public class Field: Property {
        public override var kind: String { return "Field" }

        public init(node: XMLElement, at index: Int) {
            super.init(fromChildrenOf: node, at: index)
        }
    }
    
}
