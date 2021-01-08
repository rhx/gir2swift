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

    /// a union data type record
    public class Union: Record {
        /// String representation of `Union`s
        public override var kind: String { return "Union" }
    }
    
}
