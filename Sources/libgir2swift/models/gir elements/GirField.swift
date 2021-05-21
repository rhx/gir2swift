//
//  File.swift
//  
//
//  Created by Mikoláš Stuchlík on 17.11.2020.
//
import SwiftLibXML

extension GIR {

    /// a field is a Property
    public class Field: Property {
        public override var kind: String { return "Field" }

        /// Since fileds can constain callbacks, this property was introduced to parse it. Such variable should be stored in `CType.containedType` property. This will result in a lot of logic breaking behavior. Thus this property was introduced, since no code is generated using this property and as for now, servers for experimenting.
        public var containedCallback: GIR.Callback?

        public init(node: XMLElement, at index: Int) {
            if let callback = node.children.filter({ $0.name == "callback" }).first {
                containedCallback = Callback.init(node: callback, at: index)
            } 

            super.init(fromChildrenOf: node, at: index)
        }
    }
    
}
