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

import Foundation
import Logging

// this is a contrived example of a system where each component obtain its own logger
enum LocalLoggerBasedSystem {
    static func main() {
        // run the example
        for i in 1 ... 2 {
            print("---------------------------- processing request #\(i) ----------------------------")
            Foo().doSomething(requestNumnber: i)
        }
    }

    class Foo {
        private var logger = Logger(label: "LocalLoggerBasedSystem::Foo")

        func doSomething(requestNumnber: Int) {
            if 0 == requestNumnber % 2 {
                // debug verbosely every 2nd request
                self.logger.logLevel = .trace
            }
            self.logger.info("\(self)::doSomething")
            self.doSomethingElse(requestNumnber: requestNumnber)
            self.logger.info("\(self)::doSomething::end")
        }

        private func doSomethingElse(requestNumnber: Int) {
            self.logger[metadataKey: "foo"] = "bar" // logger is a value type, changes only effect this instance
            self.logger.info("\(self)::doSomethingElse")
            self.logger.trace("\(self)::doSomethingElse:someDebugInfo")
            Bar().doSomething(requestNumnber: requestNumnber)
            self.logger.info("\(self)::doSomethingElse::end")
        }
    }

    class Bar {
        private var logger = Logger(label: "LocalLoggerBasedSystem::Bar")

        func doSomething(requestNumnber: Int) {
            if 0 == requestNumnber % 2 {
                // debug verbosely every 2nd request
                self.logger.logLevel = .trace
            }
            self.logger[metadataKey: "bar"] = "baz" // logger is a value type, changes only effect this instance
            self.logger.info("\(self)::doSomething")
            self.logger.trace("\(self)::doSomething:someDebugInfo")
            Baz().doSomething(requestNumnber: requestNumnber)
            self.logger.info("\(self)::doSomething::end")
        }
    }

    class Baz {
        private var logger = Logger(label: "LocalLoggerBasedSystem::Baz")
        private let queue = DispatchQueue(label: "LocalLoggerBasedSystem::Baz")

        func doSomething(requestNumnber: Int) {
            if 0 == requestNumnber % 2 {
                // debug verbosely every 2nd request
                self.logger.logLevel = .trace
            }
            self.logger.info("\(self)::doSomething")
            self.logger.trace("\(self)::doSomething:someDebugInfo")
            let group = DispatchGroup()
            group.enter()
            queue.async {
                self.logger.info("\(self)::doSomethingAsync")
                // since the library does not know about the context it will loose the metadata
                let library = RandomLibrary()
                library.doSomething()
                library.doSomethingAsync {
                    group.leave()
                }
            }
            group.wait()

            var l = logger // logger is a value type, changes only effect this instance
            l[metadataKey: "baz"] = "qux"
            l.info("\(self)::doSomething::Local")
            logger.info("\(self)::doSomething::end")
        }
    }
}
