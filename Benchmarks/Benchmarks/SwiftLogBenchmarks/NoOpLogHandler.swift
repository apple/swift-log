//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift Logging API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Logging API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging

struct NoOpLogHandler: LogHandler {
    let label: String
    public var metadataProvider: Logger.MetadataProvider?

    init(label: String, metadataProvider: Logger.MetadataProvider?) {
        self.label = label
        self.metadataProvider = metadataProvider
    }

    init(label: String) {
        self.label = label
        self.metadataProvider = LoggingSystem.metadataProvider
    }

    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata explicitMetadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        // Do nothing
    }

    private var _logLevel: Logger.Level?
    var logLevel: Logger.Level {
        get {
            self._logLevel ?? .debug
        }
        set {
            self._logLevel = newValue
        }
    }

    private var _metadataSet = false
    private var _metadata = Logger.Metadata() {
        didSet {
            self._metadataSet = true
        }
    }

    public var metadata: Logger.Metadata {
        get {
            self._metadata
        }
        set {
            self._metadata = newValue
        }
    }

    // TODO: would be nice to delegate to local copy of logger but StdoutLogger is a reference type. why?
    subscript(metadataKey metadataKey: Logger.Metadata.Key) -> Logger.Metadata.Value? {
        get {
            self._metadata[metadataKey]
        }
        set {
            self._metadata[metadataKey] = newValue
        }
    }
}
