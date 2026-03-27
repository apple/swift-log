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

/// A log event that contains all the information about a single log statement.
///
/// `LogEvent` is passed to a ``LogHandler`` via ``LogHandler/log(event:)`` and carries every piece of data emitted
/// at the log call site. Handlers may inspect, modify, or forward any of the event's properties.
///
/// All properties are mutable so that handler wrappers (for example ``MultiplexLogHandler``) can rewrite fields
/// such as metadata or source before forwarding to downstream handlers.
public struct LogEvent: Sendable {
    /// The log level of this event.
    public var level: Logger.Level

    /// The message of this event.
    public var message: Logger.Message

    /// The metadata associated with this event, if any.
    public var metadata: Logger.Metadata? {
        get { self._metadata }
        set { self._metadata = newValue }
    }

    private var _metadata: Logger.Metadata?

    /// The source where this log event originated, for example the logging module.
    ///
    /// When no explicit source was provided at the call site, this is derived lazily from ``file``
    /// every time this property is accessed. Handlers that never read this property pay no
    /// allocation cost for source computation.
    public var source: String {
        @inlinable get { self._source ?? Logger.currentModule(fileID: self.file) }
        @inlinable set { self._source = newValue }
    }

    @usableFromInline
    internal var _source: String?

    /// The file this log event originates from.
    public var file: String

    /// The function this log event originates from.
    public var function: String

    /// The line this log event originates from.
    public var line: UInt

    /// Creates a new log event.
    ///
    /// - Parameters:
    ///   - level: The log level of this event.
    ///   - message: The message of this event.
    ///   - metadata: The metadata associated with this event, if any.
    ///   - source: The source where this log event originated. When `nil`, ``source`` is derived lazily
    ///     from ``file`` on first access so handlers that never read it pay no allocation cost.
    ///   - file: The file this log event originates from.
    ///   - function: The function this log event originates from.
    ///   - line: The line this log event originates from.
    public init(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String?,
        file: String,
        function: String,
        line: UInt
    ) {
        self.level = level
        self.message = message
        self._metadata = metadata
        self._source = source
        self.file = file
        self.function = function
        self.line = line
    }
}
