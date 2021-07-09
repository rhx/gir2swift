import Foundation

/// Swift code representation of a record
public struct SwiftCode {
    let funcs: [GIR.Function] 

    public func swiftCode(ptrName: String, record r: GIR.Record) -> String {
        let cl = r as? GIR.Class
        let ctype = r.typeRef.type.ctype
        let parents = [
            cl?.parent.protocolName.withNormalisedPrefix ?? r.parentType?.protocolName.withNormalisedPrefix ?? "",
            ctype == GIR.gerror ? GIR.errorProtocol.name : ""
        ].filter { !$0.isEmpty } + r.implements.filter {
            !(r.parentType?.implements.contains($0) ?? false)
        }.map { $0.protocolName.withNormalisedPrefix }
        let p = recordProtocolCode(r, parent: parents.joined(separator: ", "), ptr: ptrName)
        let s = recordStructCode(r, ptr: ptrName)

        // In case we are sure this record represents Class Metatype, return uninstantiable type
        var instanceTypeDescriptor = ""
        var classDefinition = ""
        if let instantiable = r.classInstanceType, instantiable.typegetter != nil {
            instanceTypeDescriptor = buildClassTypeDeclaration(for: r, classInstance: instantiable) + "\n\n"
        } else {
            classDefinition = recordClassCode(r, parent: cl?.parent.withNormalisedPrefix ?? "", ptr: ptrName)
        }
        
        let e = recordProtocolExtensionCode(funcs, r, ptr: ptrName)
        let code = instanceTypeDescriptor + p + s + classDefinition + e
        return code
    }
}
