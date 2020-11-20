//
//  File.swift
//  
//
//  Created by Mikoláš Stuchlík on 16/10/2020.
//

import Foundation

@_functionBuilder
class CodeBuilder {
    static let ignoringEspace: String = "<%IGNORED%>"
    
    static func buildBlock( _ segments: String...) -> String {
        segments.filter { $0 != CodeBuilder.ignoringEspace } .joined(separator: "\n")
    }
    
    static func buildEither(first: String) -> String { first }
    static func buildEither(second: String) -> String { second }
    
    static func buildOptional(_ component: String?) -> String { component ?? CodeBuilder.ignoringEspace }
    static func buildIf(_ segment: String?) -> String { buildOptional(segment) }
}

class Code {
    static var defaultCodeIndentation: String = "    "
    
    static func block(indentation: String? = defaultCodeIndentation, @CodeBuilder builder: ()->String) -> String {
        let code = builder()
        
        if let indentation = indentation {
            return indentation + (code.replacingOccurrences(of: "\n", with: "\n" + indentation))
        }
        
        return builder()
    }
    
    static func line(@CodeBuilder builder: ()->String) -> String {
        builder().components(separatedBy: "\n").joined()
    }
    
    static func loop<T>(over items: [T], @CodeBuilder builder: (T)->String) -> String {
        !items.isEmpty ? items.map(builder).joined(separator: "\n") : CodeBuilder.ignoringEspace
    }
    
    static func loopEnumerated<T>(over items: [T], @CodeBuilder builder: (Int, T)->String) -> String {
        !items.isEmpty ? items.enumerated().map(builder).joined(separator: "\n") : CodeBuilder.ignoringEspace
    }
}
