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

    /// Return an idiomatic Swift name.
    ///
    /// This method returns the name in Swift-style camelCase.
    /// Before doing so, it checks whether the name is all uppercase,
    /// in which case it converts it to lowercase first.
    @inlinable var swiftCamelCaseName: String {
        let normalisedName: String
        if name == name.uppercased() {
            normalisedName = name.lowercased()
        } else {
            normalisedName = name
        }
        return normalisedName.snakeCase2camelCase
    }

    /// Return an idiomatic, de-uppercased Swift name.
    ///
    /// This method returns the name in Swift-style camelCase.
    /// Before doing so, it checks whether the name is all uppercase,
    /// in which case it converts it to lowercase first.
    @inlinable var swiftCamelCASEName: String {
        let normalisedName: String
        if name == name.uppercased() {
            normalisedName = name.lowercased()
        } else {
            normalisedName = name
        }
        return normalisedName.snakeCASE2camelCase
    }
}


/// Swift extension for arguments
public extension GIR.CType {
    /// return the, potentially prefixed argument name to use in a method declaration
    @inlinable
    var prefixedArgumentName: String {
        let (prefix, arg) = name.argumentSplit
        let noPrefix = prefix.isEmpty
        let argName = arg.snakeCase2camelCase.swiftQuoted
        let label = prefix.snakeCase2camelCase.swiftQuoted
        let prefixedname = noPrefix || label == argName ? argName : (label + " " + argName)
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
        var ref: TypeReference? = typeRef
        while let currentRef = ref {
            if var replacement = GIR.swiftParameterTypeReplacements[currentRef] {
                replacement.isConst = currentRef.isConst || typeRef.isConst
                replacement.isOptional = currentRef.isOptional || typeRef.isOptional
                return replacement
            }
            ref = currentRef.type.isAlias ? currentRef.type.parent : nil
            if ref?.indirectionLevel != currentRef.indirectionLevel { ref = nil }
        }
        return typeRef
    }

    /// Type reference to an idiomatic Swift type used for a Swift function return value
    @inlinable
    var swiftReturnRef: TypeReference {
        var ref: TypeReference? = typeRef
        while let currentRef = ref {
            if var replacement = GIR.swiftReturnTypeReplacements[currentRef] {
                replacement.isConst = currentRef.isConst || typeRef.isConst
                replacement.isOptional = currentRef.isOptional || typeRef.isOptional
                return replacement
            }
            ref = currentRef.type.isAlias ? currentRef.type.parent : nil
            if ref?.indirectionLevel != currentRef.indirectionLevel { ref = nil }
        }
        if typeRef.indirectionLevel == 1 && typeRef.type.typeName.hasSuffix("char") && !typeRef.type.typeName.hasSuffix("unichar") {
            return GIR.stringRef
        }
        return typeRef
    }

