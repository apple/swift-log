//
// THIS IS NOT PART OF THE PITCH, JUST AN EXAMPLE HOW A LOGGER USAGE LOOKS LIKE
//

import Foundation
import Logging

// this is a contrived example of a 3rd party library that is used by the other examples
// this library does not know anything about the systewm that used it, so cannot make
// assumptions about them
class RandomLibrary {
    private let logger = Logger(label: "RandomLibrary")
    private let queue = DispatchQueue(label: "RandomLibrary")

    public init() {}

    public func doSomething() {
        self.logger.info("doSomething")
    }

    public func doSomethingAsync(completion: @escaping () -> Void) {
        self.queue.asyncAfter(deadline: .now() + 0.1) {
            self.logger.info("doSomethingAsync")
            completion()
        }
    }
}
