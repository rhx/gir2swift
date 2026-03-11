# ``libgir2swift``

The core library that parses GObject Introspection (GIR) XML and generates Swift wrapper code.

## Overview

`libgir2swift` implements the full GIR-to-Swift transformation pipeline. It is used by the `gir2swift` command-line tool and can be embedded in other tools that need to process `.gir` files programmatically.

The library is organised into three layers:

- **Models** — Swift types that mirror the GIR XML schema, plus the ``GIR`` document class and the ``Gir2Swift`` command structure.
- **Emitting** — Code-generation routines that turn parsed GIR models into Swift source text.
- **Utilities** — Helpers for planning, incremental generation, post-processing, and string manipulation.

### Parsing a GIR file

The central class is ``GIR``. Construct it by passing a memory buffer that contains the raw bytes of a `.gir` file:

```swift
import libgir2swift

let data = try Data(contentsOf: girURL, options: .alwaysMapped)
let gir: GIR? = data.withUnsafeBytes { bytes in
    GIR(buffer: bytes.bindMemory(to: CChar.self), quiet: false)
}
```

After construction, `gir` exposes typed collections for every GIR element kind: ``GIR/interfaces``, ``GIR/records``, ``GIR/unions``, ``GIR/classes``, ``GIR/functions``, ``GIR/callbacks``, and more.

### GIR element hierarchy

All GIR elements derive from ``GIR/Thing``. The inheritance hierarchy mirrors the GIR XML schema:

```
Thing
└── Datatype
    ├── CType
    │   ├── Alias
    │   ├── Constant
    │   ├── Argument
    │   ├── Property
    │   │   └── Field
    │   └── Record
    │       ├── Class
    │       │   └── Interface
    │       └── Union
    ├── Enumeration
    │   └── Bitfield
    └── Method
        ├── Function
        │   ├── Signal
        │   └── Callback
```

### Type system

``GIRType`` represents a resolved GIR type together with its Swift and C names, namespace, parent type, and the ``TypeConversion`` operations available to it. ``TypeReference`` tracks pointer levels and const qualifiers for a type used in a specific position (e.g., a function parameter or return value).

## Topics

### Command and configuration

- ``Gir2Swift``

### GIR document

- ``GIR``

### GIR element models

- ``GIR/Thing``
- ``GIR/Datatype``
- ``GIR/CType``
- ``GIR/Alias``
- ``GIR/Argument``
- ``GIR/Bitfield``
- ``GIR/Callback``
- ``GIR/Class``
- ``GIR/Constant``
- ``GIR/Enumeration``
- ``GIR/Field``
- ``GIR/Function``
- ``GIR/Interface``
- ``GIR/Method``
- ``GIR/Property``
- ``GIR/Record``
- ``GIR/Signal``
- ``GIR/Union``

### Type system

- ``GIRType``
- ``GIRStringType``
- ``GIRRawPointerType``
- ``GIRRecordType``
- ``GIRGenericType``
- ``GIROpaquePointerType``
- ``TypeConversion``
- ``CastConversion``
- ``StringConversion``
- ``SubClassConversion``
- ``OptionalSubClassConversion``
- ``CustomConversion``
- ``NestedConversion``
- ``EnumTypeConversion``
- ``BitfieldTypeConversion``
- ``RawPointerConversion``
- ``TypeReference``

### Related

- <doc://gir2swift/documentation/gir2swift>
- <doc://gir2swift_plugin/documentation/gir2swift_plugin>
