//
//  File.swift
//  
//
//  Created by Mikoláš Stuchlík on 17.11.2020.
//
import SwiftLibXML

extension GIR {

    /// a property is a C type
    public class Property: CType {
        public override var kind: String { return "Property" }
    }
    
}
