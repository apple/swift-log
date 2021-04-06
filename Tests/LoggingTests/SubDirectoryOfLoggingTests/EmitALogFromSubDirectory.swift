//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift Logging API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Logging API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging

internal func emitLogMessage(_ message: Logger.Message, to logger: Logger) {
    logger.trace(message)
    logger.debug(message)
    logger.info(message)
    logger.notice(message)
    logger.warning(message)
    logger.error(message)
    logger.critical(message)
}
