//
//  girknowntypes.swift
//  libgir2swift
//
//  Created by Rene Hexel on 26/7/20.
//  Copyright © 2020, 2022 Rene Hexel.
//  All rights reserved.
//
import Foundation

public extension GIR {
    static let voidType = GIRType("Void", ctype: "void")
    static let voidRef  = TypeReference(type: voidType)
    static let noneType = GIRType("none", ctype: "void", superType: voidRef, isAlias: true)

    static let floatType   = GIRType("Float", ctype: "float")
    static let doubleType  = GIRType("Double", ctype: "double")
    static let float80Type = GIRType("Float80", ctype: "long double")
    static let intType     = GIRType("Int", ctype: "long")
    static let uintType    = GIRType("UInt", ctype: "unsigned long")
    static let int8Type    = GIRType("Int8", ctype: "int8_t")
    static let int16Type   = GIRType("Int16", ctype: "int16_t")
    static let int32Type   = GIRType("Int32", ctype: "int32_t")
    static let int64Type   = GIRType("Int64", ctype: "int64_t")
    static let uint8Type   = GIRType("UInt8", ctype: "u_int8_t")
    static let uint16Type  = GIRType("UInt16", ctype: "u_int16_t")
    static let uint32Type  = GIRType("UInt32", ctype: "u_int32_t")
    static let uint64Type  = GIRType("UInt64", ctype: "u_int64_t")
    static let swiftNumericTypes: Set<GIRType> = [floatType, doubleType, float80Type, intType, uintType, int8Type, int16Type, int32Type, int64Type, uint8Type, uint16Type, uint32Type, uint64Type]
    static let intRef = TypeReference(type: intType)
    static let uintRef = TypeReference(type: uintType)
    static let doubleRef = TypeReference(type: doubleType)

    static let Bool = "Bool"
    static let bool = "bool"
    static let cintType     = GIRType("CInt", ctype: "int")
    static let clongType    = GIRType("CLong", ctype: "long")
    static let cshortType   = GIRType("CShort", ctype: "short")
    static let cboolType    = GIRType("CBool", ctype: bool)
    static let ccharType    = GIRType(CChar, ctype: char)
    static let cscharType   = GIRType("CSignedChar", ctype: "signed char")
    static let cuintType    = GIRType("CUnsignedInt", ctype: "unsigned int")
    static let culongType   = GIRType("CUnsignedLong", ctype: "unsigned long")
    static let cushortType  = GIRType("CUnsignedShort", ctype: "unsigned short")
    static let cucharType   = GIRType("CUnsignedChar", ctype: "unsigned char")
    static let cfloatType   = GIRType("CFloat", ctype: "float")
    static let cdoubleType  = GIRType("CDouble", ctype: "double")
    static let cldoubleType = GIRType("CLongDouble", ctype: "long double")
    static let cNumericTypes: Set<GIRType> = [cintType, clongType, cshortType, cboolType, ccharType, cscharType, cuintType, culongType, cushortType, cucharType, cfloatType, cdoubleType, cldoubleType]

