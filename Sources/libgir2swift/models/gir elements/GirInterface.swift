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

    /// an inteface is similar to a class,
    /// but can be part of a more complex type graph
    public class Interface: Class {
        /// String representation of `Interface`es
        public override var kind: String { return "Interface" }
    }
    
}
