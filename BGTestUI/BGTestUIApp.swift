import SwiftUI
import BackgroundTasks
import UserNotifications

@main
struct PoCBackgroundApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Register Background Tasks
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.example.pocbackground.cleanup", using: nil) { task in
            BackgroundTaskManager.shared.handleCleanupTask(task: task as! BGAppRefreshTask)
        }
        
        // Setup Background Fetch
        UIApplication.shared.setMinimumBackgroundFetchInterval(15 * 60) // 15 minutes
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
        
        return true
    }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        BackgroundTaskManager.shared.performBackgroundFetch(completionHandler: completionHandler)
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        BackgroundTaskManager.shared.handleBackgroundURLSession(identifier: identifier, completionHandler: completionHandler)
    }
}
