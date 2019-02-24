//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2018-2019 Apple Inc. and the Swift Logging API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Logging API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
//
// THIS IS NOT PART OF THE PITCH, JUST AN EXAMPLE HOW A LOGGER IMPLEMENTATION LOOKS LIKE
//

import Foundation
import Logging

// helper class to keep things DRY
internal struct CommonLogHandler {
    let label: String
    private var _logLevel: Logger.Level?
    private let formatter: DateFormatter
    private let lock = NSLock()

    public init(label: String) {
        self.label = label
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.locale = Locale(identifier: "en_US")
        formatter.calendar = Calendar(identifier: .gregorian)
        self.formatter = formatter
    }

    public func log(level: Logger.Level, message: String, metadata: Logger.Metadata?, printer: (String) -> Void) {
        let prettyMetadata = metadata?.isEmpty ?? true ? self.prettyMetadata : self.prettify(self.metadata.merging(metadata!, uniquingKeysWith: { _, new in new }))
        printer("[\(self.label)] \(self.formatter.string(from: Date()))\(prettyMetadata.map { " \($0)" } ?? "") \(level): \(message)")
    }

    public var logLevel: Logger.Level? {
        get {
            return self.lock.withLock { self._logLevel }
        }
        set {
            self.lock.withLock {
                self._logLevel = newValue
            }
        }
    }

    private var prettyMetadata: String?
    private var _metadata = Logger.Metadata() {
        didSet {
            self.prettyMetadata = self.prettify(self._metadata)
        }
    }

    public var metadata: Logger.Metadata {
        get {
            return self.lock.withLock { self._metadata }
        }
        set {
            self.lock.withLock { self._metadata = newValue }
        }
    }

    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            return self.lock.withLock { self._metadata[metadataKey] }
        }
        set {
            self.lock.withLock {
                self._metadata[metadataKey] = newValue
            }
        }
    }

    private func prettify(_ metadata: Logger.Metadata) -> String? {
        return !metadata.isEmpty ? metadata.map { "\($0)=\($1)" }.joined(separator: " ") : nil
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return body()
    }
}