    static let char = "char"
    static let gchar = "gchar"
    static let guchar = "guchar"
    static let utf8 = "utf8"
    static let filename = "filename"
    static let string = "String"
    static let CChar = "CChar"
    static let gfloatType  = GIRType("gfloat", ctype: "gfloat")
    static let gdoubleType = GIRType("gdouble", ctype: "gdouble")
    static let gcharType   = GIRType(gchar, ctype: gchar)
    static let gintType    = GIRType("gint", ctype: cintType.ctype)
    static let gintRef     = TypeReference(type: gintType)
    static let gintAlias   = GIRType("gint", ctype: "gint", superType: gintRef, isAlias: true)
    static let glongType   = GIRType("glong", ctype: culongType.ctype)
    static let glongRef    = TypeReference(type: glongType)
    static let glongAlias  = GIRType("glong", ctype: "glong", superType: glongRef, isAlias: true)
    static let gshortType  = GIRType("gshort", ctype: cshortType.ctype)
    static let gshortRef   = TypeReference(type: gshortType)
    static let gshortAlias = GIRType("gshort", ctype: "gshort", superType: gshortRef, isAlias: true)
    static let gucharType  = GIRType(guchar, ctype: guchar)
    static let guintType   = GIRType("guint", ctype: cuintType.ctype)
    static let guintRef    = TypeReference(type: guintType)
    static let guintAlias  = GIRType("guint", ctype: "guint", superType: guintRef, isAlias: true)
    static let gulongType  = GIRType("gulong", ctype: culongType.ctype)
    static let gulongRef   = TypeReference(type: gulongType)
    static let gulongAlias = GIRType("gulong", ctype: "gulong", superType: gulongRef, isAlias: true)
    static let gushortType = GIRType("gushort", ctype: cushortType.ctype)
    static let gushortRef   = TypeReference(type: gshortType)
    static let gushortAlias = GIRType("gushort", ctype: "gushort", superType: gushortRef, isAlias: true)
    static let gint8Type   = GIRType("gint8", ctype: "gint8")
    static let gint16Type  = GIRType("gint16", ctype: "gint16")
    static let gint32Type  = GIRType("gint32", ctype: "gint32")
    static let gint64Type  = GIRType("gint64", ctype: "gint64")
    static let guint8Type  = GIRType("guint8", ctype: "guint8")
    static let guint16Type = GIRType("guint16", ctype: "guint16")
    static let guint32Type = GIRType("guint32", ctype: "guint32")
    static let guint64Type = GIRType("guint64", ctype: "guint64")
    static let gsizeType   = GIRType("gsize", ctype: "gsize")
    static let goffsetType = GIRType("goffset", ctype: "goffset")
    static let gbooleanType = GIRType("gboolean", ctype: "gboolean")
    static let glibNumericTypes: Set<GIRType> = [gfloatType, gdoubleType, gcharType, gintType, glongType, gshortType, gucharType, guintType, gulongType, gushortType, gint8Type, gint16Type, gint32Type, gint64Type, guint8Type, guint16Type, guint32Type, guint64Type, gsizeType, gbooleanType]

    static let numericTypes = swiftNumericTypes ∪ cNumericTypes ∪ glibNumericTypes

    static var boolType: GIRType = {
        let b = GIRType(Bool, ctype: bool)
        let p = "(("
        let s = ") != 0)"
        numericTypes.forEach { type in
            let tp = type.name + "(("
            let ts = ") ? 1 : 0)"
            let conv = CustomConversion(source: type, target: b, downPrefix: p, downSuffix: s, upPrefix: tp, upSuffix: ts)
            let rev = CustomConversion(source: b, target: type, downPrefix: tp, downSuffix: ts, upPrefix: p, upSuffix: s)
            type.conversions[b] = [conv, conv]
            b.conversions[type] = [rev, rev]
        }
        return b
    }()
    static let boolRef: TypeReference =  { TypeReference(type: boolType) }()

    static let charPtr = TypeReference.pointer(to: ccharType)
    static let constCharPtr = TypeReference.pointer(to: ccharType, isConst: true)
    static let gcharPtr = TypeReference.pointer(to: gcharType)
    static let constGCharPtr = TypeReference.pointer(to: gcharType, isConst: true)
    static let gucharPtr = TypeReference.pointer(to: gucharType)
    static let constGUCharPtr = TypeReference.pointer(to: gucharType, isConst: true)
    static let stringType = GIRStringType(name: string, ctype: char, superType: charPtr)
    static let constStringType = GIRStringType(name: string, ctype: char, superType: constCharPtr)
    static let gstringType = GIRStringType(name: string, ctype: gchar, superType: gcharPtr)
    static let constGStringType = GIRStringType(name: string, ctype: gchar, superType: gcharPtr)
    static let gustringType = GIRStringType(name: string, ctype: guchar, superType: gucharPtr)
    static let constGUStringType = GIRStringType(name: string, ctype: guchar, superType: constGUCharPtr)
    static let stringRef = TypeReference(type: stringType)
    static let constStringRef = TypeReference(type: constStringType, isConst: true)
    static let utf8Type = GIRType(utf8, ctype: gcharType.ctype)
    static let utf8Ref = TypeReference.pointer(to: utf8Type)
    static let constUTF8Ref = TypeReference.pointer(to: utf8Type, isConst: true)
    static let fileType = GIRType(filename, ctype: gcharType.ctype)
    static let fileRef = TypeReference.pointer(to: fileType)
    static let constFileRef = TypeReference.pointer(to: fileType, isConst: true)

