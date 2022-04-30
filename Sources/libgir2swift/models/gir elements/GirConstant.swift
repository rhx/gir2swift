//
//  GirConstant.swift
//  gir2swift
//
//  Created by Rene Hexel on 25/03/2016.
//  Copyright © 2016, 2017, 2018, 2019, 2020, 2022 Rene Hexel. All rights reserved.
//
import SwiftLibXML

extension GIR {

    /// an entry for a constant
    public class Constant: CType {
        /// String representation of `Constant`s
        public override var kind: String { return "Constant" }
        /// raw value
        public let value: Int

        /// Designated initialiser
        /// - Parameters:
        ///   - name: The name of the `Constant` to initialise
        ///   - cname: C identifier
        ///   - type: The type of the enum
        ///   - ctype: underlying C type
        ///   - value: the value of the constant
        ///   - comment: Documentation text for the constant
        ///   - introspectable: Set to `true` if introspectable
        ///   - deprecated: Documentation on deprecation status if non-`nil`
        public init(name: String, cname: String, type: TypeReference, value: Int, comment: String, introspectable: Bool = false, deprecated: String? = nil) {
            self.value = value
            super.init(name: name, cname: cname, type: type, comment: comment, introspectable: introspectable, deprecated: deprecated)
        }

        /// Initialiser to construct a constant from XML
        /// - Parameters:
        ///   - node: `XMLElement` to construct this constant from
        ///   - index: Index within the siblings of the `node`
        ///   - nameAttr: Key for the attribute to extract the `name` property from
        public init(node: XMLElement, at index: Int, nameAttr: String = "name") {
            if let val = node.attribute(named: "value"), let v = Int(val) {
                value = v
            } else {
                value = index
            }
            super.init(node: node, at: index, nameAttr: nameAttr)
        }
    }
    
}

