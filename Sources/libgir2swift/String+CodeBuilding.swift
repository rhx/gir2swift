//
//  File.swift
//  
//
//  Created by Mikoláš Stuchlík on 16/10/2020.
//

import Foundation

@_functionBuilder
class StringBuilder {
    static func buildBlock( _ segments: String...) -> String {
        segments.joined(separator: "\n")
    }
    
    static func buildEither(first: String) -> String { first }
    static func buildEither(second: String) -> String { second }
    
    static func buildOptional(_ component: String?) -> String { component ?? "" }
    static func buildIf(_ segment: String?) -> String { buildOptional(segment) }
}

extension String {
    static var defaultCodeIndentation: String = "    "
    
    static func buildCode(indentation: String? = defaultCodeIndentation, @StringBuilder builder: ()->String) -> String {
        if let indentation = indentation {
            return builder()
                .components(separatedBy: "\n")
                .lazy
                .map { indentation + $0 }
                .joined(separator: "\n")
        }
        
        return builder()
    }
    
    static func buildOneLine(@StringBuilder builder: ()->String) -> String {
        builder().components(separatedBy: "\n").joined()
    }
    
    static func loop<T>(over items: [T], @StringBuilder builder: (T)->String) -> String {
        items.map(builder).joined(separator: "\n")
    }
}
