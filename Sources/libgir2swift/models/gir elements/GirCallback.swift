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

    /// a callback is the same as a function,
    /// except that the type definition is a `@convention(c)` callback definition
    public class Callback: Function {
        public override var kind: String { return "Callback" }
    }
    
}
