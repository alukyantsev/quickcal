import Combine
import Foundation
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
    private let localization: QuickCalLocalization

    public init(
        service: any LoginItemServicing = SMAppService.mainApp,
        localization: QuickCalLocalization = .current
    ) {
        self.service = service
        self.localization = localization
        refresh()
    }

    public convenience init(service: any LoginItemServicing, locale: Locale) {
        self.init(
            service: service,
            localization: QuickCalLocalization(
                preferredLanguages: [locale.identifier],
                systemLocale: locale
            )
        )
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
            message = localization.string(.launchRequiresApproval)
        case .notFound:
            isEnabled = false
            message = nil
        @unknown default:
            isEnabled = false
            message = localization.string(.launchUnknownStatus)
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
            message = localization.format(
                .launchChangeFailedFormat,
                error.localizedDescription
            )
        }
    }
}
