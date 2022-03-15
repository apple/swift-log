//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift Logging API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Logging API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

//  Sendable support helpers

#if compiler(>=5.6)
@preconcurrency public protocol _SwiftLogSendableLogHandler: Sendable {}
#else
public protocol _SwiftLogSendableLogHandler {}
#endif

#if compiler(>=5.6)
public typealias _SwiftLogSendable = Sendable
#else
public typealias _SwiftLogSendable = Any
#endif
