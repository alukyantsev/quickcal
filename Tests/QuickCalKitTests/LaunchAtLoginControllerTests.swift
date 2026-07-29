import ServiceManagement
import Testing
@testable import QuickCalKit

@Suite
struct LaunchAtLoginControllerTests {
    private final class FakeService: LoginItemServicing {
        var status: SMAppService.Status = .notRegistered
        var registerError: Error?
        var unregisterError: Error?

        func register() throws {
            if let registerError {
                throw registerError
            }
            status = .enabled
        }

        func unregister() throws {
            if let unregisterError {
                throw unregisterError
            }
            status = .notRegistered
        }
    }

    private struct TestError: LocalizedError {
        var errorDescription: String? { "access denied" }
    }

    @Test
    func enableRegistersAndRefreshesStatus() async {
        await MainActor.run {
            let service = FakeService()
            let controller = LaunchAtLoginController(service: service)

            controller.setEnabled(true)

            #expect(controller.isEnabled)
            #expect(controller.message == nil)
        }
    }

    @Test
    func disableUnregistersAndRefreshesStatus() async {
        await MainActor.run {
            let service = FakeService()
            service.status = .enabled
            let controller = LaunchAtLoginController(service: service)

            controller.setEnabled(false)

            #expect(!controller.isEnabled)
            #expect(controller.message == nil)
        }
    }

    @Test
    func notFoundBehavesLikeDisabledWithoutMessage() async {
        await MainActor.run {
            let service = FakeService()
            service.status = .notFound
            let controller = LaunchAtLoginController(service: service)

            #expect(!controller.isEnabled)
            #expect(controller.message == nil)
        }
    }

    @Test
    func requiresApprovalShowsActionableMessage() async {
        await MainActor.run {
            let service = FakeService()
            service.status = .requiresApproval
            let controller = LaunchAtLoginController(service: service)

            #expect(!controller.isEnabled)
            #expect(
                controller.message
                    == "Разрешите QuickCal в Системных настройках → Основные → Объекты входа."
            )
        }
    }

    @Test
    func registrationErrorKeepsActualState() async {
        await MainActor.run {
            let service = FakeService()
            service.registerError = TestError()
            let controller = LaunchAtLoginController(service: service)

            controller.setEnabled(true)

            #expect(!controller.isEnabled)
            #expect(controller.message == "Не удалось изменить автозапуск: access denied")
        }
    }
}
