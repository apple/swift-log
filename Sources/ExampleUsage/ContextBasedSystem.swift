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

// this is a contrived example of a context based system, ie a system that explictly passes a context object around
// in this example we include a logger in the context object
// we also allow users to set metadata on the context object and reuse that as the metadata for logging
enum ContextBasedSystem {
    static func main() {
        // run the example
        for i in 1 ... 2 {
            print("---------------------------- processing request #\(i) ----------------------------")
            let context = Context(metadata: ["requestId": "\(UUID().uuidString)"]) // contrived context
            Foo().doSomething(context: context, requestNumnber: i)
        }
    }

    struct Context {
        var logger = Logger(label: "ContextLogger")

        init(metadata: Logger.Metadata = [:]) {
            metadata.forEach { self[$0.0] = $0.1 }
        }

        // since logger is a value type, we can reuse our copy to manage the metadata
        subscript(metadataKey: String) -> Logger.Metadata.Value? {
            get { return self.logger[metadataKey: metadataKey] }
            set { self.logger[metadataKey: metadataKey] = newValue }
        }
    }

    class Foo {
        func doSomething(context: Context, requestNumnber: Int) {
            var c = context // context is a value type, changes only effect this instance
            if 0 == requestNumnber % 2 {
                // debug verbosely every 2nd request
                c.logger.logLevel = .trace
            }
            c.logger.info("\(self)::doSomething")
            self.doSomethingElse(context: c)
            c.logger.info("\(self)::doSomething::end")
        }

        private func doSomethingElse(context: Context) {
            var c = context // context is a value type, changes only effect this instance
            c["foo"] = "bar"
            c.logger.info("\(self)::doSomethingElse")
            c.logger.trace("\(self)::doSomethingElse:someDebugInfo")
            Bar().doSomething(context: c)
            c.logger.info("\(self)::doSomethingElse::end")
        }
    }

    class Bar {
        func doSomething(context: Context) {
            var c = context // context is a value type, changes only effect this instance
            c["bar"] = "baz"
            c.logger.info("\(self)::doSomething")
            c.logger.trace("\(self)::doSomething:someDebugInfo")
            Baz().doSomething(context: c)
            c.logger.info("\(self)::doSomething::end")
        }
    }

    class Baz {
        private let queue = DispatchQueue(label: "ContextBasedSystem::Baz")

        func doSomething(context: Context) {
            context.logger.info("\(self)::doSomething")
            context.logger.trace("\(self)::doSomething:someDebugInfo")
            let group = DispatchGroup()
            group.enter()
            queue.async {
                context.logger.info("\(self)::doSomethingAsync")
                // since the library does not know about the context it will loose the metadata
                let library = RandomLibrary()
                library.doSomething()
                library.doSomethingAsync {
                    group.leave()
                }
            }
            group.wait()

            var l = context.logger // logger is a value type, changes only effect this instance
            l[metadataKey: "baz"] = "qux"
            l.info("\(self)::doSomething::Local")
            context.logger.info("\(self)::doSomething::end")
        }
    }
}
