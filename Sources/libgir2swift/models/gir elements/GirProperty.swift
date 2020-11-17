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

    /// a property is a C type
    public class Property: CType {
        public override var kind: String { return "Property" }
    }
    
}
