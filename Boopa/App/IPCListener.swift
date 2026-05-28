import Foundation

/// Observes `com.eilgnaw.boopa.command` distributed notifications posted by the CLI
/// and forwards decoded commands to the agent.
final class IPCListener {
    private let handler: (WireCommand) -> Void
    private var observer: NSObjectProtocol?

    init(handler: @escaping (WireCommand) -> Void) {
        self.handler = handler
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(WireCommand.notificationName),
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard
                let payload = note.userInfo?[WireCommand.userInfoKey] as? String,
                let command = WireCommand.from(jsonString: payload)
            else { return }
            self?.handler(command)
        }
    }

    deinit {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }
}
