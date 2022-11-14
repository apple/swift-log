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

import Logging

#if swift(>=5.5.0) && canImport(_Concurrency)
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension Logger {

    /// Replicates how the `Tracing` package offers an integration between `Baggage` and logger metadata.
    mutating func provideMetadata(from baggage: TestBaggage?) {
        guard let baggage = baggage else {
            return
        }
        
        TestBaggage.withValue(baggage) {
            let metadata = self.metadataProvider.provideMetadata()
            for (k, v) in metadata {
                self[metadataKey: k] = v
            }
        }
    }
}
#endif
