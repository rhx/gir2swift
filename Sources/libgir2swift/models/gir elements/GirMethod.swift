//
//  GirMethod.swift
//  gir2swift
//
//  Created by Rene Hexel on 25/03/2016.
//  Copyright © 2016, 2017, 2018, 2019, 2020, 2022 Rene Hexel. All rights reserved.
//
import SwiftLibXML

extension GIR {
    /// data type representing a function/method
    public class Method: Argument {     // superclass type is return type
        /// String representation of member `Method`s
        public override var kind: String { return "Method" }
        /// Return type
        public let returns: Argument
        /// All associated arguments (parameters) in order
        public let args: [Argument]
        /// `true` if this method throws an error
        public let throwsError: Bool

        /// Designated initialiser
        /// - Parameters:
        ///   - name: The name of the method
        ///   - cname: C function name
        ///   - returns: return type
        ///   - args: Array of parameters
        ///   - comment: Documentation text for the method
        ///   - introspectable: Set to `true` if introspectable
        ///   - deprecated: Documentation on deprecation status if non-`nil`
        ///   - throwsAnError: Set to `true` if this method can throw an error
        public init(name: String, cname: String, returns: Argument, args: [Argument] = [], comment: String = "", introspectable: Bool = false, deprecated: String? = nil, throwsAnError: Bool = false) {
            self.returns = returns
            self.args = args
            throwsError = throwsAnError
            super.init(name: name, cname: cname, type: returns.typeRef, instance: returns.instance, comment: comment, introspectable: introspectable, deprecated: deprecated)
        }

        /// Initialiser to construct a method type from XML
        /// - Parameters:
        ///   - node: `XMLElement` to construct this constant from
        ///   - index: Index within the siblings of the `node`
        public init(node: XMLElement, at index: Int) {
            let thrAttr = node.attribute(named: "throws") ?? "0"
            throwsError = (Int(thrAttr) ?? 0) != 0
            let children = node.children.lazy
            if let ret = children.first(where: { $0.name == "return-value"}) {
                let arg = Argument(node: ret, at: -1)
                returns = arg
            } else {
                returns = Argument(name: "", cname: "", type: .void, instance: false, comment: "")
            }
            if let params = children.first(where: { $0.name == "parameters"}) {
                let children = params.children.lazy
                args = GIR.args(children: children)
            } else {
                args = GIR.args(children: children)
            }
            super.init(node: node, at: index, varargs: args.lazy.filter({$0.varargs}).first != nil)
        }

        /// indicate whether this is an unref method
        public var isUnref: Bool {
            return args.count == 1 && name == "unref"
        }

        /// indicate whether this is a ref method
        public var isRef: Bool {
            return args.count == 1 && name == "ref"
        }

        /// indicate whether this is a getter method
        public var isGetter: Bool {
            return args.count == 1  && ( name.hasPrefix("get_") || name.hasPrefix("is_"))
        }

        /// indicate whether this is a setter method
        public var isSetter: Bool {
            return args.count == 2 && name.hasPrefix("set_")
        }

        /// indicate whether this is a setter method for the given getter
        public func isSetterFor(getter: String) -> Bool {
            guard args.count == 2 else { return false }
            let u = getter.utf8
            let s = u.index(after: u.startIndex)
            let e = u.endIndex
            let v = u[s..<e]
            let setter = "s" + String(Substring(v))
            return name == setter
        }

        /// indicate whether this is a getter method for the given setter
        public func isGetterFor(setter: String) -> Bool {
            guard args.count == 1 else { return false }
            let u = setter.utf8
            let s = u.index(after: u.startIndex)
            let e = u.endIndex
            let v = u[s..<e]
            let getter = "g" + String(Substring(v))
            return name == getter
        }
    }
    
}
