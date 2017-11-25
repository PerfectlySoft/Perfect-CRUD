//
//  PerfectSwORMLogging.swift
//  PerfectSwORM
//
//  Created by Kyle Jessup on 2017-11-24.
//	Copyright (C) 2017 PerfectlySoft, Inc.
//
//===----------------------------------------------------------------------===//
//
// This source file is part of the Perfect.org open source project
//
// Copyright (c) 2015 - 2017 PerfectlySoft Inc. and the Perfect project authors
// Licensed under Apache License v2.0
//
// See http://perfect.org/licensing.html for license information
//
//===----------------------------------------------------------------------===//
//

import Foundation
import Dispatch

public enum SwORMLogDestination {
	case none
	case console
	case file(String)
	case custom((SwORMLogEvent) -> ())
	
	func handleEvent(_ event: SwORMLogEvent) {
		switch self {
		case .none:
			()
		case .console:
			print("\(event)")
		case .file(let name):
			let fm = FileManager()
			guard fm.isWritableFile(atPath: name) || fm.createFile(atPath: name, contents: nil, attributes: nil),
				let fileHandle = FileHandle(forWritingAtPath: name),
				let data = "\(event)\n".data(using: .utf8) else {
				print("[ERR] Unable to open file at \"\(name)\" to log event \(event)")
				return
			}
			defer {
				fileHandle.closeFile()
			}
			fileHandle.seekToEndOfFile()
			fileHandle.write(data)
		case .custom(let code):
			code(event)
		}
	}
}

public enum SwORMLogEventType: CustomStringConvertible {
	case info, warning, error, query
	public var description: String {
		switch self {
		case .info:
			return "INFO"
		case .warning:
			return "WARN"
		case .error:
			return "ERR"
		case .query:
			return "QUERY"
		}
	}
}

public struct SwORMLogEvent: CustomStringConvertible {
	public let time: Date
	public let type: SwORMLogEventType
	public let msg: String
	public var description: String {
		let formatter = DateFormatter()
		formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss ZZ"
		return "[\(formatter.string(from: time))] [\(type)] \(msg)"
	}
}

public struct SwORMLogging {
	private static var _queryLogDestinations: [SwORMLogDestination] = [.console]
	private static var _errorLogDestinations: [SwORMLogDestination] = [.console]
	private static var pendingEvents: [SwORMLogEvent] = []
	private static var loggingQueue: DispatchQueue = {
		let q = DispatchQueue(label: "SwORMLoggingQueue", qos: .background)
		scheduleLogCheck(q)
		return q
	}()
	private static func logCheckInSerialQueue() {
		print("logCheckInSerialQueue")
		defer {
			scheduleLogCheck(loggingQueue)
		}
		guard !pendingEvents.isEmpty else {
			return
		}
		let eventsToLog = pendingEvents
		pendingEvents = []
		eventsToLog.forEach {
			logEventInSerialQueue($0)
		}
	}
	private static func logEventInSerialQueue(_ event: SwORMLogEvent) {
		if case .query = event.type {
			_queryLogDestinations.forEach { $0.handleEvent(event) }
		} else {
			_errorLogDestinations.forEach { $0.handleEvent(event) }
		}
	}
	private static func scheduleLogCheck(_ queue: DispatchQueue) {
		queue.asyncAfter(deadline: .now() + 0.5, execute: logCheckInSerialQueue)
	}
}

public extension SwORMLogging {
	public static var queryLogDestinations: [SwORMLogDestination] {
		set {
			loggingQueue.async { _queryLogDestinations = newValue }
		}
		get {
			return loggingQueue.sync { return _queryLogDestinations }
		}
	}
	public static var errorLogDestinations: [SwORMLogDestination] {
		set {
			loggingQueue.async { _errorLogDestinations = newValue }
		}
		get {
			return loggingQueue.sync { return _errorLogDestinations }
		}
	}
	public static func log(_ type: SwORMLogEventType, _ msg: String) {
		let now = Date()
		loggingQueue.async {
			pendingEvents.append(.init(time: now, type: type, msg: msg))
		}
	}
}




