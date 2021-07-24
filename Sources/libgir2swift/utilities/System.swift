//
//  System.swift
//  libgir2swift
//
//  Created by Rene Hexel on 18/7/21.
//  Copyright © 2021 Rene Hexel. All rights reserved.
//
import Foundation

/// A protocol that covers file handles, pipes, sockets, etc.
protocol IOHandle {}

extension Pipe: IOHandle {}
extension FileHandle: IOHandle {}

/// A structure representing a shell comand and its arguments
struct CommandArguments {
    /// Name of the shell comand
    var command: String
    /// Arguments to pass to the shell command
    var arguments: [String]
}

/// Return the current working directory
/// - Returns: Upon successful completion, a string containing the pathname is returned.
func getcwd() -> String? {
    guard let dir = getcwd(nil, 0) else { return nil }
    defer { free(dir) }
    let wd = String(cString: dir)
    return wd
}

/// Search for an executable in the path
/// - Parameters:
///   - executable: The executable to search for
///   - path: The array of directories to search in (defaults to the contents of the `PATH` environment variable)
/// - Returns: a `URL` representing the full path of the executable if successful, `nil` otherwise
func urlForExecutable(named executable: String, in path: [String] = ProcessInfo.processInfo.environment["PATH"].map { $0.split(separator: ":").map(String.init) } ?? []) -> URL? {
    guard let wd = getcwd().map(URL.init(fileURLWithPath:)) else { return nil }
    let fm = FileManager.default
    for url in path.map({ URL(string: $0, relativeTo: wd) ?? URL(fileURLWithPath: $0) }) {
        let file = url.appendingPathComponent(executable, isDirectory: false)
        #if os(macOS)
        var directory = ObjCBool(false)
        if fm.fileExists(atPath: file.path, isDirectory: &directory), !directory.boolValue,
           fm.isExecutableFile(atPath: file.path) {
            return file
        }
        #else
        if fm.isExecutableFile(atPath: file.path) {
            return file
        }
        #endif
    }
    return nil
}


/// Create a process to execute the given command
/// - Parameters:
///   - command: the name of the executable to run
///   - path: The array of directories to search in (defaults to the contents of the `PATH` environment variable)
///   - arguments: the arguments to pass to the command
///   - standardInput: the pipe to redirect standard input from if not `nil`
///   - standardOutput: the pipe to redirect standard output to if not `nil`
///   - standardError: the pipe to redirect standard error to if not `nil`
/// - Throws: an error if the command cannot be run
/// - Returns: The process being executed.  Call `run()` and then `waitUntilExit()` on the process to collect its `terminationStatus`
func createProcess(command: String, in path: [String] = ProcessInfo.processInfo.environment["PATH"].map { $0.split(separator: ":").map(String.init) } ?? [], arguments: [String] = [], standardInput: Any? = nil, standardOutput: Any? = nil, standardError: Any? = nil) throws -> Process {
    guard let url = urlForExecutable(named: command, in: path) else {
        throw POSIXError(.ENOENT)
    }
    let process = Process()
    if !arguments.isEmpty { process.arguments = arguments }
    if let stdin  = standardInput  { process.standardInput  = stdin  }
    if let stdout = standardOutput { process.standardOutput = stdout }
    if let stderr = standardError  { process.standardError  = stderr }
    if #available(macOS 10.13, *) {
        process.executableURL = url
    } else {
        process.launchPath = url.path
    }
    return process
}

/// Run a pipeline of executables
/// - Parameter components: an array commands and associated arguments to execute
/// - Throws: an error if any of the commands cannot be run
/// - Returns: an array of processes being executed
func pipe<Input: IOHandle, Output: IOHandle>(_ components: [CommandArguments], in path: [String] = ProcessInfo.processInfo.environment["PATH"].map { $0.split(separator: ":").map(String.init) } ?? [], input: Input? = nil, output: Output? = nil) throws -> [Process] {
    let pipes: [Any?] = components.enumerated().map { $0.offset == 0 ? input : Pipe() as Any? } + [output]
    let processes = try components.enumerated().map {
        try createProcess(command: $0.element.command, in: path, arguments: $0.element.arguments, standardInput: pipes[$0.offset], standardOutput: pipes[$0.offset+1])
    }
    if #available(macOS 10.13, *) {
        try processes.forEach { try $0.run() }
    } else {
        processes.forEach { $0.launch() }
    }
    return processes
}


/// Execute the given shell command
/// - Parameters:
///   - standardInput: the pipe to redirect standard input from if not `nil`
///   - standardOutput: the pipe to redirect standard output to if not `nil`
///   - standardError: the pipe to redirect standard error to if not `nil`
///   - command: the name of the executable to run
///   - arguments: the arguments to pass to the command
/// - Returns: `nil` if the program cannot be run, the program's termination status otherwise
@discardableResult
func run(standardInput: Any? = nil, standardOutput: Any? = nil, standardError: Any? = nil, _ command: String, arguments: [String]) -> Int? {
    do {
        let process = try createProcess(command: command, arguments: arguments)
        if #available(macOS 10.13, *) {
            try process.run()
        } else {
            process.launch()
        }
        process.waitUntilExit()
        return Int(process.terminationStatus)
    } catch {
        perror("Cannot run \(command)")
        return nil
    }
}

/// Execute the given shell command and test its return value
/// - Parameters:
///   - standardInput: the pipe to redirect standard input from if not `nil`
///   - standardOutput: the pipe to redirect standard output to if not `nil`
///   - standardError: the pipe to redirect standard error to, or `/dev/null` if `nil`
///   - expectedResult: the expected return value of the shell command
///   - command: the name of the executable to run
///   - arguments: the arguments to pass to the command
/// - Returns: `true` if the shell command has suceeded (returned the expected result)
func test(standardInput: Any? = nil, standardOutput: Any? = nil, standardError: Any? = nil, expecting expectedResult: Int = 0, _ command: String, _ arguments: String...) -> Bool {
    let stderr: Any?
    if let se = standardError { stderr = se }
    else {
        stderr = FileHandle(forWritingAtPath: "/dev/null")
    }
    let rv = run(standardInput: standardInput, standardOutput: standardOutput, standardError: stderr, command, arguments: arguments)
    if standardError == nil, let se = stderr as? FileHandle {
        if #available(macOS 10.15, *) {
            try? se.close()
        } else {
            se.closeFile()
        }
    }
    return rv == expectedResult
}
