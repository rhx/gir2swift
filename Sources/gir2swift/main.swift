//
//  main.swift
//  gir2swift
//
//  Created by Rene Hexel on 22/03/2016.
//  Copyright © 2016, 2017, 2018, 2019, 2020, 2021, 2022 Rene Hexel. All rights reserved.
//
import libgir2swift
import Foundation

let fm = FileManager.default

CommandLine.arguments.enumerated().forEach { (i, filename) in
    print("\n\(i): \(filename)")
}

Gir2Swift.main()
