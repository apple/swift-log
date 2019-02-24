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
import ExampleImplementation

// boostrap with our sample implementation
LoggingSystem.bootstrap(SimpleLogHandler.init)

print()
print("##### global logger based system #####")
GlobalLoggerBasedSystem.main()

print()
print("##### local logger based system #####")
LocalLoggerBasedSystem.main()

print()
print("##### context based system #####")
ContextBasedSystem.main()

print()
print("##### multiplexiing to multiple logging implementations #####")
MultiplexExample.main()

print()
print("##### config based logging implementations #####")
ConfigExample.main()
