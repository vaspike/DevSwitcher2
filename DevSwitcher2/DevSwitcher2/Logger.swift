//
//  Logger.swift
//  DevSwitcher2
//
//  Created by river on 2025-07-27.
//

import Foundation

/// A simple logger that only prints messages in the DEBUG build configuration.
final class Logger {
    
    /// Logs a message to the console.
    /// The message will only be printed if the code is compiled in the DEBUG configuration.
    ///
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: A string to print between each item. The default is a single space (" ").
    ///   - terminator: The string to print after all items have been printed. The default is a newline ("\n").
    static func log(_ items: Any..., separator: String = " ", terminator: String = "\n") {
#if DEBUG
        let output = items.map { "\($0)" }.joined(separator: separator)
        print(output, terminator: terminator)
#endif
    }
}
