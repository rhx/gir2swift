//
//  File.swift
//  
//
//  Created by Mikoláš Stuchlík on 17.11.2020.
//
import SwiftLibXML

extension GIR {
    /// a function is the same as a method
    public class Function: Method {
        public override var kind: String { return "Function" }
    }
    
}
