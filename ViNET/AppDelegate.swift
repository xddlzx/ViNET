import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  // for iOS 12 and below (storyboard fallback)
  var window: UIWindow?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 13.0, *) {
      // SceneDelegate will set up window
    } else {
      // iOS 12 and below: create window manually
      window = UIWindow(frame: UIScreen.main.bounds)
      window?.rootViewController = ViewController()
      window?.makeKeyAndVisible()
    }
    return true
  }

  // MARK: UISceneSession Lifecycle (iOS 13+)
  @available(iOS 13.0, *)
  func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    return UISceneConfiguration(name: "Default Configuration",
                                sessionRole: connectingSceneSession.role)
  }
}
