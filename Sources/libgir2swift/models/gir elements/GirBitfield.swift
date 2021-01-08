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

    /// a bitfield is defined akin to an enumeration
    public class Bitfield: Enumeration {
        /// String representation of `Bitfield`s
        public override var kind: String { return "Bitfield" }

        /// Register this type as an enumeration type
        @inlinable
        override public func registerKnownType() {
            let type = typeRef.type
            let ctype = GIRType(name: type.typeName, typeName: type.typeName, ctype: type.ctype)

            if !GIR.bitfields.contains(ctype) {
                let c = BitfieldTypeConversion(source: ctype, target: type)
                type.conversions[ctype] = [c, c]
                GIR.bitfields.insert(ctype)
            }

            if !GIR.bitfields.contains(type) {
                let c = BitfieldTypeConversion(source: type, target: ctype)
                type.conversions[ctype] = [c, c]
                GIR.bitfields.insert(type)
            }
        }
    }

}
