//
//  EmptySequence.swift
//  Gtk3Swift
//
//  Created by Rene Hexel on 25/03/2016.
//  Copyright © 2016 Rene Hexel. All rights reserved.
//

/// Function returning a generator for an empty sequence of T
public func emptyGenerator<T>() -> AnyGenerator<T> {
    return AnyGenerator { nil }
}

/// Function returning an empty sequence of T
public func emptySequence<T>() -> AnySequence<T> {
    return AnySequence(EmptyGenerator())
}
