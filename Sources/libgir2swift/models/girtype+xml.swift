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
        let typeName = attribute(named: "type-name")?.withNormalisedPrefix
        let ctype = attribute(named: "type")?.withNormalisedPrefix ?? typeName
        let nameAttr = attribute(named: "name")?.withNormalisedPrefix
        guard let cAttr = ctype ?? nameAttr else { return .void }
        let cReference = decodeIndirection(for: cAttr)
        let innerType = cReference.innerType
        let innerName = innerType.isEmpty ? type.type.name : innerType
        let rawName: String
        if let n = nameAttr {
            rawName = n
        } else {
            rawName = innerName
        }
        let name = rawName.validSwift
        let cName = ctype ?? name
        let plainType = (innerName.isEmpty ? nil : innerName) ?? typeName
        let identifier = attribute(named: "identifier")
        let isNullable = attribute(named: "nullable").flatMap({ Int($0) }).map({ $0 != 0 }) ?? false
        let oldN = GIR.namedTypes[name]?.count ?? 0
        let rawTypeRef = typeReference(named: identifier, for: name, typeName: plainType, cType: cName, isOptional: isNullable)
        let typeRef = GIR.swiftFundamentalReplacements[rawTypeRef] ?? rawTypeRef
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
        var ref = TypeReference(type: t, identifier: identifier)
        ref.constPointers = typeRef.constPointers
        ref.isConst = typeRef.isConst
        return ref
    }

    /// Return a type reference that is tracking the level of indirection
    /// through `const` and non-`const` pointers
    var type: TypeReference {
        guard let typeXMLNode = children.filter({ $0.name == "type" }).first else { return .void }
        var type = typeXMLNode.alias
        type.isOptional = attribute(named: "nullable").flatMap({ Int($0) }).map({ $0 != 0 }) ?? type.isOptional
        return type
    }


    /// Return the types contained within the given field/parameter
    var containedTypes: [GIR.CType] {
        var index = 0
        let containedTypes: [GIR.CType] = children.compactMap { child in
            switch child.name {
            case "type":
                defer { index += 1 }
                return GIR.CType(node: child, at: index)
            case "callback":
                defer { index += 1 }
                return GIR.Callback(node: child, at: index)
            default:
                return nil
            }
        }
        return containedTypes
    }

}

