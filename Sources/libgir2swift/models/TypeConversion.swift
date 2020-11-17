//
//  girtypeconversion.swift
//  libgir2swift
//
//  Created by Rene Hexel on 26/7/20.
//  Copyright © 2020 Rene Hexel. All rights reserved.
//
import Foundation

/// Type conversion operation.
/// This root class is used for aliases/equal type conversions,
/// i.e., casts are no-ops.
public class TypeConversion: Hashable {
    /// Source type
    public let source: GIRType
    /// Target type
    public let target: GIRType

    /// Designated initialiser for a type conversion
    /// - Parameter source: The source type for the conversion
    /// - Parameter target: The target type this conversion refers to
    @inlinable
    public init(source: GIRType, target: GIRType) {
        self.source = source
        self.target = target
    }

    /// Swift code for converting to the target type without cast.
    /// - Parameter expression: An expression of source type to cast to the target type
    @inlinable
    public func castToTarget(from expression: String) -> String {
        return "\(expression)"
    }

    /// Swift code for converting from the target type without cast.
    /// - Parameter expression: An expression of target type to cast to the source type
    @inlinable
    public func castFromTarget(expression: String) -> String {
        return "\(expression)"
    }

    /// Equality check for a type conversion.
    /// Two conversions are considered equal if they have the same name and C type.
    /// - Parameters:
    ///   - lhs: The left hand side type to compare
    ///   - rhs: The right hand side type to compare
    /// - Returns: `true` if both types are considered equal
    @inlinable
    public static func == (lhs: TypeConversion, rhs: TypeConversion) -> Bool {
        return lhs.source == rhs.source && lhs.target == rhs.target
    }

    /// Hashes the essential components of this type cast by feeding them into the
    /// given hasher.
    ///
    /// - Parameter hasher: The hasher to use when combining the components
    ///   of this instance.
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(source)
        hasher.combine(target)
    }
}

/// An empty conversion has no explicit casting
public typealias EmptyConversion = TypeConversion

public class CastConversion: TypeConversion {
    /// Swift code for converting to the target type.
    /// By default, the type conversion is just a conversion constructor call.
    /// - Parameter expression: An expression of source type to cast to the target type
    @inlinable
    override public func castToTarget(from expression: String) -> String {
        return "\(target.swiftName)(\(expression))"
    }

    /// Swift code for converting from the target type to the source type.
    /// By default, the type conversion is just a conversion constructor call.
    /// - Parameter expression: An expression of target type to cast to the source type
    @inlinable
    override public func castFromTarget(expression: String) -> String {
        return "\(source.swiftName)(\(expression))"
    }
}

public class StringConversion: TypeConversion {
    /// Swift code for converting from a string to a pointer of the target type.
    /// By default, the type conversion is just a conversion constructor call.
    /// - Parameter expression: An expression of source type to cast to the target type
    @inlinable
    override public func castToTarget(from expression: String) -> String {
        return "\(expression)"
    }

    /// Swift code for converting from the target type to the source string type.
    /// By default, the type conversion is just a conversion constructor call.
    /// - Parameter expression: An expression of target type to cast to the source type
    @inlinable
    override public func castFromTarget(expression: String) -> String {
        return expression + ".map({ " + source.swiftName + "(cString: $0) })"
    }
}

/// Parent/Child class conversion operation
public class SubClassConversion: TypeConversion {
    /// Swift code for converting to the target type using `as`.
    /// - Parameter expression: An expression of source type to cast to the target type
    @inlinable
    override public func castToTarget(from expression: String) -> String {
        return "(\(expression)) as \(target.swiftName)"
    }

    /// Swift code for converting from the target type to the source type
    /// using `as!`.
    /// - Parameter expression: An expression of target type to cast to the source type
    @inlinable
    override public func castFromTarget(expression: String) -> String {
        return "(\(expression)) as! \(source.swiftName)"
    }
}

/// Parent/Child class conversion operation with optional upcast
public class OptionalSubClassConversion: SubClassConversion {
    /// Swift code for optional conversion from the target type to the source type
    /// using `as?`.
    /// - Parameter expression: An expression of target type to cast to the source type
    @inlinable
    override public func castFromTarget(expression: String) -> String {
        return "(\(expression)) as? \(source.swiftName)"
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
    @inlinable
    public init(source: GIRType, target: GIRType, downPrefix: String = "", downSuffix: String = "", upPrefix: String = "", upSuffix: String = "") {
        downcastPrefix = downPrefix
        downcastSuffix = downSuffix
        upcastPrefix = upPrefix
        upcastSuffix = upSuffix
        super.init(source: source, target: target)
    }

    /// Swift code for converting to the target type using the downcast prefix.
    /// - Parameter expression: An expression of source type to cast to the target type
    @inlinable
    override public func castToTarget(from expression: String) -> String {
        return downcastPrefix + expression + downcastSuffix
    }

    /// Swift code for converting to the target type using the upcast prefix.
    /// - Parameter expression: An expression of target type to cast to the source type
    @inlinable
    override public func castFromTarget(expression: String) -> String {
        return upcastPrefix + expression + upcastSuffix
    }
}


/// Nested type conversion operation
public class NestedConversion: CustomConversion {
    /// Nested inner conversion to apply to a type
    public var innerConversion: TypeConversion

    /// Designated initialiser for a nested type conversion
    /// - Parameter source: The source type for the conversion
    /// - Parameter target: The target type this conversion refers to
    /// - Parameter downPrefix:The prefix to apply when downcasting an expression
    /// - Parameter downSuffix: The suffix to apply when downcasting an expression
    /// - Parameter upPrefix: The prefix to apply when upcasting an expression
    /// - Parameter upSuffix: The suffix to apply when upcasting an expression
    /// - Parameter embedding: The type conversion to embed
    @inlinable
    public init(source: GIRType, target: GIRType, downPrefix: String, downSuffix: String, upPrefix: String, upSuffix: String, embedding: TypeConversion) {
        innerConversion = embedding
        super.init(source: source, target: target, downPrefix: downPrefix, downSuffix: downSuffix, upPrefix: upPrefix, upSuffix: upSuffix)
    }
}

/// Enum type conversion operation.
public class EnumTypeConversion: CastConversion {
    /// Swift code for converting to the target type without cast.
    /// - Parameter expression: An expression of source type to cast to the target type
    @inlinable
    override public func castToTarget(from expression: String) -> String {
        return super.castToTarget(from: "\(expression).rawValue")
    }
}

/// Bit field (`OptionSet`) type conversion operation.
public class BitfieldTypeConversion: EnumTypeConversion {}

/// Raw pointer conversion
public class RawPointerConversion: TypeConversion {
    /// Swift code for optional conversion from the target type to the source type
    /// using `assumingMemoryBound(to:)`.
    /// - Parameter expression: An expression of target type to cast to the source type
    @inlinable
    override public func castFromTarget(expression: String) -> String {
        return "\(expression).assumingMemoryBound(to: \(source.swiftName).self)"
    }
}
