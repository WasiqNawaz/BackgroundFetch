import UIKit
import BackgroundTasks
import AVFoundation
import UserNotifications

class BackgroundTaskManager {
    //MARK: - Variables
    var player: AVAudioPlayer?
    static let shared = BackgroundTaskManager()
    private var taskCount = 0
    private var startTime: Date?
    private var isTaskRunning = false
    
    //MARK: - Arrays
    let images = ["1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1", "2", "3","1"]

    init() {}
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.wasiq.CoreBGTask.processing", using: nil) { task in
            self.handleProcessingTask(task: task as! BGProcessingTask)
        }
    }
    
    func scheduleBackgroundProcessing() {
        let request = BGProcessingTaskRequest(identifier: "com.wasiq.CoreBGTask.processing")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("BackgroundTaskManager: Scheduled background processing task")
        } catch {
            print("BackgroundTaskManager: Failed to schedule task - \(error)")
        }
    }
    
    private func handleProcessingTask(task: BGProcessingTask) {
        scheduleBackgroundProcessing() // Schedule next one
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        task.expirationHandler = {
            queue.cancelAllOperations()
            print("BackgroundTaskManager: Expired!")
        }
        
        queue.addOperation {
            self.performMLTask()
            task.setTaskCompleted(success: true)
        }
    }
    
    func stopBackgroundProcessing() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        isTaskRunning = false
        updateUI()
    }
    
    private func updateUI() {
        guard let startTime = self.startTime else { return }
        
        let runtime = Date().timeIntervalSince(startTime)
        let runtimeString = String(format: "%.1f seconds", runtime)
        
        let text = """
        Background Task Result:
        Tasks Completed: \(self.taskCount)
        Runtime: \(runtimeString)
        """
        
        DispatchQueue.main.async {
            ViewController.shared?.updateStats(text: text)
        }
    }
    
    func performMLTask() {
        print("BackgroundTaskManager: Starting ML task...")
        
        self.startTime = Date()
        
        for (index, imageName) in images.enumerated() {
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(index * 10)) {
                self.processImage(named: imageName)
            }
        }
    }
    private func processImage(named imageName: String) {
        if let img = UIImage(named: imageName) {
            let result = MLModelHelper().runModelPrediction(with: img)
            if let result = result, result.contains("confidence") {
                print("Prediction result for \(imageName): \(result)")
            }
        }
        
        DispatchQueue.main.async {
            self.taskCount += 1
            self.updateUI()
            self.showNotification()
        }
    }
    
    
    
    func showNotification() {
        guard let startTime = self.startTime else { return }

        let runtime = Date().timeIntervalSince(startTime)
        let runtimeString = String(format: "%.1f seconds", runtime)
 
        let content = UNMutableNotificationContent()
        content.title = "Tasks Completed: \(self.taskCount)"
        content.body = "Background Runtime: \(runtimeString)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Notification error: \(error)")
            }
        }
    }
}
