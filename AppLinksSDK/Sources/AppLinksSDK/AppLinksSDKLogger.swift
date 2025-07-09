//
//  AppLinksLogger.swift
//  AppLinksSDK
//
//  Created by Maxence Henneron on 7/9/25.
//

import os

public enum AppLinksSDKLogLevel: Int, Comparable {
    case none = 0
    case error
    case warning
    case info
    case debug

    public static func < (lhs: AppLinksSDKLogLevel, rhs: AppLinksSDKLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}


public final class AppLinksSDKLogger {
    // MARK: - Singleton with Global Config
    public static let shared = AppLinksSDKLogger(
        subsystem: "com.applinks.AppLinksSDK",
        category: "core",
        logLevel: {
            #if DEBUG
            .debug
            #else
            .error
            #endif
        }()
    )

    // MARK: - Stored Config
    public var subsystem: String
    public var logLevel: AppLinksSDKLogLevel

    private let category: String
    private let logger: Logger

    // MARK: - Init
    public init(subsystem: String, category: String, logLevel: AppLinksSDKLogLevel) {
        self.subsystem = subsystem
        self.logLevel = logLevel
        self.category = category
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    // MARK: - Cloning with Different Category
    public func withCategory(_ newCategory: String) -> AppLinksSDKLogger {
        AppLinksSDKLogger(
            subsystem: self.subsystem,
            category: newCategory,
            logLevel: self.logLevel
        )
    }

    // MARK: - Logging
    public func debug(_ message: @autoclosure () -> String) {
        guard logLevel >= .debug else { return }
        let evaluated = message()
        
        logger.debug("\(evaluated, privacy: .public)")
    }

    public func info(_ message: @autoclosure () -> String) {
        guard logLevel >= .info else { return }
        let evaluated = message()
        
        logger.info("\(evaluated, privacy: .public)")
    }

    public func warning(_ message: @autoclosure () -> String) {
        guard logLevel >= .warning else { return }
        let evaluated = message()

        logger.notice("\(evaluated, privacy: .public)")
    }

    public func error(_ message: @autoclosure () -> String) {
        guard logLevel >= .error else { return }
        let evaluated = message()

        logger.error("\(evaluated, privacy: .public)")
    }
}
