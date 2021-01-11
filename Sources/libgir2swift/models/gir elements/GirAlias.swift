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

    /// a type alias is just a type with an underlying C type
    public class Alias: CType {
        /// String representation for an `Alias`
        public override var kind: String { return "Alias" }
    }

}