    static let stringTypes: Set<GIRType> = {
        let ts: Set<GIRType> = [stringType, constStringType, gstringType, constGStringType, gustringType, constGUStringType]
        let t = stringType
        let p = ""
        let s = ".map({ " + t.swiftName + "(cString: $0)})"
        ts.forEach { type in
            let e = EmptyConversion(source: type, target: t)
            let r = EmptyConversion(source: t, target: type)
            let conv = StringConversion(source: type, target: t)
            let rev = StringConversion(source: t, target: type)
            type.conversions[t] = [e, e, conv, conv]
            t.conversions[type] = [r, r, rev, rev]
        }
        return ts
    }()

    static let voidPointer = TypeReference.pointer(to: voidType, isConst: true)
    static let mutableVoidPointer = TypeReference.pointer(to: voidType)
    static let rawPointerType = GIRRawPointerType(aliasOf: voidPointer, name: "UnsafeRawPointer")
    static let mutableRawPointerType = GIRRawPointerType(aliasOf: mutableVoidPointer, name: "UnsafeMutableRawPointer")
    static let opaquePointer = "OpaquePointer"
    static let gpointer = "gpointer"
    static let gpointerB = gpointer + "!"
    static let gpointerQ = gpointer + "?"
    static let gconstpointer = "gconstpointer"
    static let gconstpointerB = gconstpointer + "!"
    static let gconstpointerQ = gconstpointer + "?"
    static let gpointerType = GIRRawPointerType(aliasOf: mutableVoidPointer, name: gpointer, swiftName: gpointer, ctype: gpointer)
    static let gpointerConstPointerType = GIRRawPointerType(aliasOf: mutableVoidPointer, name: gpointer, swiftName: gpointer, ctype: gconstpointer)
    static let gconstpointerType = GIRRawPointerType(aliasOf: voidPointer, name: gconstpointer, swiftName: gconstpointer, ctype: gconstpointer)
    static let opaquePointerType = GIROpaquePointerType(aliasOf: mutableVoidPointer, name: opaquePointer)
    static let optionalGPointerType = GIRRawPointerType(aliasOf: mutableVoidPointer, name: gpointerQ, swiftName: gpointerQ, ctype: gpointerQ)
    static let optionalGConstPointerType = GIRRawPointerType(aliasOf: mutableVoidPointer, name: gconstpointerQ, swiftName: gconstpointerQ, ctype: gconstpointerQ)
    static let forceUnwrappedGPointerType = GIRRawPointerType(aliasOf: mutableVoidPointer, name: gpointerB, swiftName: gpointerB, ctype: gpointerB)
    static let forceUnwrappedGConstPointerType = GIRRawPointerType(aliasOf: mutableVoidPointer, name: gconstpointerB, swiftName: gconstpointerB, ctype: gconstpointerB)
    static let rawPointerTypes: Set<GIRType> = [rawPointerType, mutableRawPointerType]
    static let constPointerTypes: Set<GIRType> = [rawPointerType, gconstpointerType, optionalGConstPointerType, forceUnwrappedGConstPointerType]
    static let mutablePointerTypes: Set<GIRType> = [mutableRawPointerType, gpointerType, optionalGPointerType, forceUnwrappedGPointerType]
    static let pointerTypes = constPointerTypes ∪ mutablePointerTypes ∪ opaquePointerType
    static let rawPointerRef = TypeReference(type: rawPointerType)
    static let mutableRawPointerRef = TypeReference(type: mutableRawPointerType)
    static let gpointerRef = TypeReference(type: gpointerType)
    static let gpointerConstPointerRef = TypeReference(type: gpointerConstPointerType)
    static let optionalGPointerRef = TypeReference(type: optionalGPointerType)
    static let forceUnwrappedGPointerRef = TypeReference(type: forceUnwrappedGPointerType)
    static let gconstpointerRef = TypeReference(type: gconstpointerType)
    static let optionalGConstPointerRef = TypeReference(type: optionalGConstPointerType)
    static let forceUnwrappedGConstPointerRef = TypeReference(type: forceUnwrappedGConstPointerType)
    static let gpointerPointerRef = TypeReference.pointer(to: gpointerType, pointerIsConst: true)
    static let optionalGPointerPointerRef = TypeReference.pointer(to: optionalGPointerType, pointerIsConst: true)
    static let gpointerMutablePointerRef = TypeReference.pointer(to: gpointerType)
    static let optionalGPointerMutablePointerRef = TypeReference.pointer(to: optionalGPointerType)
    static let gconstpointerPointerRef = TypeReference.pointer(to: gconstpointerType, pointerIsConst: true)
    static let optionalGConstpointerPointerRef = TypeReference.pointer(to: optionalGConstPointerType, pointerIsConst: true)
    static let gconstpointerMutablePointerRef = TypeReference.pointer(to: gconstpointerType)
    static let optionalGConstpointerMutablePointerRef = TypeReference.pointer(to: optionalGConstPointerType)

