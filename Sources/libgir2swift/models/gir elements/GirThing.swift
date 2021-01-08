//
//  File.swift
//  
//
//  Created by Mikoláš Stuchlík on 17.11.2020.
//
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif
import SwiftLibXML

extension GIR {
    /// GIR named thing class
    public class Thing: Hashable, Comparable {
        /// String representation of the kind of `Thing` represented by the receiver
        public var kind: String { return "Thing" }
        /// type name without namespace/prefix
        public let name: String
        /// documentation for the `Thing`
        public let comment: String
        /// Is this `Thing` introspectable?
        public let introspectable: Bool
        /// Is this `Thing` disguised?
        public let disguised: Bool
        /// Alternative to use if deprecated
        public let deprecated: String?
        /// Is this `Thing` explicitly marked as deprecated?
        public let markedAsDeprecated: Bool
        /// Version the receiver is available from
        public let version: String?
        
        /// Hashes the essential components of this value by feeding them into the given hasher.
        ///
        /// This method is implemented to conform to the Hashable protocol.
        /// Calls hasher.combine(_:) with the name component.
        /// - Parameter hasher: The hasher to use when combining the components of the receiver.
        public func hash(into hasher: inout Hasher) {
            hasher.combine(name)
        }
        
        
        /// Comparator to check whether two `Thing`s are equal
        /// - Parameters:
        ///   - lhs: `Thing` to compare
        ///   - rhs: `Thing` to compare with
        public static  func ==(lhs: GIR.Thing, rhs: GIR.Thing) -> Bool {
            return lhs.name == rhs.name
        }

        /// Comparator to check the ordering of two `Thing`s
        /// - Parameters:
        ///   - lhs: first `Thing` to compare
        ///   - rhs: second `Thing` to compare
        public static func <(lhs: GIR.Thing, rhs: GIR.Thing) -> Bool {
            return lhs.name < rhs.name
        }
        
        /// type name without 'Private' suffix (nil if public)
        var priv: String? {
            return name.stringByRemoving(suffix: "Private")
        }
        /// Type name without 'Class', 'Iface', etc. suffix
        var node: String {
            let nodeName: String
            let privateSuffix: String
            if let p = priv {
                nodeName = p
                privateSuffix = "Private"
            } else {
                nodeName = name
                privateSuffix = ""
            }
            for s in ["Class", "Iface"] {
                if let n = nodeName.stringByRemoving(suffix: s) {
                    return n + privateSuffix
                }
            }
            return name
        }
        
        /// Memberwise initialiser
        /// - Parameters:
        ///   - name: The name of the `Thing` to initialise
        ///   - comment: Documentation text for the `Thing`
        ///   - introspectable: Set to `true` if introspectable
        ///   - disguised: Set to `true` if disguised
        ///   - deprecated: Documentation on deprecation status if non-`nil`
        ///   - markedAsDeprecated: Set to `true` if deprecated
        ///   - version: The version this `Thing` is first available in
        public init(name: String, comment: String, introspectable: Bool = true, disguised: Bool = false, deprecated: String? = nil, markedAsDeprecated: Bool = false, version: String? = nil) {
            self.name = name
            self.comment = comment
            self.introspectable = introspectable
            self.disguised = disguised
            self.deprecated = deprecated
            self.markedAsDeprecated = markedAsDeprecated
            self.version = version
        }
        
        /// XML Element initialser
        /// - Parameters:
        ///   - node: `XMLElement` to construct this `Thing` from
        ///   - index: Index within the siblings of the `node`
        ///   - nameAttr: Key for the attribute to extract the `name` property from
        public init(node: XMLElement, at index: Int, nameAttr: String = "name") {
            name = node.attribute(named: nameAttr) ?? "Unknown\(index)"
            let c = node.children.lazy
            let depr = node.bool(named: "deprecated")
            comment = GIR.docs(children: c)
            markedAsDeprecated = depr
            deprecated = GIR.deprecatedDocumentation(children: c) ?? ( depr ? "This method is deprecated." : nil )
            introspectable = (node.attribute(named: "introspectable") ?? "1") != "0"
            disguised = node.bool(named: "disguised")
            version = node.attribute(named: "version")
        }
    }
}
