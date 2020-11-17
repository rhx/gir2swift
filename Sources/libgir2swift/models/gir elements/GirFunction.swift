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
    /// a function is the same as a method
    public class Function: Method {
        public override var kind: String { return "Function" }

        public override init(node: XMLElement, at index: Int) {
            super.init(node: node, at: index)
        }
    }
    
}
