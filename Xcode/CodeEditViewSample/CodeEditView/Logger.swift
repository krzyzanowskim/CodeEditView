//
//  Logger.swift
//  CodeEditViewSample
//
//  Created by Marcin Krzyzanowski on 29/09/2020.
//

import OSLog

#if DEBUG
let logger = Logger()
#else
let logger = Logger(OSLog.disabled)
#endif
