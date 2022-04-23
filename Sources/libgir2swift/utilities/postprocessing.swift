//
//  postprocessing.swift
//  libgir2swift
//
//  Created by Rene Hexel on 23/7/21.
//  Copyright © 2021, 2022 Rene Hexel. All rights reserved.
//

import Foundation

/// Post-process the output
/// - Parameters:
///   - node: Name of the gir node to post-process
///   - targetDirectoryURL: URL representing the target source directory containing the module configuration files
///   - pkgConfigName: Name of the library to pass to pkg-config
///   - outputString: The output string to post-process (if not empty)
///   - outputDirectory: The directory to output generated files in, `stdout` if `nil`
///   - outputFiles: The output files to post-process
func postProcess(_ node: String, for targetDirectoryURL: URL, pkgConfigName: String, outputString: String, outputDirectory: String?, outputFiles: Set<String>) {
    var pipeCommands = [CommandArguments]()
    let postProcessors = ["sed", "awk"]
    let fm = FileManager.default
    let cwd = fm.currentDirectoryPath
    let cwdURL = URL(fileURLWithPath: cwd)
    postProcessors.forEach {
        let script = node + "." + $0
        let scriptPath = targetDirectoryURL.appendingPathComponent(script).path
        if fm.fileExists(atPath: scriptPath) {
            pipeCommands.append(.init(command: $0, arguments: ["-f", scriptPath]))
        } else if fm.fileExists(atPath: script) {
            pipeCommands.append(.init(command: $0, arguments: ["-f", script]))
        }
    }
    let nodeFiles = ((try? fm.contentsOfDirectory(atPath: targetDirectoryURL.path)) ?? (try? fm.contentsOfDirectory(atPath: cwd)) ?? []).filter { $0.hasPrefix(node) }
    let cmds = postProcessors.flatMap { command in
        nodeFiles.filter {
            guard $0.hasSuffix("." + command), let i = $0.index($0.startIndex, offsetBy: node.count, limitedBy: $0.endIndex), let e = $0.index($0.endIndex, offsetBy: -(command.count+1), limitedBy: $0.startIndex) else { return false }
            let j = $0.index(after: i)
            let k = $0.index(after: j)
            let arg: String
            if $0[i] == "-" && $0[j].isDigit {
                arg = "--atleast-version=" + $0[j..<e]
            } else if $0[i...j] == ">=" && $0[k].isDigit {
                arg = "--atleast-version=" + $0[k..<e]
            } else if $0[i...j] == "<=" && $0[k].isDigit {
                arg = "--max-version=" + $0[k..<e]
            } else if $0[i] == "=" && $0[j].isDigit {
                arg = "--exact-version=" + $0[j..<e]
            } else if $0[i...j] == "==" && $0[k].isDigit {
                arg = "--exact-version=" + $0[k..<e]
            } else {
                return false
            }
            let result = test("pkg-config", arg, pkgConfigName)
            return result
        }.map { (f: String) -> CommandArguments in
            let d = f.lastIndex(of: ".") ?? f.index(f.endIndex, offsetBy: -4)
            let s = f.index(after: d)
            let script = targetDirectoryURL.appendingPathComponent(f).path
            return .init(command: String(f[s..<f.endIndex]), arguments: ["-f", (fm.fileExists(atPath: script) ? script : f)])
        }
    }
    pipeCommands += cmds
    let swiftSuffix = ".swift"
    let n = swiftSuffix.count
    let inputFiles = nodeFiles.filter {
        guard $0.hasSuffix(swiftSuffix), let j = $0.lastIndex(of: "=") ?? $0.lastIndex(of: "-"), let e = $0.index($0.endIndex, offsetBy: -(n+1), limitedBy: $0.startIndex) else { return false }
        let i = $0.index(before: j)
        let k = $0.index(after: j)
        let arg: String
        if $0[i] == "-" && $0[j].isDigit {
            arg = "--atleast-version=" + $0[j..<e]
        } else if $0[i...j] == ">=" && $0[k].isDigit {
            arg = "--atleast-version=" + $0[k..<e]
        } else if $0[i...j] == "<=" && $0[k].isDigit {
            arg = "--max-version=" + $0[k..<e]
        } else if $0[i] == "=" && $0[j].isDigit {
            arg = "--exact-version=" + $0[j..<e]
        } else if $0[i...j] == "==" && $0[k].isDigit {
            arg = "--exact-version=" + $0[k..<e]
        } else {
            return false
        }
        let result = test("pkg-config", arg, pkgConfigName)
        return result
    }
    if pipeCommands.isEmpty {
        if !outputString.isEmpty { print(outputString) }
    } else {
        var processes = [Process]()
        if !outputString.isEmpty {
            let p = Pipe()
            do {
                processes = try pipe(pipeCommands, input: p)
            } catch {
                perror("Cannot post-process using \(pipeCommands.map { ([$0.command] + $0.arguments).joined(separator: " ") }.joined(separator: ", "))")
            }
            DispatchQueue.global(qos: .userInitiated).async {
                let data = outputString.data(using: .utf8) ?? Data()
                p.fileHandleForWriting.write(data)
                if outputDirectory == nil {
                    for file in inputFiles {
                        let fileURL: URL
                        if #available(macOS 10.11, *) {
                            fileURL = URL(fileURLWithPath: file, isDirectory: false, relativeTo: cwdURL)
                        } else {
                            fileURL = URL(fileURLWithPath: file)
                        }
                        guard let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else { continue }
                        p.fileHandleForWriting.write(data)
                    }
                }
                p.fileHandleForWriting.closeFile()
            }
        }
        let pipes = outputFiles.flatMap { (f: String) -> [Process] in
            let o = f + ".out"
            guard let inFile = FileHandle(forReadingAtPath: f),
                  fm.createFile(atPath: o, contents: nil, attributes: nil),
                  let outFile = FileHandle(forWritingAtPath: o) else { return [] }
            do {
                return try pipe(pipeCommands, input: inFile, output: outFile)
            } catch {
                perror("Cannot post-process \(f)")
                return []
            }
        }
        processes += pipes
        let inputFileProcesses: [Process]
        if let outputDirectory = outputDirectory {
            let outDirURL: URL
            if #available(macOS 10.11, *) {
                outDirURL = URL(fileURLWithPath: outputDirectory, isDirectory: true, relativeTo: cwdURL)
            } else {
                outDirURL = URL(fileURLWithPath: outputDirectory)
            }
            inputFileProcesses = inputFiles.flatMap { (f: String) -> [Process] in
                let fileURL = URL(fileURLWithPath: f)
                let outputURL = outDirURL.appendingPathComponent(fileURL.lastPathComponent, isDirectory: false)
                let o = outputURL.path
                guard let inFile = FileHandle(forReadingAtPath: f),
                      fm.createFile(atPath: o, contents: nil, attributes: nil),
                      let outFile = FileHandle(forWritingAtPath: o) else { return [] }
                do {
                    return try pipe(pipeCommands, input: inFile, output: outFile)
                } catch {
                    perror("Cannot process \(f) -> \(o)")
                    return []
                }
            }
        } else {
            inputFileProcesses = []
        }
        processes.forEach { $0.waitUntilExit() }
        outputFiles.forEach {
            let o = $0 + ".out"
            do {
                try fm.removeItem(atPath: $0)
            } catch {
                print("Cannot remove '\($0)': \(error)", to: &Streams.stdErr)
            }
            do {
                try? fm.removeItem(atPath: $0)
                try fm.moveItem(atPath: o, toPath: $0)
            } catch {
                print("Cannot move '\(o)' to '\($0)': \(error)", to: &Streams.stdErr)
            }
        }
        inputFileProcesses.forEach { $0.waitUntilExit() }
    }
}
