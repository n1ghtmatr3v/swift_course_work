import Foundation
import Combine
import SwiftUI

@MainActor
final class HideMenu: ObservableObject
{
    @Published var shouldShowDecorativeBadges: Bool = true

    private let idleDelayNanoseconds: UInt64
    private var idleTask: Task<Void, Never>?

    init(idleDelay: TimeInterval = 60)
    {
        self.idleDelayNanoseconds = UInt64(idleDelay * 1_000_000_000)
    }

    func startIdleTimer()
    {
        scheduleIdleTimer()
    }

    func stopIdleTimer()
    {
        idleTask?.cancel()
        idleTask = nil
        shouldShowDecorativeBadges = false
    }

    func registerUserInteraction()
    {
        if shouldShowDecorativeBadges {
            shouldShowDecorativeBadges = false
        }

        scheduleIdleTimer()
    }

    private func scheduleIdleTimer()
    {
        idleTask?.cancel()

        let delay = idleDelayNanoseconds

        idleTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }

            guard Task.isCancelled == false else {
                return
            }

            await MainActor.run {
                self?.shouldShowDecorativeBadges = true
            }
        }
    }
}

private struct FullScreenPreviewWrapper: View
{
    var body: some View
    {
        NavigatorOnMap()
    }
}

#Preview("Full iPhone Screen") {
    FullScreenPreviewWrapper()
}
