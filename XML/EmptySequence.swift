//
//  EmptySequence.swift
//  Gtk3Swift
//
//  Created by Rene Hexel on 25/03/2016.
//  Copyright © 2016 Rene Hexel. All rights reserved.
//

/// Function returning an iterator for an empty sequence of T
public func emptyIterator<T>() -> AnyIterator<T> {
    return AnyIterator { nil }
}

/// Function returning an empty sequence of T
public func emptySequence<T>() -> AnySequence<T> {
    return AnySequence(EmptyIterator())
}
