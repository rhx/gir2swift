//
//  girenums.swift
//  libgir2swift
//
//  Created by Rene Hexel on 1/8/20.
//  Copyright © 2020 Rene Hexel. All rights reserved.
//
import Foundation

public extension GIR {
    /// Ownership transfer mechanism
    enum OwnershipTransfer: String, RawRepresentable {
        /// the recipient does not own the value
        case none
        /// same rules as for none, used for floating objects
        case floating
        /// the recipient owns the container, but not the elements. (Only meaningful for container types.)
        case container
        /// the recipient owns the entire value.
        /// For a refcounted type, this means the recipient owns a ref on the value.
        /// For a container type, this means the recipient owns both container and elements.
        case full
    }

    /// Parameter direction
    enum ParameterDirection: String, RawRepresentable {
        /// Indicates that this is an input parameter
        case `in`
        /// Indicates that this is an output parameter
        case `out`
        /// Indicates that this is an input/output parameter
        case `inout`
    }
}
