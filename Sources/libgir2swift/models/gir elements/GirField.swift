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

        /// This is temporary variable introduced to aid signal generation.
        public var containedCallback: GIR.Callback?

        public init(node: XMLElement, at index: Int) {
            if let callback = node.children.filter({ $0.name == "callback" }).first {
                containedCallback = Callback.init(node: callback, at: index)
            } 

            super.init(fromChildrenOf: node, at: index)
        }
    }
    
}
