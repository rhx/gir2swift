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

    /// Reference to void type
    public static var void: TypeReference = TypeReference(type: GIR.voidType, indirectionLevel: 0)
}

/// Representation of a fundamental type, its relationship to other types,
/// and casting operations
public class GIRType: Hashable {
    /// Name of the type defined in the GIR file
    public let name: String
    /// Name of the type in Swift
    public var swiftName: String
   /// Name of the type in C
    public let ctype: String
    /// The supertype (or equivalent, if alias) of this type
    public let isa: GIRType?
    /// Indicatow whether this type is an alias that doesn't need casting
    public let isAlias: Bool
    /// Dictionary of possible type conversion (cast) operations to target types
    public var conversions: [GIRType : TypeConversion] = [:]

    /// Designated initialiser for a GIR type
    /// - Parameters:
    ///   - name: The name of the type
    ///   - swiftName: The name of the type in Swift (or `nil` if same as `name`)
    ///   - ctype: The name of the type in C
    ///   - superType: The parent or alias type (or `nil` if fundamental)
    ///   - isAlias: An indicator whether the type is an alias of its supertype that does not need casting
    public init(name: String, swiftName: String? = nil, ctype: String, superType: GIRType? = nil, isAlias: Bool = false) {
        precondition(isAlias == false || superType != nil)
        self.name = name
        self.swiftName = swiftName ?? name
        self.ctype = ctype
        self.isa = superType
        self.isAlias = isAlias
    }

    /// Equality check for a type.
    /// Two types are considered equal if they have the same names and C types.
    /// - Parameters:
    ///   - lhs: The left hand side type to compare
    ///   - rhs: The right hand side type to compare
    /// - Returns: `true` if both types are considered equal
    public static func == (lhs: GIRType, rhs: GIRType) -> Bool {
        return lhs.name == rhs.name && lhs.swiftName == rhs.swiftName && lhs.ctype == rhs.ctype
    }

