//
//  Character+Utilities.swift
//  Character+Utilities
//
//  Created by Rene Hexel on 24/7/21.
//  Copyright © 2021 Rene Hexel. All rights reserved.
//
import Foundation

extension Character {
    /// Return `true` if the ASCII value of the character is a digit
    var isDigit: Bool {
        let u = utf8
        guard u.count == 1 else { return false }
        return isdigit(CInt(u.first!)) != 0
    }
}
