//
//  girtype+xml.swift
//  libgir2swift
//
//  Created by Rene Hexel on 18/7/20.
//  Copyright © 2020 Rene Hexel. All rights reserved.
//
import Foundation
import SwiftLibXML

let whiteSpacesAndAsterisks = CharacterSet(charactersIn: "*").union(.whitespaces)

extension SwiftLibXML.XMLElement {
    /// Return a type reference for an XML node counting the level of indirection
    /// through `const` and non-`const` pointers
    var alias: TypeReference {
        guard let name = attribute(named: "name") else { return .void }
        let typeName = attribute(named: "type-name")
        let ctype = attribute(named: "type") ?? typeName ?? name
        let identifier = attribute(named: "identifier")
        let isNullable = attribute(named: "nullable").flatMap({ Int($0) }).map({ $0 != 0 }) ?? false
        let oldN = GIR.namedTypes[name]?.count ?? 0
        let typeRef = typeReference(named: identifier, for: name, typeName: typeName, cType: ctype, isOptional: isNullable)
        let newN = GIR.namedTypes[name]?.count ?? 0
        let isNewType = oldN != newN
        guard isNewType, let typeXMLNode = children.filter({ $0.name == "type" }).first else {
            return typeRef
        }
        let orig = typeRef.type
        let alias = typeXMLNode.alias
//        let parent = alias.type
        let gt = GIRType(name: name, swiftName: orig.swiftName, typeName: orig.typeName, ctype: orig.ctype, superType: alias, isAlias: true)
        let t = addType(gt)
        let ref = TypeReference(type: t, identifier: identifier)
        return ref
    }

    /// Return a type reference that is tracking the level of indirection
    /// through `const` and non-`const` pointers
    var type: TypeReference {
        guard let typeXMLNode = children.filter({ $0.name == "type" }).first else { return .void }
        return typeXMLNode.alias
    }
}

