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
// THIS IS NOT PART OF THE PITCH, JUST AN EXAMPLE HOW A LOGGER USAGE LOOKS LIKE
//

import ExampleImplementation
import Foundation
@testable import Logging // need access to internal bootstrap function 

enum MultiplexExample {
    static func main() {
        // boostrap with two of our sample implementations
        LoggingSystem.bootstrapInternal({ MultiplexLogHandler([SimpleLogHandler(label: $0), FileLogHandler(label: $0)]) })

        // run the example
        let logger = Logger(label: "com.example.TestApp")
        logger.info("hello world!")
    }
}