    /// Hashes the essential components of this type by feeding them into the
    /// given hasher.
    ///
    /// - Parameter hasher: The hasher to use when combining the components
    ///   of this instance.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(swiftName)
        hasher.combine(ctype)
    }
}

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
    public init(source: GIRType, target: GIRType) {
        self.source = source
        self.target = target
    }

    /// Swift code for converting to the target type without cast.
    /// - Parameter expression: An expression of source type to cast to the target type
    public func castToTarget(from expression: String) -> String {
        return "\(expression)"
    }

    /// Swift code for converting from the target type without cast.
    /// - Parameter expression: An expression of target type to cast to the source type
    public func castFromTarget(expression: String) -> String {
        return "\(expression)"
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

public class CastConversion: TypeConversion {
    /// Swift code for converting to the target type.
    /// By default, the type conversion is just a conversion constructor call.
    /// - Parameter expression: An expression of source type to cast to the target type
    override public func castToTarget(from expression: String) -> String {
        return "\(target.name)(\(expression))"
    }

    /// Swift code for converting from the target type to the source type.
    /// By default, the type conversion is just a conversion constructor call.
    /// - Parameter expression: An expression of target type to cast to the source type
    override public func castFromTarget(expression: String) -> String {
        return "\(source.name)(\(expression))"
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
    public init(source: GIRType, target: GIRType, downPrefix: String, downSuffix: String, upPrefix: String, upSuffix: String, embedding: TypeConversion) {
        innerConversion = embedding
        super.init(source: source, target: target, downPrefix: downPrefix, downSuffix: downSuffix, upPrefix: upPrefix, upSuffix: upSuffix)
    }
}

public extension GIR {
    static let voidType = GIRType(name: "Void", ctype: "void")

    static let floatType   = GIRType(name: "Float", ctype: "float")
    static let doubleType  = GIRType(name: "Double", ctype: "double")
    static let float80Type = GIRType(name: "Float80", ctype: "long double")
    static let intType     = GIRType(name: "Int", ctype: "long")
    static let uintType    = GIRType(name: "UInt", ctype: "unsigned long")
    static let int8Type    = GIRType(name: "Int8", ctype: "int8_t")
    static let int16Type   = GIRType(name: "Int16", ctype: "int16_t")
    static let int32Type   = GIRType(name: "Int32", ctype: "int32_t")
    static let int64Type   = GIRType(name: "Int64", ctype: "int64_t")
    static let uint8Type   = GIRType(name: "UInt8", ctype: "u_int8_t")
    static let uint16Type  = GIRType(name: "UInt16", ctype: "u_int16_t")
    static let uint32Type  = GIRType(name: "UInt32", ctype: "u_int32_t")
    static let uint64Type  = GIRType(name: "UInt64", ctype: "u_int64_t")
    static let swiftNumericTypes: Set<GIRType> = [floatType, doubleType, float80Type, intType, uintType, int8Type, int16Type, int32Type, int64Type, uint8Type, uint16Type, uint32Type, uint64Type]

    static let cintType     = GIRType(name: "CInt", ctype: "int")
    static let clongType    = GIRType(name: "CLong", ctype: "long")
    static let cshortType   = GIRType(name: "CShort", ctype: "short")
    static let cboolType    = GIRType(name: "CBool", ctype: "bool")
    static let ccharType    = GIRType(name: "CChar", ctype: "char")
    static let cscharType   = GIRType(name: "CSignedChar", ctype: "signed char")
    static let cuintType    = GIRType(name: "CUnsignedInt", ctype: "unsigned int")
    static let culongType   = GIRType(name: "CUnsignedLong", ctype: "unsigned long")
    static let cushortType  = GIRType(name: "CUnsignedShort", ctype: "unsigned short")
    static let cucharType   = GIRType(name: "CUnsignedChar", ctype: "unsigned char")
    static let cfloatType   = GIRType(name: "CFloat", ctype: "float")
    static let cdoubleType  = GIRType(name: "CDouble", ctype: "double")
    static let cldoubleType = GIRType(name: "CLongDouble", ctype: "long double")
    static let cNumericTypes: Set<GIRType> = [cintType, clongType, cshortType, cboolType, ccharType, cscharType, cuintType, culongType, cushortType, cucharType, cfloatType, cdoubleType, cldoubleType]

    static let gfloatType  = GIRType(name: "gfloat", ctype: "gfloat")
    static let gdoubleType = GIRType(name: "gdouble", ctype: "gdouble")
    static let gintType    = GIRType(name: "gnt", ctype: "glong")
    static let guintType   = GIRType(name: "guint", ctype: "guint")
    static let gint8Type   = GIRType(name: "gint8", ctype: "gint8")
    static let gint16Type  = GIRType(name: "gint16", ctype: "gint16")
    static let gint32Type  = GIRType(name: "gint32", ctype: "gint32")
    static let gint64Type  = GIRType(name: "gint64", ctype: "gint64")
    static let guint8Type  = GIRType(name: "guint8", ctype: "guint8")
    static let guint16Type = GIRType(name: "guint16", ctype: "guint16")
    static let guint32Type = GIRType(name: "guint32", ctype: "guint32")
    static let guint64Type = GIRType(name: "guint64", ctype: "guint64")
    static let gsizeType   = GIRType(name: "gsize", ctype: "gsize")
    static let goffsetType = GIRType(name: "goffset", ctype: "goffset")
    static let gbooleanType = GIRType(name: "gboolean", ctype: "gboolean")
    static let glibNumericTypes: Set<GIRType> = [gfloatType, gdoubleType, gintType, guintType, gint8Type, gint16Type, gint32Type, gint64Type, guint8Type, guint16Type, guint32Type, guint64Type, gsizeType, gbooleanType]

    static let numericTypes = swiftNumericTypes.union(cNumericTypes).union(glibNumericTypes)

    static var boolType: GIRType = {
        let b = GIRType(name: "Bool", ctype: "bool")
        let p = "(("
        let s = ") != 0)"
        numericTypes.forEach { type in
            let tp = type.name + "(("
            let ts = ") ? 1 : 0)"
            type.conversions = Dictionary(uniqueKeysWithValues: numericConversions.filter {
                $0.source == type
            }.map { ($0.target, $0) } + [
                (b, CustomConversion(source: type, target: b, downPrefix: p, downSuffix: s, upPrefix: tp, upSuffix: ts))
            ])
            b.conversions[type] = CustomConversion(source: b, target: type, downPrefix: tp, downSuffix: ts, upPrefix: p, upSuffix: s)
        }
        return b
    }()

    static var fundamentalTypes: Set<GIRType> = {
        return numericTypes ∪ boolType ∪ voidType
    }()

    static var numericConversions = { numericTypes.flatMap { s in numericTypes.map { t in
        s == t ? TypeConversion(source: s, target: t) : CastConversion(source: s, target: t)
    }}}()
}
