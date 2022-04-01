#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

@usableFromInline
enum Streams {
    /// Abstraction for stderr, calling fputs under the hood.
    @usableFromInline
    static var stdErr: StandardError = StandardError()

    /// Abstraction for stdErr
    @usableFromInline
    struct StandardError: TextOutputStream {
        @usableFromInline
        mutating func write(_ string: String) {
            fputs(string, stderr)
        }
    }
}

