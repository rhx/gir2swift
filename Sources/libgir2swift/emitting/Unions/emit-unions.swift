import Foundation

/// Return a unions-to-swift conversion closure for the array of functions passed in
public func swiftUnionsConversion(_ funcs: [GIR.Function], u: GIR.Union) -> String {
    let ptrName = u.ptrName
    let ctype = u.typeRef.type.ctype
    let parents = [ u.parentType?.protocolName ?? "", ctype == GIR.gerror ? GIR.errorProtocol.name : "" ].filter { !$0.isEmpty } +
        u.implements.filter { !(u.parentType?.implements.contains($0) ?? false) }.map { $0.protocolName }
    let p = recordProtocolCode(u, parent: parents.joined(separator: ", "), ptr: ptrName)
    let s = recordStructCode(u, ptr: ptrName)
    let c = recordClassCode(u, parent: "", ptr: ptrName)
    let e = recordProtocolExtensionCode(funcs, u, ptr: ptrName)
    let code = p + s + c + e
    return code
}
