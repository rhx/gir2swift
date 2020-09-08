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
        let name = typeRef.fullTypeName
        guard typeRef.type === typeRef.type && (isScalarArray || typeRef.indirectionLevel > 0) else { return name }
        let code = (isScalarArray ? "inout [" : "") + name + (isScalarArray ? "]" : "")
        return code
    }

    /// Type reference to an idiomatic Swift type used for a Swift function parameter
    @inlinable
    var swiftParamRef: TypeReference {
        guard var replacement = GIR.swiftParameterTypeReplacements[typeRef] else { return typeRef }
        replacement.isConst = typeRef.isConst
        replacement.isOptional = typeRef.isOptional
        return replacement
    }

    /// Type reference to an idiomatic Swift type used for a Swift function return value
    @inlinable
    var swiftReturnRef: TypeReference {
        guard var replacement = GIR.swiftReturnTypeReplacements[typeRef] else {
            if typeRef.indirectionLevel == 1 && typeRef.type.typeName.hasSuffix("char") && !typeRef.type.typeName.hasSuffix("unichar") {
                return GIR.stringRef
            }
            return typeRef
        }
        replacement.isConst = typeRef.isConst
        replacement.isOptional = typeRef.isOptional
        return replacement
    }

    /// Return a Swift template declaration for a known record,
    /// or `nil` otherwise
    @inlinable
    var templateDecl: String? {
        guard let record = knownRecordReference else {
            return nil
        }
        let className = record.className
        let protocolName = record.protocolName
        let typeName = typeRef.type.name
        let prefix = typeName.girDottedPrefix
        let name: String
        if GIR.dottedPrefix != prefix && typeName.hasSuffix(className) {
            name = prefix + protocolName
        } else {
            name = protocolName
        }
        return className + "T: " + name
    }

    /// return a directly referenced known record, `nil` otherwise
    @inlinable var knownRecordReference: GIR.Record? {
        guard typeRef.knownIndirectionLevel == 1 else { return nil }
        return knownRecord
    }

    /// return whether the receiver is a direct reference to a known record
    @inlinable var isKnownRecordReference: Bool { knownRecordReference != nil }

    /// return the swift (known) type of the receiver when used as a return value
    @inlinable
    var returnTypeName: String {
        let swiftRef = swiftReturnRef
        let name = swiftRef.fullTypeName
        guard typeRef.type === swiftRef.type && (isScalarArray || swiftRef.indirectionLevel > 0) else { return name }
        let code = (isScalarArray ? "[" : "") + name + (isScalarArray ? "]" : "")
        return code
    }

    /// explicit, idiomatic type reference (struct if pointer to record)
    @inlinable var idiomaticWrappedRef: TypeReference {
        guard let record = knownRecordReference else {
            guard typeRef.knownIndirectionLevel == 0, let optionSet = knownBitfield else {
                return swiftReturnRef
            }
            return optionSet.typeRef
        }
        return record.structRef
    }

    /// explicit, idiomatic type reference (class if pointer to record)
    @inlinable var idiomaticClassRef: TypeReference {
        guard let record = knownRecordReference else {
            guard typeRef.knownIndirectionLevel == 0, let optionSet = knownBitfield else {
                return swiftReturnRef
            }
            return optionSet.typeRef
        }
        return record.classRef
    }

    /// explicit, idiomatic type name (empty if same as the underlying C type)
    @inlinable var idiomaticWrappedTypeName: String {
        let ref = idiomaticWrappedRef
        guard ref == swiftReturnRef else { return ref.type.swiftName }
        guard ref != typeRef else { return "" }
        let typeName = swiftReturnRef.fullTypeName
        return typeName
    }

    /// explicit, idiomatic class type name (empty if same as the underlying C type)
    @inlinable var idiomaticClassTypeName: String {
        let ref = idiomaticClassRef
        guard ref == swiftReturnRef else { return ref.type.swiftName }
        guard ref != typeRef else { return "" }
        let typeName = swiftReturnRef.fullTypeName
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
    @inlinable func returnTypeName(for record: GIR.Record? = nil, beingIdiomatic: Bool = true, useStruct: Bool = true) -> String {
        let idiomaticName = idiomaticWrappedTypeName
        let ref = typeRef
        let pointers = ref.knownIndirectionLevel
        let typeName = ref.type.name
        let dottedPrefix = typeName.dottedPrefix
        let name: String
        if pointers == 1, let knownRecord = GIR.knownRecords[typeName] {
            let knownRef = useStruct ? knownRecord.structRef : (beingIdiomatic ? knownRecord.classRef : knownRecord.typeRef)
            name = knownRef.forceUnwrappedName
        } else if pointers == 0, let optionSet = knownBitfield {
            name = optionSet.typeRef.fullSwiftTypeName
        } else {
            name = beingIdiomatic && !idiomaticName.isEmpty ? idiomaticName : ref.fullTypeName
        }
        let prefixedName: String
        if dottedPrefix.isEmpty || name.firstIndex(of: ".") != nil {
            prefixedName = name
        } else {
            prefixedName = dottedPrefix + name
        }
        let normalisedName = prefixedName.withNormalisedPrefix
        if (typeRef.isOptional || maybeOptional(for: record) || name.maybeCallback) && !name.hasSuffix("?") && !name.hasSuffix("!") {
            return normalisedName + "!"
        } else {
            return normalisedName
        }
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
    /// return the swift (known) type of the receiver when passed as an argument
    @inlinable
    var argumentTypeName: String {
        let swiftRef = swiftParamRef
        let name = swiftRef.fullUnderlyingTypeName.withNormalisedPrefix
        guard typeRef.type === swiftRef.type && (isScalarArray || swiftRef.indirectionLevel > 0) else {
            let optionalName = ((isNullable || isOptional) && !(name.hasSuffix("!") || name.hasSuffix("?"))) ? (name + "!") : name
            return optionalName
        }
        let code = (isScalarArray ? "inout [" : "") + name + (isScalarArray ? "]" : "")
        return code
    }

    /// return the swift (known) type of the receiver when passed as an argument
    /// for a `@convention(c)` callback
    @inlinable
    var callbackArgumentTypeName: String {
        let ref = typeRef
        let rawName = ref.type.typeName == GIR.errorT ? ref.fullUnderlyingCName : ref.fullUnderlyingTypeName
        let name = rawName.withNormalisedPrefix
        guard typeRef.indirectionLevel != 0 && !name.hasSuffix("?") else { return name }
        let optionalName: String
        if name.hasSuffix("!") {
            let s = name.startIndex
            let e = name.index(before: name.endIndex)
            optionalName = name[s..<e] + "?"
        } else {
            optionalName = name + "?"
        }
        return optionalName
    }

    /// Return a Swift template declaration for a known record that is non-nullable,
    /// or `nil` otherwise
    @inlinable
    var nonNullableTemplateDecl: String? {
        guard !(isNullable && allowNone) && isKnownRecordReference else {
            return nil
        }
        return templateDecl
    }

    /// return the swift (known) type of the receiver when passed as an argument
    /// Returns a template name in case of a known record
    @inlinable
    var templateTypeName: String {
        guard let record = knownRecordReference else {
            guard typeRef.knownIndirectionLevel == 0, let optionSet = knownBitfield else {
                return argumentTypeName
            }
            return optionSet.escapedName.swift
        }
        let templateName = record.className + "T"
        let typeName = isNullable ? (templateName + "?") : templateName
        return typeName
    }

    /// return the swift (known) type of the receiver when passed as an argument
    /// Returns a reference name in case of a known record with a default value
    @inlinable
    var defaultRefTemplateTypeName: String {
        guard let record = knownRecordReference else {
            guard typeRef.knownIndirectionLevel == 0, let optionSet = knownBitfield else {
                return argumentTypeName
            }
            return optionSet.escapedName.withNormalisedPrefix.swift
        }
        let templateName: String
        if allowNone {
            let className = record.className
            let protocolName = record.structName
            let typeName = typeRef.type.name
            let prefix = typeName.girDottedPrefix
            if GIR.dottedPrefix != prefix && typeName.hasSuffix(className) {
                templateName = prefix + protocolName
            } else {
                templateName = protocolName
            }
        } else {
            templateName = record.className + "T"
        }
        let typeName = isNullable ? (templateName + "?") : templateName
        return typeName
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
