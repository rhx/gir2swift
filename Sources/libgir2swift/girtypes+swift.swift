//
//  girtypes+swift.swift
//  libgir2swift
//
//  Created by Rene Hexel on 8/8/20.
//  Copyright © 2016, 2017, 2018, 2019, 2020 Rene Hexel. All rights reserved.
//
import Foundation

/// Swift extentsion for things
public extension GIR.Thing {
    /// return a name with reserved Ref or Protocol suffixes escaped
    @inlinable
    var escapedName: String {
        let na = name.typeEscaped
        return na
    }
}


/// Swift extension for arguments
public extension GIR.CType {
    /// return the, potentially prefixed argument name to use in a method declaration
    @inlinable
    var prefixedArgumentName: String {
        let argName = argumentName
        let swname = camelQuoted
        let prefixedname = argName == swname ? argName : (swname + " " + argName)
        return prefixedname
    }

    /// return the swift (known) type of the receiver as parsed from the GIR file
    @inlinable
    var swiftType: String {
        let name = typeRef.fullSwiftTypeName
        guard typeRef.type === typeRef.type && (isScalarArray || typeRef.indirectionLevel > 0) else { return name }
        let code = (isScalarArray ? "inout [" : "") + name + (isScalarArray ? "]" : "")
        return code
    }

    /// Type reference to an idiomatic Swift type used for a Swift function parameter
    @inlinable
    var swiftParamRef: TypeReference { GIR.swiftParameterTypeReplacements[typeRef] ?? typeRef }

    /// Type reference to an idiomatic Swift type used for a Swift function return value
    @inlinable
    var swiftReturnRef: TypeReference { GIR.swiftReturnTypeReplacements[typeRef] ?? typeRef }

    /// return the swift (known) type of the receiver when passed as an argument
    @inlinable
    var argumentType: String {
        let swiftRef = swiftParamRef
        let name = swiftRef.fullSwiftTypeName
        guard typeRef.type === swiftRef.type && (isScalarArray || swiftRef.indirectionLevel > 0) else { return name }
        let code = (isScalarArray ? "inout [" : "") + name + (isScalarArray ? "]" : "")
        return code
    }

    /// return the swift (known) type of the receiver when used as a return value
    @inlinable
    var returnType: String {
        let swiftRef = swiftReturnRef
        let name = swiftRef.fullSwiftTypeName
        guard typeRef.type === swiftRef.type && (isScalarArray || swiftRef.indirectionLevel > 0) else { return name }
        let code = (isScalarArray ? "[" : "") + name + (isScalarArray ? "]" : "")
        return code
    }
}


/// Swift extension for methods
public extension GIR.Method {
    var isDesignatedConstructor: Bool {
        return name == "new"
    }

    /// is this a bare factory method that is not the default constructor
    var isBareFactory: Bool {
        return args.isEmpty && !isDesignatedConstructor
    }

    /// return whether the method is a constructor of the given record
    func isConstructorOf(_ record: GIR.Record?) -> Bool {
        return record != nil && returns.isInstanceOfHierarchy(record!) && !(args.first?.isInstanceOf(record) ?? false)
    }

    /// return whether the method is a factory of the given record
    func isFactoryOf(_ record: GIR.Record?) -> Bool {
        return !isDesignatedConstructor && isConstructorOf(record)
    }
}

/// Swift extension for arguments
public extension GIR.Argument {
    /// explicit, idiomatic type name (empty if same as the underlying C type)
    @inlinable var idiomaticReturnTypeName: String {
        let type = typeRef
        let swiftReturnType = swiftReturnRef
        let typeName = type == swiftReturnType ? "" : swiftReturnType.fullSwiftTypeName
        return typeName
    }

    /// Check whether the return type may need to be optional,
    /// e.g. when derived from a pointer that may be `nil`
    @inlinable func maybeOptional(for record: GIR.Record? = nil) -> Bool {
        let isPointer = isAnyKindOfPointer
        guard let record = record else { return isPointer }
        return isInstanceOfHierarchy(record)
    }

    /// return the idiomatic/non-idiomatic return type name
    @inlinable func returnTypeName(for record: GIR.Record? = nil, beingIdiomatic: Bool = true) -> String {
        let idiomaticName = idiomaticReturnTypeName
        let name = beingIdiomatic && !idiomaticName.isEmpty ? idiomaticName : typeRef.fullSwiftTypeName
        if maybeOptional(for: record) {
            return name + "!"
        } else {
            return name
        }
    }
}


/// Swift extension for records
public extension GIR.Record {
    /// swift node name for this record
    @inlinable
    var swift: String { return name.swift }

    /// swift class name for this record
    @inlinable
    var className: String { return swift }
}
