# gir2swift

A command-line tool that converts GObject Introspection (GIR) XML files into Swift wrapper code.

## Overview

`gir2swift` reads gobject-introspection XML (`.gir`) files and generates the corresponding Swift source files that wrap the underlying C types and functions. It is the primary tool used to build Swift bindings for GLib-based libraries such as GTK, GLib, GIO, and Pango.

Normally `gir2swift` is invoked automatically via the <doc://gir2swift_plugin/documentation/gir2swift_plugin> build tool plugin. You can also call it directly from the command line for debugging or when working outside of a SwiftPM project.

The command is implemented by `Gir2Swift` in the `libgir2swift` library.

### Basic workflow

1. Install the prerequisites — a Swift toolchain (5.6+), `libxml2`, and `gobject-introspection` with its `.gir` files.
2. Add `gir2swift` and the `gir2swift-plugin` to your `Package.swift`.
3. Create a `gir2swift-manifest.yaml` in your package or target directory.
4. Run `swift build`; the plugin invokes `gir2swift` and places the generated Swift files in the plugin work directory.
5. If the build fails, add post-processing scripts (`.sed`, `.awk`) to patch the generated output.

### Synopsis

```
gir2swift [<options>] [<gir-files> ...]
```

### Options summary

| Option | Description |
|--------|-------------|
| `-v` | Produce verbose output |
| `-a` | Generate wrappers for all C types, including private ones |
| `--alpha-names` | Write output into a fixed set of files named `A`–`Z` |
| `-d` | Base path for hosting DocC documentation |
| `-e` | Add an extension namespace |
| `-n` | Add a namespace |
| `-s` | Write one `.swift` file per class |
| `--post-process` | Extra files to include in post-processing |
| `-p` | Add a prerequisite `.gir` file |
| `-o` | Output directory for generated files |
| `-t` | Target source directory (for manifest and configuration lookup) |
| `-w` | Working directory to `chdir` into before processing |
| `--pkg-config-name` | Library name to pass to `pkg-config` |
| `-m` | Hand-crafted boilerplate `.swift` file for the module |
| `--overwrite` | Force regeneration even when outputs are newer than inputs |
| `--manifest` | Path to the manifest file (default: `gir2swift-manifest.yaml`) |
| `--opaque-declarations` | Print opaque struct declarations to stdout and exit |

### Manifest file

The manifest is a YAML file that configures `gir2swift` for a specific target:

```yaml
version: 1
gir-name: GLib-2.0
pkg-config: glib-2.0
output-directory: Sources/GLib
alpha-names: true
```

Options supplied on the command line take precedence over values in the manifest.

### Module files

In addition to the `.gir` file, `gir2swift` reads a set of companion files whose names share the GIR base name:

| Extension | Purpose |
|-----------|---------|
| `.preamble` | Swift `import` statements prepended to every generated file |
| `.module` | Additional Swift code placed in the main generated file |
| `.exclude` | Newline-separated symbol names to suppress |
| `.include` | Newline-separated symbol names to force-include |
| `.verbatim` | Constants to copy verbatim rather than translate |
| `.callbackSuffixes` | Type-name suffixes treated as C callbacks |
| `.namespaceReplacements` | Tab-separated namespace substitution pairs |
| `.sed` | `sed` post-processing script |
| `.awk` | `awk` post-processing script |
| `.cat` | Swift fragment appended to the main generated file |

## Topics

### Related

- <doc://libgir2swift/documentation/libgir2swift>
- <doc://gir2swift_plugin/documentation/gir2swift_plugin>
