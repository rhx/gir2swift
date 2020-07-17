//
//  girtype.swift
//  libgir2swift
//
//  Created by Rene Hexel on 18/7/20.
//  Copyright © 2020 Rene Hexel. All rights reserved.
//
import Foundation

/// Reference to a GIR type.
public struct TypeReference: Hashable {
    /// The type referenced
    public let type: GIRType
    /// The level of indirection,
    /// with `0` indicating the referenced type itself,
    /// `1` representing a pointer to an instance of the referenced type,
    /// `2` representing an array of pointers (or a pointer to a pointer), etc.
    public let indirectionLevel: Int
}

/// Representation of a fundamental type, its relationship to other types,
/// and casting operations
public class GIRType: Hashable {
    /// Name of the type defined in the GIR file
    public let name: String
    /// Name of the type in C
    public let ctype: String
    /// The supertype (or equivalent, if alias) of this type
    public let isa: GIRType?
    /// Indicatow whether this type is an alias that doesn't need casting
    public let isAlias: Bool
    /// Array of possible type conversion (cast) operations
    public var conversions: Set<TypeConversion> = []

    /// Designated initialiser for a GIR type
    /// - Parameters:
    ///   - name: The name of the type
    ///   - ctype: The name of the type in C
    ///   - superType: The parent or alias type (or `nil` if fundamental)
    ///   - isAlias: An indicator whether the type is an alias of its supertype that does not need casting
    public init(name: String, ctype: String, superType: GIRType? = nil, isAlias: Bool = false) {
        precondition(isAlias == false || superType != nil)
        self.name = name
        self.ctype = ctype
        self.isa = superType
        self.isAlias = isAlias
    }

    /// Equality check for a type.
    /// Two types are considered equal if they have the same name and C type.
    /// - Parameters:
    ///   - lhs: The left hand side type to compare
    ///   - rhs: The right hand side type to compare
    /// - Returns: `true` if both types are considered equal
    public static func == (lhs: GIRType, rhs: GIRType) -> Bool {
        return lhs.name == rhs.name && lhs.ctype == rhs.ctype
    }

    /// Hashes the essential components of this type by feeding them into the
    /// given hasher.
    ///
    /// - Parameter hasher: The hasher to use when combining the components
    ///   of this instance.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(ctype)
    }
}

/// Type conversion operation
public class TypeConversion: Hashable {
    /// Source type
    public let source: GIRType
    /// Target type
    public let target: GIRType

    /// Designated initialiser for a type conversion
    /// - Parameter source: The source type for the conversion
    /// - Parameter target: The target type this conversion refers to
    public init(source: GIRType, target: GIRType) {
        self.source = source
        self.target = target
    }

    /// Swift code for converting to the target type.
    /// By default, the type conversion is just a conversion constructor call.
    /// - Parameter expression: An expression of source type to cast to the target type
    public func castToTarget(from expression: String) -> String {
        return "\(target.name)(\(expression))"
    }

    /// Swift code for converting from the target type to the source type.
    /// By default, the type conversion is just a conversion constructor call.
    /// - Parameter expression: An expression of target type to cast to the source type
    public func castFromTarget(expression: String) -> String {
        return "\(source.name)(\(expression))"
    }

    /// Equality check for a type conversion.
    /// Two conversions are considered equal if they have the same name and C type.
    /// - Parameters:
    ///   - lhs: The left hand side type to compare
    ///   - rhs: The right hand side type to compare
    /// - Returns: `true` if both types are considered equal
    public static func == (lhs: TypeConversion, rhs: TypeConversion) -> Bool {
        return lhs.source == rhs.source && lhs.target == rhs.target
    }

    /// Hashes the essential components of this type cast by feeding them into the
    /// given hasher.
    ///
    /// - Parameter hasher: The hasher to use when combining the components
    ///   of this instance.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(source)
        hasher.combine(target)
    }
}

/// Parent/Child class conversion operation
public class SubClassConversion: TypeConversion {
    /// Swift code for converting to the target type using `as`.
    /// - Parameter expression: An expression of source type to cast to the target type
    override public func castToTarget(from expression: String) -> String {
        return "(\(expression)) as \(target.name)"
    }

    /// Swift code for converting from the target type to the source type
    /// using `as!`.
    /// - Parameter expression: An expression of target type to cast to the source type
    override public func castFromTarget(expression: String) -> String {
        return "(\(expression)) as! \(source.name)"
    }
}

/// Parent/Child class conversion operation with optional upcast
public class OptionalSubClassConversion: SubClassConversion {
    /// Swift code for optional conversion from the target type to the source type
    /// using `as?`.
    /// - Parameter expression: An expression of target type to cast to the source type
    override public func castFromTarget(expression: String) -> String {
        return "(\(expression)) as? \(source.name)"
    }
}

/// Custom type conversion operation
public class CustomConversion: TypeConversion {
    /// The prefix to apply when downcasting an expression
    public let downcastPrefix: String
    /// The suffix to apply when downcasting an expression
    public let downcastSuffix: String
    /// The prefix to apply when upcasting an expression
    public let upcastPrefix: String
    /// The suffix to apply when upcasting an expression
    public let upcastSuffix: String

    /// Designated initialiser for a custom type conversion
    /// - Parameter source: The source type for the conversion
    /// - Parameter target: The target type this conversion refers to
    /// - Parameter downPrefix:The prefix to apply when downcasting an expression
    /// - Parameter downSuffix: The suffix to apply when downcasting an expression
    /// - Parameter upPrefix: The prefix to apply when upcasting an expression
    /// - Parameter upSuffix: The suffix to apply when upcasting an expression
    public init(source: GIRType, target: GIRType, downPrefix: String, downSuffix: String, upPrefix: String, upSuffix: String) {
        downcastPrefix = downPrefix
        downcastSuffix = downSuffix
        upcastPrefix = upPrefix
        upcastSuffix = upSuffix
        super.init(source: source, target: target)
    }

    /// Swift code for converting to the target type using the downcast prefix.
    /// - Parameter expression: An expression of source type to cast to the target type
    override public func castToTarget(from expression: String) -> String {
        return downcastPrefix + expression + downcastSuffix
    }

    /// Swift code for converting to the target type using the upcast prefix.
    /// - Parameter expression: An expression of target type to cast to the source type
    override public func castFromTarget(expression: String) -> String {
        return upcastPrefix + expression + upcastSuffix
    }
}

