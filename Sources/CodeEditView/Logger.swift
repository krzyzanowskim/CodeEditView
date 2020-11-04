import OSLog

#if DEBUG
let logger = Logger()
#else
let logger = Logger(OSLog.disabled)
#endif
