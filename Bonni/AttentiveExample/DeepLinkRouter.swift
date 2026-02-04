//
//  DeepLinkRouter.swift
//  AttentiveExample
//
//  Deep link routing logic for the Bonni app
//

import UIKit

enum DeepLinkDestination {
    case cart

    init?(url: URL) {
        guard url.scheme == "bonni" else { return nil }

        switch url.host {
        case "cart":
            self = .cart
        default:
            return nil
        }
    }

    init?(path: String) {
        switch path.lowercased() {
        case "cart":
            self = .cart
        default:
            return nil
        }
    }
}

class DeepLinkRouter {

    static let shared = DeepLinkRouter()

    private init() {}

    // MARK: - Public Methods

    /// Handle deep link from URL (used by SceneDelegate/AppDelegate)
    func handle(url: URL) -> Bool {
        guard let destination = DeepLinkDestination(url: url) else {
            return false
        }

        return navigate(to: destination)
    }

    /// Handle deep link from path string (used for testing/internal navigation)
    func handle(path: String) -> Bool {
        guard let destination = DeepLinkDestination(path: path) else {
            return false
        }

        return navigate(to: destination)
    }

    // MARK: - Private Methods

    private func navigate(to destination: DeepLinkDestination) -> Bool {
        guard let navigationController = getNavigationController() else {
            return false
        }

        switch destination {
        case .cart:
            return navigateToCart(from: navigationController)
        }
    }

    private func navigateToCart(from navigationController: UINavigationController) -> Bool {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let viewModel = appDelegate.productListViewModel else {
            return false
        }

        let cartVC = CartViewController(viewModel: viewModel)

        if Thread.isMainThread {
            navigationController.pushViewController(cartVC, animated: true)
        } else {
            DispatchQueue.main.sync {
                navigationController.pushViewController(cartVC, animated: true)
            }
        }

        return true
    }

    private func getNavigationController() -> UINavigationController? {
        // Try to get the topmost view controller's navigation controller
        if let topVC = getTopViewController(),
           let navController = topVC.navigationController {
            return navController
        }

        // Try to get from window scene
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }),
           let navController = window.rootViewController as? UINavigationController {
            return navController
        }

        // Fallback: try from app delegate window
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
           let window = appDelegate.window,
           let navController = window.rootViewController as? UINavigationController {
            return navController
        }

        return nil
    }

    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootViewController = window.rootViewController else {
            return nil
        }

        var topController = rootViewController

        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }

        if let navigationController = topController as? UINavigationController {
            return navigationController.visibleViewController
        }

        if let tabBarController = topController as? UITabBarController {
            if let selected = tabBarController.selectedViewController {
                if let navigationController = selected as? UINavigationController {
                    return navigationController.visibleViewController
                }
                return selected
            }
        }

        return topController
    }
}
