import Foundation
import GoogleMobileAds

@MainActor
enum AdMobConfiguration {
    static let applicationID = "ca-app-pub-8054978526190901~8544964764"
    static let productionBannerAdUnitID = "ca-app-pub-8054978526190901/7390675514"
    private static let googleTestBannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"
    private static let knownPhysicalTestDeviceID = "efe3142c8beae5a21692b487bbd44615"
    static let sdkReadyNotification = Notification.Name("AdMobConfiguration.sdkReady")

    private(set) static var isSDKReady = false
    private static var hasStarted = false
    private static var readyHandlers: [() -> Void] = []

    static var bannerAdUnitID: String {
        #if DEBUG
        googleTestBannerAdUnitID
        #else
        productionBannerAdUnitID
        #endif
    }

    static var resolvedApplicationID: String? {
        guard let plistAppID = Bundle.main.object(
            forInfoDictionaryKey: "GADApplicationIdentifier"
        ) as? String else {
            return nil
        }

        let trimmedAppID = plistAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedAppID.isEmpty ? nil : trimmedAppID
    }

    static var isConfigured: Bool {
        resolvedApplicationID == applicationID
    }

    static func onSDKReady(_ handler: @escaping @MainActor () -> Void) {
        if isSDKReady {
            handler()
            return
        }

        readyHandlers.append(handler)
    }

    static func prepare() {
        guard isConfigured else {
            #if DEBUG
            print(
                "[AdMob] SDK not started. GADApplicationIdentifier mismatch:",
                resolvedApplicationID ?? "nil"
            )
            #endif
            return
        }

        guard !hasStarted else { return }

        hasStarted = true
        configureTestDevices()
        MobileAds.shared.start { _ in
            Task { @MainActor in
                isSDKReady = true
                NotificationCenter.default.post(name: sdkReadyNotification, object: nil)
                let handlers = readyHandlers
                readyHandlers.removeAll()
                handlers.forEach { $0() }
            }
        }
    }

    private static func configureTestDevices() {
        #if DEBUG
        #if targetEnvironment(simulator)
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = ["SIMULATOR"]
        #else
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
            knownPhysicalTestDeviceID,
        ]
        #endif
        #endif
    }
}
