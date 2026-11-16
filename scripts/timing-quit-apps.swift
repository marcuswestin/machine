import AppKit
import Foundation

// Graceful termination only; preserve network services and never force-quit.
let identifiers = Array(CommandLine.arguments.dropFirst())
var results: [[String: Any]] = []
for identifier in identifiers {
    let apps = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
    let accepted = apps.map { $0.terminate() }
    let deadline = Date().addingTimeInterval(10)
    while apps.contains(where: { !$0.isTerminated }) && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    results.append([
        "bundleIdentifier": identifier,
        "pids": apps.map { Int($0.processIdentifier) },
        "accepted": accepted,
        "stopped": apps.allSatisfy { $0.isTerminated },
    ])
}
let json = try JSONSerialization.data(withJSONObject: results, options: [.sortedKeys])
print(String(decoding: json, as: UTF8.self))
