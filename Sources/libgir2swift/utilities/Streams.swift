#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

enum Streams {
    /// Abstraction for stderr, calling fputs under the hood.
    static var stdErr: StandardError = StandardError()

    /// Abstraction for stdErr
    struct StandardError: TextOutputStream {
        mutating func write(_ string: String) {
            fputs(string, stderr)
        }
    }
}

