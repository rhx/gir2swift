//
//  gir+swift.swift
//  gir2swift
//
//  Created by Rene Hexel on 2/04/2016.
//  Copyright © 2016, 2017, 2018, 2019, 2020, 2021 Rene Hexel. All rights reserved.
//
import Foundation

public extension GIR {
    /// code boiler plate
    var boilerPlate: String {
        return """

               extension gboolean {
                   private init(_ b: Bool) { self = b ? gboolean(1) : gboolean(0) }
               }

               func asStringArray(_ param: UnsafePointer<UnsafePointer<CChar>?>) -> [String] {
                   var ptr = param
                   var rv = [String]()
                   while ptr.pointee != nil {
                       rv.append(String(cString: ptr.pointee!))
                       ptr = ptr.successor()
                   }
                   return rv
               }

               func asStringArray<T>(_ param: UnsafePointer<UnsafePointer<CChar>?>, release: ((UnsafePointer<T>?) -> Void)) -> [String] {
                   let rv = asStringArray(param)
                   param.withMemoryRebound(to: T.self, capacity: rv.count) { release(UnsafePointer<T>($0)) }
                   return rv
               }

               """
    }
}


/// a pair of getters and setters (both cannot be nil at the same time)
public struct GetterSetterPair {
    let getter: GIR.Method
    let setter: GIR.Method?
}

/// constant for "i" as a code unit
let iU = "i".utf8.first!
/// constant for "_" as a code unit
let _U = "_".utf8.first!

extension GetterSetterPair {
    /// name of the underlying property for a getter / setter pair
    var name: String {
        let n = getter.name.utf8 
        let o = n.first == iU ? 0 : 4;  // no offset for "is_..."

        // convert the remainder to camel case
        var s = n.index(n.startIndex, offsetBy: o)
        let e = n.endIndex
        var name = String()
        var i = s
        while i < e {
            var j = n.index(after: i)
            if n[i] == _U {
                if let str = String(n[s..<i]) {
                    name += str
                    s = i
                }
                i = j
                guard i < e else { break }
                j = n.index(after: i)
                if let u = String(n[i..<j])?.unicodeScalars.first, u.isASCII {
                    let c = Int32(u.value)
                    if let upper = UnicodeScalar(UInt16(toupper(c))), islower(c) != 0 {
                        name += String(Character(upper))
                        s = j
                    } else {
                        s = i
                    }
                } else {
                    s = i
                }
            }
            i = j
        }
        if let str = String(n[s..<e]) { name += str }
        return name
    }
}

/// return setter/getter pairs from a list of methods
public func getterSetterPairs(for allMethods: [GIR.Method]) -> [GetterSetterPair] {
    let gettersAndSetters = allMethods.filter{ $0.isGetter || $0.isSetter }.sorted {
        let u = $0.name.utf8
        let v = $1.name.utf8
        let o = u.first == iU ? 0 : 4;  // no offset for "is_..."
        let p = v.first == iU ? 0 : 4;
        let a = u[u.index(u.startIndex, offsetBy: o)..<u.endIndex]
        let b = v[v.index(v.startIndex, offsetBy: p)..<v.endIndex]
        return String(Substring(a)) <= String(Substring(b))
    }
    var pairs = Array<GetterSetterPair>()
    pairs.reserveCapacity(gettersAndSetters.count)
    var i = gettersAndSetters.makeIterator()
    var b = i.next()
    while let a = b {
        b = i.next()
        if a.isGetter {
            guard let s = b, s.isSetterFor(getter: a.name) else { pairs.append(GetterSetterPair(getter: a, setter: nil)) ; continue }
            pairs.append(GetterSetterPair(getter: a, setter: s))
        } else {    // isSetter
            guard let g = b, g.isGetterFor(setter: a.name) else { continue }
            pairs.append(GetterSetterPair(getter: g, setter: a))
        }
        b = i.next()
    }
    return pairs
}

/// GIR extension for Strings
public extension String {
    /// indicates whether the receiver is a known type
    @inlinable
    var isKnownType: Bool { return GIR.knownDataTypes[self] != nil }

    /// swift protocol name for a given string
    /// Name of the Protocol for this record
    @inlinable
    var protocolName: String { return isEmpty ? self : (self + "Protocol") }

    /// Type name without namespace prefix
    @inlinable
    var withoutDottedPrefix: String {
        guard !hasPrefix(GIR.dottedPrefix) else {
            return components(separatedBy: ".").last ?? self
        }
        return self
    }

    /// Full type name with namespace prefix normalised
    @inlinable var withNormalisedPrefix: String {
        guard let d = firstIndex(of: ".") else { return self }
        let p = self[startIndex...d]
        guard !p.isEmpty, let prefix = GIR.namespaceReplacements[p] else { return self }
        let s = index(after: d)
        let e = endIndex
        return String(prefix + self[s..<e])
    }

    /// Dotted prefix with namespace replacements
    @inlinable var girDottedPrefix: Substring {
        let prefix = dottedPrefix
        guard let replacement = GIR.namespaceReplacements[prefix] else {
            return prefix
        }
        return replacement
    }
}


/// SwiftDoc representation of comments
public func commentCode(_ thing: GIR.Thing, indentation: String = "") -> String {
    let prefix = indentation + "/// "
    let comment = thing.comment
    let documentation = gtkDoc2SwiftDoc(comment, linePrefix: prefix)
    return documentation
}

/// Swift representation of deprecation
public func deprecatedCode(_ thing: GIR.Thing, indentation: String) -> String? {
    return thing.deprecated.map { (s: String) -> String in
        let prefix = indentation + "/// "
        return s.isEmpty ? "" : s.reduce(prefix) {
            $0 + ($1 == "\n" ? "\n" + prefix : String($1))
        }
    }
}

// MARK: - default Swift code for things

/// Swift code representation with code following the comments
public func swiftCode(_ thing: GIR.Thing, _ postfix: String = "", indentation: String = "") -> String {
    let s = commentCode(thing, indentation: indentation)
    let t: String
    if let d = deprecatedCode(thing, indentation: indentation) {
        t = s + "\n\(indentation)///\n\(indentation)/// **\(thing.name) is deprecated:**\n" + d + "\n"
    } else {
        t = s
    }
    return t + ((t.isEmpty || t.hasSuffix("\n")) ? "" : "\n") + postfix
}
