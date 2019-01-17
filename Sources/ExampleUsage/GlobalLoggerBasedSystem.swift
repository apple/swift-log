//
// THIS IS NOT PART OF THE PITCH, JUST AN EXAMPLE HOW A LOGGER USAGE LOOKS LIKE
//

import ExampleImplementation
import Foundation
import Logging

// since this example mutates the global logger, we need to lock around it
var _logger = Logging.make("GlobalLogger")
var lock = NSLock()
var logger: Logger {
    get {
        return lock.withLock {
            _logger
        }
    }
    set {
        lock.withLock {
            _logger = newValue
        }
    }
}

// this is a contrived example of a system that shares one global logger
enum GlobalLoggerBasedSystem {
    static func main() {
        // boostrap with our sample implementation
        let logging = SimpleLogging()
        Logging.bootstrap(logging.make)
        // run the example
        for i in 1 ... 2 {
            print("---------------------------- processing request #\(i) ----------------------------")
            logger[metadataKey: "requestId"] = "\(UUID().uuidString)"
            Foo().doSomething(requestNumnber: i)
        }
    }

    class Foo {
        func doSomething(requestNumnber: Int) {
            if 0 == requestNumnber % 2 {
                // debug verbosely every 2nd request
                logger.logLevel = .trace
            }
            logger.info("\(self)::doSomething")
            self.doSomethingElse()
            logger.info("\(self)::doSomething::end")
        }

        private func doSomethingElse() {
            logger[metadataKey: "foo"] = "bar"
            logger.info("\(self)::doSomethingElse")
            logger.trace("\(self)::doSomethingElse:someDebugInfo")
            Bar().doSomething()
            logger.info("\(self)::doSomethingElse::end")
            logger[metadataKey: "foo"] = nil
        }
    }

    class Bar {
        func doSomething() {
            logger[metadataKey: "bar"] = "baz"
            logger.info("\(self)::doSomething")
            logger.trace("\(self)::doSomething:someDebugInfo")
            Baz().doSomething()
            logger.info("\(self)::doSomething::end")
            logger[metadataKey: "bar"] = nil
        }
    }

    class Baz {
        private let queue = DispatchQueue(label: "GlobalLoggerBasedSystem::Baz")

        func doSomething() {
            logger.info("\(self)::doSomething")
            logger.trace("\(self)::doSomething:someDebugInfo")
            let group = DispatchGroup()
            group.enter()
            queue.async {
                logger.info("\(self)::doSomethingAsync")
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

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return body()
    }
}
