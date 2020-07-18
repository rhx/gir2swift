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
    /// Return a type reference counting the level of indirection through pointers
    var type: TypeReference {
        guard let t = children.filter({ $0.name == "type" }).first,
              let name = t.attribute(named: "name") else { return .void }
        let ctypeRaw = t.attribute(named: "type") ?? name
        let pointers = ctypeRaw.trailingAsteriskCountIgnoringWhitespace
        let ct = ctypeRaw.trimmingCharacters(in: whiteSpacesAndAsterisks)
        let gt = GIRType(name: name, ctype: ct)
        let ref = TypeReference(type: gt, indirectionLevel: pointers)
        return ref
    }
}
