import UIKit
import BackgroundTasks
import CoreML
import UserNotifications
import CoreVideo

class ViewController: UIViewController {
    //MARK: - Variables
    private var taskCount = 0
    private var startTime: Date?
    
    //MARK: - Outlets
    @IBOutlet weak var resultLbl: UILabel!


    override func viewDidLoad() {
        super.viewDidLoad()
        requestNotificationPermission()   // Ask for notification access
        performMLTask() // Start ML task on button tap
        registerBackgroundTask()         // Register background task handler
    }


    // MARK: - Background Task Registration

    /// Registers background task with system to allow background execution.
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.wasiq.CoreBGTask.processing", using: nil) { task in
            self.scheduleBackgroundTask()  // Reschedule for future
            self.performMLTask()           // Run the ML task
            task.setTaskCompleted(success: true) // Inform system task is done
        }
    }

    /// Submits a background task request to the system.
    func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: "com.wasiq.CoreBGTask.processing")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        try? BGTaskScheduler.shared.submit(request) // Ignore failure silently
    }

    // MARK: - ML Task Execution

    /// Loops over images and sends each through the model asynchronously.
    func performMLTask() {
        ///iOS limits to 64 scheduled notifications. Clear old ones if needed:
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        startTime = Date()
        // you can change count from 100 to more if you need more images to test
        let images = Array(repeating: ["1", "2", "3"], count: 100).flatMap { $0 }

        for (index, name) in images.enumerated() {
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(index * 10)) { // 10 seconds per iteration you can increase time from here
                guard let img = UIImage(named: name),
                      let result = self.runModelPrediction(with: img) else { return }

                self.taskCount += 1
                let runtime = Date().timeIntervalSince(self.startTime ?? Date())
                let text = "Completed Tasks: \(self.taskCount)\nRuntime: \(String(format: "%.1f", runtime))s"

                DispatchQueue.main.async {
                    self.resultLbl.text = text  // Update UI with result
                }

                let body = "Runtime: \(String(format: "%.1f", runtime))s"
                if self.taskCount == images.count {
                    self.sendNotification(title: "✅ All Tasks Completed", body: body)
                }

            }
        }
    }

    // MARK: - CoreML Prediction

    /// Converts image to pixel buffer, runs model prediction, returns summary string.
    func runModelPrediction(with image: UIImage) -> String? {
        guard let buffer = pixelBuffer(from: image, width: 736, height: 736) else { return nil }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all  // Use GPU, Neural Engine, CPU
            let model = try DiceDetector(configuration: config)

            let input = DiceDetectorInput(image: buffer, iouThreshold: 0.45, confidenceThreshold: 0.25)
            let output = try model.prediction(input: input)
            return "Detected \(output.confidence.count) objects."
        } catch {
            print("Prediction error: \(error)")
            return nil
        }
    }

    // MARK: - Notifications

    /// Triggers a local notification with provided content.
    func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Requests permission to send local notifications.
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if !granted {
                // Prompt user to enable notifications manually
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Notifications Disabled",
                                                  message: "Please enable them in Settings.",
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    })
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    // MARK: - UIImage to PixelBuffer (Moved from extension)

    /// Converts UIImage to CVPixelBuffer for ML input.
    func pixelBuffer(from image: UIImage, width: Int, height: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attrs: [NSObject: AnyObject] = [
            kCVPixelBufferCGImageCompatibilityKey: true as AnyObject,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true as AnyObject
        ]

        CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                            kCVPixelFormatType_32ARGB, attrs as CFDictionary, &buffer)

        guard let pxBuffer = buffer else { return nil }

        CVPixelBufferLockBaseAddress(pxBuffer, [])
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(pxBuffer),
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(pxBuffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
            return nil
        }

        UIGraphicsPushContext(context)
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pxBuffer, [])

        return pxBuffer
    }
}
