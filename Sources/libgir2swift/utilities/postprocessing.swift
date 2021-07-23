//
//  postprocessing.swift
//  libgir2swift
//
//  Created by Rene Hexel on 23/7/21.
//  Copyright © 2021 Rene Hexel. All rights reserved.
//

import Foundation

/// Post-process the output
/// - Parameters:
///   - node: Name of the gir node to post-process
///   - pkgConfigName: Name of the library to pass to pkg-config
///   - outputString: The output string to post-process (if not empty)
///   - outputFiles: The output files to post-process
func postProcess(_ node: String, pkgConfigName: String, outputString: String, outputDirectory: String?, outputFiles: Set<String>) {
    var pipeCommands = [CommandArguments]()
    let postProcessors = ["sed", "awk"]
    let fm = FileManager.default
    postProcessors.forEach {
        let script = node + "." + $0
        if fm.fileExists(atPath: script) {
            pipeCommands.append(.init(command: $0, arguments: ["-f", script]))
        }
    }
    let cwd = fm.currentDirectoryPath
    let cmds = ((try? fm.contentsOfDirectory(atPath: cwd)) ?? []).filter {
        guard $0.hasPrefix(node) else { return false }
        for command in postProcessors {
            guard $0.hasSuffix(command), let i = $0.index($0.startIndex, offsetBy: node.count, limitedBy: $0.endIndex), let e = $0.index($0.endIndex, offsetBy: -(command.count+1), limitedBy: $0.startIndex) else { continue }
            let j = $0.index(after: i)
            let k = $0.index(after: j)
            let arg: String
            if $0[i] == "-" && $0[j].isNumber {
                arg = "--atleast-version=" + $0[j..<e]
            } else if $0[i...j] == ">=" && $0[k].isNumber {
                arg = "--atleast-version=" + $0[k..<e]
            } else if $0[i...j] == "<=" && $0[k].isNumber {
                arg = "--max-version=" + $0[k..<e]
            } else if $0[i] == "=" && $0[j].isNumber {
                arg = "--exact-version=" + $0[j..<e]
            } else if $0[i...j] == "==" && $0[k].isNumber {
                arg = "--exact-version=" + $0[k..<e]
            } else {
                return false
            }
            let null = FileHandle(forWritingAtPath: "/dev/null")
            defer { if #available(macOS 10.15, *) {
                try? null?.close()
            } else {
                null?.closeFile()
            } }
            guard let result = run(standardError: null, "pkg-config", arg, pkgConfigName) else { return false }
            return result == 0
        }
        return false
    }.map { (f: String) -> CommandArguments in
        let d = f.lastIndex(of: ".") ?? f.index(f.endIndex, offsetBy: -4)
        let s = f.index(after: d)
        return .init(command: String(f[s..<f.endIndex]), arguments: ["-f", f])
    }
    pipeCommands += cmds
    if pipeCommands.isEmpty {
        if !outputString.isEmpty { print(outputString) }
    } else {
        var processes = [Process]()
        if !outputString.isEmpty {
        }
        let pipes = outputFiles.flatMap { (f: String) -> [Process] in
            guard let inFile = FileHandle(forReadingAtPath: f),
                  let outFile = FileHandle(forWritingAtPath: f + ".out") else { return [] }
            do {
                return try pipe(pipeCommands, input: inFile, output: outFile)
            } catch {
                perror("Cannot post-process \(f)")
                return []
            }
        }
        processes += pipes
        processes.forEach { $0.waitUntilExit() }
    }
}

