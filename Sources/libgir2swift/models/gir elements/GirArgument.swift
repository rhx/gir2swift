//
//  GirArgument.swift
//  gir2swift
//
//  Created by Rene Hexel on 25/03/2016.
//  Copyright © 2016, 2017, 2018, 2019, 2020, 2022 Rene Hexel. All rights reserved.
//
import SwiftLibXML

extension GIR {
    /// data type representing a function/method argument or return type
    public class Argument: CType {
        public override var kind: String { return "Argument" }
        /// is this an instance parameter or return type?
        public let instance: Bool
        /// is this a varargs (...) parameter?
        public let _varargs: Bool
        /// is this a nullable parameter or return type?
        public let isNullable: Bool
        /// is this a parameter that can be ommitted?
        public let allowNone: Bool
        /// is this an optional (out) parameter?
        public let isOptional: Bool
        /// is this a caller-allocated (out) parameter?
        public let callerAllocates: Bool
        /// model of ownership transfer used
        public let ownershipTransfer: OwnershipTransfer
        /// whether this is an `in`, `out`, or `inout` parameter
        public let direction: ParameterDirection

        /// indicate whether the given parameter is varargs
        public var varargs: Bool {
            return _varargs || name.hasPrefix("...")
        }

        /// default constructor
        /// - Parameters:
        ///   - name: The name of the `Argument` to initialise
        ///   - cname: C identifier
        ///   - type: The corresponding, underlying GIR type
        ///   - instance: `true` if this is an instance parameter
        ///   - comment: Documentation text for the type
        ///   - introspectable: Set to `true` if introspectable
        ///   - deprecated: Documentation on deprecation status if non-`nil`
        ///   - varargs: `true` if this is a varargs `(...)` parameter
        ///   - isNullable: `true` if this is a nullable parameter or return type
        ///   - allowNone: `true` if this parameter can be omitted
        ///   - isOptional: `true` if this is an optional (out) parameter
        ///   - callerAllocates: `true` if this is caller allocated
        ///   - ownershipTransfer: model of ownership transfer used
        ///   - direction: whether this is an `in`, `out`, or `inout` paramete
        public init(name: String, cname:String, type: TypeReference, instance: Bool, comment: String, introspectable: Bool = false, deprecated: String? = nil, varargs: Bool = false, isNullable: Bool = false, allowNone: Bool = false, isOptional: Bool = false, callerAllocates: Bool = false, ownershipTransfer: OwnershipTransfer = .none, direction: ParameterDirection = .in) {
            self.instance = instance
            _varargs = varargs
            self.isNullable = isNullable
            self.allowNone = allowNone
            self.isOptional = isOptional
            self.callerAllocates = callerAllocates
            self.ownershipTransfer = ownershipTransfer
            self.direction = direction
            super.init(name: name, cname: cname, type: type, comment: comment, introspectable: introspectable, deprecated: deprecated)
        }

        /// XML constructor
        public init(node: XMLElement, at index: Int, defaultDirection: ParameterDirection = .in) {
            instance = node.name.hasPrefix("instance")
            _varargs = node.children.lazy.first(where: { $0.name == "varargs"}) != nil
            let allowNone = node.attribute(named: "allow-none")
            if let allowNone = allowNone, !allowNone.isEmpty && allowNone != "0" && allowNone != "false" {
                self.allowNone = true
            } else {
                self.allowNone = false
            }
            if let nullable = node.attribute(named: "nullable") ?? allowNone, !nullable.isEmpty && nullable != "0" && nullable != "false" {
                isNullable = true
            } else {
                isNullable = false
            }
            if let optional = node.attribute(named: "optional") ?? allowNone, !optional.isEmpty && optional != "0" && optional != "false" {
                isOptional = true
            } else {
                isOptional = false
            }
            if let callerAlloc = node.attribute(named: "caller-allocates"), !callerAlloc.isEmpty && callerAlloc != "0" && callerAlloc != "false" {
                callerAllocates = true
            } else {
                callerAllocates = false
            }
            ownershipTransfer = node.attribute(named: "transfer-ownership").flatMap { OwnershipTransfer(rawValue: $0) } ?? .none
            direction = node.attribute(named: "direction").flatMap { ParameterDirection(rawValue: $0) } ?? defaultDirection
            super.init(fromChildrenOf: node, at: index)
        }

        /// XML constructor for functions/methods/callbacks
        public init(node: XMLElement, at index: Int, varargs: Bool, defaultDirection: ParameterDirection = .in) {
            instance = node.name.hasPrefix("instance")
            _varargs = varargs
            let allowNone = node.attribute(named: "allow-none")
            if let allowNone = allowNone, !allowNone.isEmpty && allowNone != "0" && allowNone != "false" {
                self.allowNone = true
            } else {
                self.allowNone = false
            }
            if let nullable = node.attribute(named: "nullable") ?? allowNone, nullable != "0" && nullable != "false" {
                isNullable = true
            } else {
                isNullable = false
            }
            if let optional = node.attribute(named: "optional") ?? allowNone, optional != "0" && optional != "false" {
                isOptional = true
            } else {
                isOptional = false
            }
            if let callerAlloc = node.attribute(named: "caller-allocates"), callerAlloc != "0" && callerAlloc != "false" {
                callerAllocates = true
            } else {
                callerAllocates = false
            }
            ownershipTransfer = node.attribute(named: "transfer-ownership").flatMap { OwnershipTransfer(rawValue: $0) } ?? .none
            direction = node.attribute(named: "direction").flatMap { ParameterDirection(rawValue: $0) } ?? defaultDirection
            super.init(node: node, at: index)
        }
    }
}