    static let glist = "GList"
    static let error = "Error"
    static let gerror = "GError"
    static let errorT = "GLibError"
    static let errorProtocol = GIRType(error, ctype: "")
    static let errorReference = TypeReference(type: errorProtocol)
    static let gErrorStruct = GIRType(gerror, ctype: gerror, superType: errorReference)
    static let errorPointer = TypeReference.pointer(to: gErrorStruct)
    static let constErrorPointer = TypeReference.pointer(to: gErrorStruct, isConst: true)
    static let errorType = GIRType(aliasOf: errorPointer, name: error, swiftName: errorT)
    static let gerrorType = GIRType(aliasOf: errorPointer)

    static var errorTypes: Set<GIRType> = {
        let types: Set<GIRType> = [errorType, gerrorType]
        return types
    }()

    /// Common aliases used
    static var aliases: Set<GIRType> = {[
        GIRType(aliasOf: guintType, ctype: "unsigned int"),
        GIRType(aliasOf: gulongType, ctype: "unsigned long"),
        GIRType(aliasOf: gushortType, ctype: "unsigned short"),
        GIRType(aliasOf: guint8Type, ctype: "unsigned char"),
    ]}()

    /// Known enums
    static var enums: Set<GIRType> = []

    /// Known bitfields
    static var bitfields: Set<GIRType> = []

    /// Swift `OptionSet` equivalent to the given C `enum`
    static var optionSets: [ GIRType : TypeReference ] = [:]

    /// Known records
    static var recordTypes: Set<GIRType> = []

    /// `Ref` conversion for a given record
    static var recordRefs: [ GIRType : TypeReference ] = [:]

    /// Class conversion for a given ref
    static var refRecords: [ GIRType : TypeReference ] = [:]

    /// `Protocol` conversion for a given record
    static var protocols: [ GIRType : TypeReference ] = [:]

    /// Interface implementation table
    static var implements: [ GIRType : Set<TypeReference> ] = [:]

    /// All fundamental types prior to GIR parsing
    static var fundamentalTypes: Set<GIRType> = {
        return numericTypes ∪ boolType ∪ voidType ∪ noneType ∪ stringType ∪ aliases ∪ enums ∪ bitfields
    }()

    /// All numeric conversions
    static var numericConversions = { numericTypes.flatMap { s in numericTypes.map { t in
        s == t ? TypeConversion(source: s, target: t) : CastConversion(source: s, target: t)
    }}}()

    /// All known types so far
    static var knownTypes: Set<GIRType> = fundamentalTypes

    /// Mapping from names to known types
    static var namedTypes: [String : Set<GIRType>] = {
        var namedTypes = [String : Set<GIRType>]()
        knownTypes.forEach { addKnownType($0, to: &namedTypes) }
        return namedTypes
    }()
}

public extension TypeReference {
    /// Return the idiomatic Swift type for a given type reference
    var idiomaticType: TypeReference {
        if indirectionLevel == 0, let set = GIR.optionSets[type] { return set }
        if indirectionLevel == 1, let ref = GIR.recordRefs[type] { return ref }
        return self
    }

    /// Return the underlying type (e.g. class or primitive `C` type) for a given type reference
    var underlyingType: TypeReference {
        if indirectionLevel == 1, let ref = GIR.refRecords[type] { return ref }
        return self
    }

    /// The level of indirection, taking into account known types such as `gpointer`
    /// with `0` indicating the referenced type itself,
    /// `1` representing a pointer to an instance of the referenced type,
    /// `2` representing an array of pointers (or a pointer to a pointer), etc.
    @inlinable var knownIndirectionLevel: Int { indirectionLevel + knownPointerOffset }

    /// Return an `indirectionLevel` offset if the type in question is a known pointer
    @inlinable var knownPointerOffset: Int {
        let typeName = type.typeName
        guard typeName == GIR.gpointer || typeName == GIR.gconstpointer else {
            return 0
        }
        return 1
    }
}