    /// Type reference to an idiomatic Swift type used for a Swift signals. This property is copy of `swiftReturnRef` with a different domain. The domain for this property was modified to include support for unsigned ints.
    @inlinable
    var swiftSignalRef: TypeReference {
        var ref: TypeReference? = typeRef
        while let currentRef = ref {
            if var replacement = GIR.swiftSignalTypeReplacements[currentRef] {
                replacement.isConst = currentRef.isConst || typeRef.isConst
                replacement.isOptional = currentRef.isOptional || typeRef.isOptional
                return replacement
            }
            ref = currentRef.type.isAlias ? currentRef.type.parent : nil
            if ref?.indirectionLevel != currentRef.indirectionLevel { ref = nil }
        }
        if typeRef.indirectionLevel == 1 && typeRef.type.typeName.hasSuffix("char") && !typeRef.type.typeName.hasSuffix("unichar") {
            return GIR.stringRef
        }
        return typeRef
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
        let prefix = typeRef.type.dottedPrefix
        let normalisedPrefix = prefix.asNormalisedPrefix
        let templateName: String
        let protocolTypeName: String
        if GIR.dottedPrefix != prefix && GIR.dottedPrefix != normalisedPrefix && typeName.hasSuffix(record.name) {
            protocolTypeName = normalisedPrefix + protocolName
            templateName = typeRef.type.namespace + className.capitalised
        } else {
            protocolTypeName = protocolName
            templateName = className
        }
        return templateName + "T: " + protocolTypeName
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
            return swiftReturnRef
        }
        return record.structRef
    }

    /// Return a prefixed version of the wrapped type reference
    @inlinable var prefixedIdiomaticWrappedRef: TypeReference {
        guard let record = knownRecordReference else {
            return swiftReturnRef
        }
        return prefixed(ref: record.structRef)
    }

    /// Return a prefixed ref for a given TypeReference.
    /// - Parameter ref: The type reference in question.
    /// - Returns: A prefixed version of the typereference (inchanged if `namespace` wasn't empty).
    @inlinable
    func prefixed(ref: TypeReference) -> TypeReference {
        let type = ref.type
        guard type.namespace.isEmpty else { return ref }
        let namespace = typeRef.type.namespace.asNormalisedPrefix
        guard !namespace.isEmpty else { return ref }
        let prefixedType = GIRType(name: type.name, in: namespace, swiftName: type.swiftName, typeName: type.typeName, ctype: type.ctype, superType: type.parent, isAlias: type.isAlias, conversions: type.conversions)
        let prefixedRef = TypeReference(type: prefixedType, in: namespace, identifier: ref.identifier, isConst: ref.isConst, isOptional: ref.isOptional, isArray: ref.isArray, constPointers: ref.constPointers)
        return prefixedRef
    }

    /// Explicit, idiomatic type reference (class if pointer to record)
    @inlinable var idiomaticClassRef: TypeReference {
        guard let record = knownRecordReference else {
            return swiftReturnRef
        }
        return record.classRef
    }

    /// Return a prefixed version of the idiomatic class type reference
    @inlinable var prefixedIdiomaticClassRef: TypeReference {
        prefixed(ref: idiomaticClassRef)
    }

    /// explicit, idiomatic type name (empty if same as the underlying C type)
    @inlinable var idiomaticWrappedTypeName: String {
        let ref = idiomaticWrappedRef
        guard ref == swiftReturnRef else { return ref.type.swiftNamePrefixedWhereNecessary }
        guard ref != typeRef else { return "" }
        let typeName = swiftReturnRef.fullTypeName
        return typeName
    }

    /// explicit, idiomatic type name (empty if same as the underlying C type)
    @inlinable var prefixedIdiomaticWrappedTypeName: String {
        let ref = prefixedIdiomaticWrappedRef
        guard ref == swiftReturnRef else { return ref.type.swiftNamePrefixedWhereNecessary }
        guard ref != typeRef else { return "" }
        let typeName = swiftReturnRef.fullTypeName
        return typeName
    }

    /// explicit, idiomatic class type name (empty if same as the underlying C type)
    @inlinable var idiomaticClassTypeName: String {
        let ref = idiomaticClassRef
        guard ref == swiftReturnRef else { return ref.type.swiftNamePrefixedWhereNecessary }
        guard ref != typeRef else { return "" }
        let typeName = swiftReturnRef.fullTypeName
        return typeName
    }

    /// explicit, idiomatic class type name (empty if same as the underlying C type)
    @inlinable var prefixedIdiomaticClassTypeName: String {
        let ref = prefixedIdiomaticClassRef
        guard ref == swiftReturnRef else { return ref.type.swiftNamePrefixedWhereNecessary }
        guard ref != typeRef else { return "" }
        let typeName = swiftReturnRef.fullTypeName
        return typeName
    }

    /// Check whether the return type may need to be optional,
    /// e.g. when derived from a pointer that may be `nil`
    /// - Parameter record: The record the receiver is associated with.
    /// - Returns: `true` if this may be an optional.
    @inlinable
    func maybeOptional(for record: GIR.Record? = nil) -> Bool {
        let isPointer = isAnyKindOfPointer
        guard let record = record else { return isPointer }
        return isInstanceOfHierarchy(record)
    }

    /// return the idiomatic/non-idiomatic return type name
    /// - Parameters:
    ///   - record: The record this belongs to (`nil`, if this is a return type of a freestanding function).
    ///   - beingIdiomatic: Whether to create idiomatic Swift.
    ///   - useStruct: Whether to use the corresponding `Ref` struct as the return type,
    /// - Returns: The Swift code corresponding to the return type.
    @inlinable
    func returnTypeName(for record: GIR.Record? = nil, beingIdiomatic: Bool = true, useStruct: Bool = true) -> String {
        let idiomaticName = prefixedIdiomaticWrappedTypeName
        let ref = typeRef
        let pointers = ref.knownIndirectionLevel
        let underlyingType = ref.type
        let prefixedTypeName = ref.type.prefixedName
        let name: String
        if pointers == 1, let knownRecord = GIR.knownRecords[prefixedTypeName] ?? GIR.knownRecords[ref.type.name] {
            let knownRef = useStruct ? knownRecord.structRef : (beingIdiomatic ? knownRecord.classRef : knownRecord.typeRef)
            let unwrappedName = knownRef.forceUnwrappedName
            let unprefixedName: String
            if !isInstanceOf(record),
               let typedColl = typedCollection(for: prefixedTypeName, containedTypes: containedTypes, unwrappedName: unwrappedName, typeRef: knownRef) {
                unprefixedName = typedColl.type.name
                name = typedColl.type.swiftName
            } else {
                unprefixedName = unwrappedName
                if useStruct || beingIdiomatic {
                    let dottedPrefix = prefixedTypeName.dottedPrefix
                    if dottedPrefix.isEmpty || dottedPrefix == GIR.dottedPrefix || unprefixedName.firstIndex(of: ".") != nil {
                        name = unprefixedName
                    } else {
                        name = dottedPrefix + unprefixedName
                    }
                } else {
                    name = unprefixedName
                }
            }
        } else if pointers == 0 && isKnownBitfield {
            name = prefixedTypeName
        } else {
            name = beingIdiomatic && !idiomaticName.isEmpty ? idiomaticName : ref.fullUnderlyingTypeName(asOptional: underlyingType.isGPointer)
        }
        let normalisedName = name.withNormalisedPrefix
        if (typeRef.isOptional || ((self as? GIR.Argument)?.maybeOptional() ?? false) || maybeOptional(for: record) || name.maybeCallback) && !name.isOptional {
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
        let name = swiftRef.fullUnderlyingTypeName(asOptional: containsGPointer ? true : nil).withNormalisedPrefix
        let type = typeRef.type
        guard type === swiftRef.type && (isScalarArray || swiftRef.indirectionLevel > 0) else {
            guard typeRef.knownIndirectionLevel != 0 || !isKnownBitfield else {
                return type.namePrefixedWhereNecessary.swift
            }
            let optionalName = ((isNullable || isOptional) && !name.isOptional) ? (name + "!") : name
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
        let rawName = ref.type.typeName == GIR.errorT ? ref.fullUnderlyingCName : ref.fullUnderlyingTypeName()
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
            return argumentTypeName
        }
        let typeName = optionalIfNullable(templateName(for: record))
        return typeName
    }

    /// return the swift (known) type of the receiver when passed as an argument
    /// Returns a reference name in case of a known record with a default value
    @inlinable
    var defaultRefTemplateTypeName: String {
        guard let record = knownRecordReference else {
            return argumentTypeName
        }
        let templateName: String
        if allowNone {
            templateName = record.structNamePrefixedIfNecessary
        } else {
            templateName = self.templateName(for: record)
        }
        let typeName = optionalIfNullable(templateName)
        return typeName
    }

    /// Return the name of a templated type correspondingg to a given record
    /// - Note this gets prefixed if the record is in a different namespace
    /// - Parameter record: A record for which to create a template name
    /// - Returns: A string representing a template type for the given record
    @inlinable
    func templateName(for record: GIR.Record) -> String {
        let className = record.className
        let prefix = typeRef.type.dottedPrefix
        let normalisedPrefix = prefix.asNormalisedPrefix
        let templatePrefix: String
        if GIR.dottedPrefix != prefix && GIR.dottedPrefix != normalisedPrefix {
            templatePrefix = typeRef.type.namespace + className.capitalised
        } else {
            templatePrefix = className
        }
        let templateName = templatePrefix + "T"
        return templateName
    }

    /// Append a question mark if the receiver is nullable
    /// - Parameter templateName: The string to optionally turn into an optional
    /// - Returns: The original string, with or without a `?` appended
    @inlinable func optionalIfNullable(_ typeName: String) -> String {
        let typeName = isNullable ? (typeName + "?") : typeName
        return typeName
    }

    /// Append a question mark if the receiver is nullable or optionial
    /// - Parameter templateName: The string to optionally turn into an optional
    /// - Returns: The original string, with or without a `?` appended
    @inlinable func optionalIfNullableOrOptional(_ typeName: String) -> String {
        let typeName = isNullable || isOptional ? (typeName + "?") : typeName
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

    /// Return the name of the `Ref` struct type correspondingg to the receiver
    /// - Note this gets prefixed if the record is in a different namespace
    @inlinable
    var structNamePrefixedIfNecessary: String {
        let name = typeRef.type.prefixedWhereNecessary(structName)
        return name
    }
}
