import Foundation
import ServiceManagement

// Read macOS authorization for plist-based launch jobs without changing consent.
for path in CommandLine.arguments.dropFirst() {
    let status = SMAppService.statusForLegacyPlist(at: URL(fileURLWithPath: path))
    switch status {
    case .enabled: print("enabled")
    case .requiresApproval: print("requiresApproval")
    case .notRegistered: print("notRegistered")
    case .notFound: print("notFound")
    @unknown default: print("unknown")
    }
}
