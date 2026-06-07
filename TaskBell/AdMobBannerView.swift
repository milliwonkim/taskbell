import GoogleMobileAds
import SwiftUI
import UIKit

struct AdMobBannerView: View {
    private let bannerHeight: CGFloat = 50

    @Environment(\.scenePhase) private var scenePhase
    @State private var isSDKReady = AdMobConfiguration.isSDKReady
    @State private var reloadToken = 0

    var body: some View {
        AdMobBannerContainerRepresentable(
            adSize: fullWidthPortrait(height: bannerHeight),
            isReady: AdMobConfiguration.isConfigured && isSDKReady,
            reloadToken: reloadToken
        )
        .frame(maxWidth: .infinity)
        .frame(height: bannerHeight)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
        .onAppear {
            syncSDKReadyState()
            requestReload()
        }
        .onReceive(NotificationCenter.default.publisher(for: AdMobConfiguration.sdkReadyNotification)) { _ in
            syncSDKReadyState()
            requestReload()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            requestReload()
        }
    }

    private func syncSDKReadyState() {
        AdMobConfiguration.prepare()
        if AdMobConfiguration.isSDKReady {
            isSDKReady = true
        }
        AdMobConfiguration.onSDKReady {
            isSDKReady = true
            requestReload()
        }
    }

    private func requestReload() {
        reloadToken += 1
    }
}

private struct AdMobBannerContainerRepresentable: UIViewRepresentable {
    let adSize: AdSize
    let isReady: Bool
    let reloadToken: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(adSize: adSize)
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: .zero)
        container.backgroundColor = .clear
        container.clipsToBounds = true
        context.coordinator.attach(to: container)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.adSize = adSize
        context.coordinator.attach(to: uiView)

        guard isReady else { return }

        context.coordinator.scheduleLoad(
            rootViewController: AdMobRootViewControllerProvider.rootViewController,
            reloadToken: reloadToken
        )
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        var adSize: AdSize
        private var bannerView: BannerView?
        private weak var container: UIView?
        private var hasRequestedLoad = false
        private var lastReloadToken = -1
        private var retryWorkItem: DispatchWorkItem?

        init(adSize: AdSize) {
            self.adSize = adSize
        }

        func attach(to container: UIView) {
            self.container = container

            let bannerView = self.bannerView ?? BannerView(adSize: adSize)
            if self.bannerView == nil {
                bannerView.adUnitID = AdMobConfiguration.bannerAdUnitID
                bannerView.delegate = self
                bannerView.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(bannerView)
                NSLayoutConstraint.activate([
                    bannerView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    bannerView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    bannerView.topAnchor.constraint(equalTo: container.topAnchor),
                    bannerView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                ])
                self.bannerView = bannerView
            }

            bannerView.adSize = adSize
        }

        func scheduleLoad(rootViewController: UIViewController?, reloadToken: Int) {
            retryWorkItem?.cancel()

            guard reloadToken != lastReloadToken || !hasRequestedLoad else {
                return
            }

            attemptLoad(rootViewController: rootViewController, reloadToken: reloadToken, attempt: 0)
        }

        private func attemptLoad(
            rootViewController: UIViewController?,
            reloadToken: Int,
            attempt: Int
        ) {
            guard let bannerView else { return }

            guard let rootViewController else {
                guard attempt < 8 else {
                    #if DEBUG
                    print("[AdMob] Banner load skipped: rootViewController unavailable")
                    #endif
                    return
                }

                let workItem = DispatchWorkItem { [weak self] in
                    self?.attemptLoad(
                        rootViewController: AdMobRootViewControllerProvider.rootViewController,
                        reloadToken: reloadToken,
                        attempt: attempt + 1
                    )
                }
                retryWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
                return
            }

            if bannerView.rootViewController !== rootViewController {
                bannerView.rootViewController = rootViewController
                hasRequestedLoad = false
            }

            guard !hasRequestedLoad else { return }

            hasRequestedLoad = true
            lastReloadToken = reloadToken
            bannerView.load(Request())
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            #if DEBUG
            print("[AdMob] Banner loaded")
            #endif
        }

        func bannerView(
            _ bannerView: BannerView,
            didFailToReceiveAdWithError error: Error
        ) {
            hasRequestedLoad = false
            #if DEBUG
            print("[AdMob] Banner failed:", error.localizedDescription)
            #endif

            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.attemptLoad(
                    rootViewController: AdMobRootViewControllerProvider.rootViewController,
                    reloadToken: self.lastReloadToken,
                    attempt: 0
                )
            }
            retryWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
        }
    }
}

@MainActor
enum AdMobRootViewControllerProvider {
    static var rootViewController: UIViewController? {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        let windowScene =
            windowScenes.first(where: { $0.activationState == .foregroundActive })
            ?? windowScenes.first

        let window =
            windowScene?.keyWindow
            ?? windowScene?.windows.first(where: \.isKeyWindow)
            ?? windowScene?.windows.first

        return window?.rootViewController
    }
}
