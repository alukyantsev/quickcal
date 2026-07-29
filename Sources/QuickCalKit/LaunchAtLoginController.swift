import Combine
import ServiceManagement

public protocol LoginItemServicing: AnyObject {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemServicing {}

@MainActor
public final class LaunchAtLoginController: ObservableObject {
    @Published public private(set) var isEnabled = false
    @Published public private(set) var message: String?

    private let service: any LoginItemServicing

    public init(service: any LoginItemServicing = SMAppService.mainApp) {
        self.service = service
        refresh()
    }

    public func refresh() {
        switch service.status {
        case .enabled:
            isEnabled = true
            message = nil
        case .notRegistered:
            isEnabled = false
            message = nil
        case .requiresApproval:
            isEnabled = false
            message = "Разрешите QuickCal в Системных настройках → Основные → Объекты входа."
        case .notFound:
            isEnabled = false
            message = nil
        @unknown default:
            isEnabled = false
            message = "Не удалось определить состояние автозапуска."
        }
    }

    public func setEnabled(_ requestedValue: Bool) {
        do {
            if requestedValue {
                try service.register()
            } else {
                try service.unregister()
            }
            refresh()
        } catch {
            refresh()
            message = "Не удалось изменить автозапуск: \(error.localizedDescription)"
        }
    }
}
