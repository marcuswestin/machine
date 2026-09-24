import AppKit
import UserNotifications

struct Args {
  var title = "Claude Code"
  var subtitle = ""
  var message = ""
  var sound = "Glass"
}

func parseArgs(_ argv: [String]) -> Args {
  var args = Args()
  var i = 0
  while i < argv.count {
    let key = argv[i]
    let value = i + 1 < argv.count ? argv[i + 1] : ""
    switch key {
    case "-title", "--title":
      args.title = value
      i += 2
    case "-subtitle", "--subtitle":
      args.subtitle = value
      i += 2
    case "-message", "--message":
      args.message = value
      i += 2
    case "-sound", "--sound":
      args.sound = value
      i += 2
    default:
      i += 1
    }
  }
  return args
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  let args: Args

  init(args: Args) {
    self.args = args
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Hard deadline so a stuck TCC/notification callback cannot block Stop hooks.
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
      exit(0)
    }

    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      let deliver = {
        let content = UNMutableNotificationContent()
        content.title = self.args.title
        if !self.args.subtitle.isEmpty {
          content.subtitle = self.args.subtitle
        }
        content.body = self.args.message
        if !self.args.sound.isEmpty {
          content.sound = UNNotificationSound(named: UNNotificationSoundName(self.args.sound))
        }
        let request = UNNotificationRequest(
          identifier: UUID().uuidString,
          content: content,
          trigger: nil
        )
        center.add(request) { _ in
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            exit(0)
          }
        }
      }

      switch settings.authorizationStatus {
      case .notDetermined:
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in
          deliver()
        }
      default:
        deliver()
      }
    }
  }
}

let args = parseArgs(Array(CommandLine.arguments.dropFirst()))
guard !args.message.isEmpty else {
  fputs("usage: claude-notify -title T -subtitle S -message M [-sound Glass]\n", stderr)
  exit(64)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate(args: args)
app.delegate = delegate
app.run()
