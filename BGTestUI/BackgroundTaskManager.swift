import Foundation
import BackgroundTasks
import CoreLocation
import AVFoundation
import CoreBluetooth
import CoreML
import Vision
import UserNotifications
import UIKit

class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()
    
    @Published var logText: String = "Logs:\n"
    @Published var currentTask: TaskType?
    @Published var statusMessage: String = "Idle"
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var locationManager: CLLocationManager?
    private var audioPlayer: AVAudioPlayer?
    private var centralManager: CBCentralManager?
    private let urlSession: URLSession
    private var downloadTask: URLSessionDownloadTask?
    private let logFileURL: URL
    var lastLocationNotification: Date?
    private var taskStartTime: Date?
    private var coreMLTask: DispatchWorkItem?
    
    enum TaskType: String {
        case backgroundTask = "Background Task"
        case coreML = "CoreML + Vision"
        case backgroundFetch = "Background Fetch"
        case urlSession = "URLSession"
        case longRunning = "Long Running Task"
        case audio = "Audio"
        case location = "Location"
        case bluetooth = "Bluetooth"
    }
    
    private init() {
        let config = URLSessionConfiguration.background(withIdentifier: "com.example.pocbackground.download")
        urlSession = URLSession(configuration: config, delegate: URLSessionDelegateHandler.shared, delegateQueue: nil)
        
        locationManager = CLLocationManager()
        locationManager?.delegate = LocationDelegateHandler.shared
        locationManager?.requestAlwaysAuthorization()
        
        centralManager = CBCentralManager(delegate: BluetoothDelegateHandler.shared, queue: nil)
        
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        logFileURL = documents.appendingPathComponent("background_logs.txt")
        
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    @objc func appDidEnterBackground() {
        if let task = currentTask, let startTime = taskStartTime {
            let seconds = Int(Date().timeIntervalSince(startTime))
            appendLog("\(task.rawValue) entered background after \(seconds) seconds")
            sendNotification(title: "\(task.rawValue) in Background", body: "Task continues after \(seconds) seconds.")
        }
    }
    
    // MARK: - Task Management
    func startTask(_ task: TaskType) {
        guard currentTask == nil else {
            appendLog("\(task.rawValue) blocked: \(currentTask!.rawValue) is running")
            return
        }
        currentTask = task
        taskStartTime = Date()
        statusMessage = "Started"
        
        switch task {
        case .backgroundTask:
            scheduleCleanupTask()
        case .coreML:
            performCoreMLVisionTask()
        case .backgroundFetch:
            performBackgroundFetch { _ in
                DispatchQueue.main.async {
                    self.currentTask = nil
                    self.statusMessage = "Idle"
                }
            }
        case .urlSession:
            startBackgroundDownload()
        case .longRunning:
            startLongRunningTask()
        case .audio:
            startBackgroundAudio()
        case .location:
            startLocationUpdates()
        case .bluetooth:
            startBluetoothScanning()
        }
    }
    
    func stopTask(_ task: TaskType) {
        guard currentTask == task else { return }
        
        switch task {
        case .backgroundTask:
            // BGTaskScheduler tasks can't be cancelled once scheduled; clear state
            appendLog("BGTask: cleanup stopped (schedule cleared)")
            currentTask = nil
            statusMessage = "Idle"
        case .coreML:
            coreMLTask?.cancel()
            appendLog("CoreML + Vision task stopped")
            currentTask = nil
            statusMessage = "Idle"
        case .backgroundFetch:
            appendLog("Background Fetch stopped")
            currentTask = nil
            statusMessage = "Idle"
        case .urlSession:
            downloadTask?.cancel()
            appendLog("Background URLSession download stopped")
            currentTask = nil
            statusMessage = "Idle"
        case .longRunning:
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
            appendLog("Long-running task stopped")
            currentTask = nil
            statusMessage = "Idle"
        case .audio:
            audioPlayer?.stop()
            try? AVAudioSession.sharedInstance().setActive(false)
            appendLog("Background audio stopped")
            currentTask = nil
            statusMessage = "Idle"
        case .location:
            stopLocationUpdates()
        case .bluetooth:
            stopBluetoothScanning()
        }
    }
    
    // MARK: - Logging
    func appendLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)\n"
        
        DispatchQueue.main.async {
            self.logText += logMessage
        }
        
        do {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                let handle = try FileHandle(forWritingTo: logFileURL)
                handle.seekToEndOfFile()
                handle.write(logMessage.data(using: .utf8)!)
                handle.closeFile()
            } else {
                try logMessage.write(to: logFileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Log file error: \(error)")
        }
        
        print(logMessage)
    }
    
    func loadPersistedLogs() {
        do {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                let savedLogs = try String(contentsOf: logFileURL, encoding: .utf8)
                DispatchQueue.main.async {
                    self.logText = "Logs:\n" + savedLogs
                }
            }
        } catch {
            appendLog("Failed to load persisted logs: \(error)")
        }
    }
    
    func clearLogs() {
        logText = "Logs:\n"
        try? FileManager.default.removeItem(at: logFileURL)
    }
    
    func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.appendLog("Notification error: \(error)")
            }
        }
    }
    
    // MARK: - 1. BackgroundTasks Framework
    func scheduleCleanupTask() {
        let request = BGAppRefreshTaskRequest(identifier: "com.example.pocbackground.cleanup")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            appendLog("Scheduled BGTask: cleanup")
            sendNotification(title: "BGTask Scheduled", body: "Cleanup task scheduled.")
            DispatchQueue.main.async {
                self.statusMessage = "Scheduled"
            }
        } catch {
            appendLog("Failed to schedule BGTask: \(error)")
            DispatchQueue.main.async {
                self.currentTask = nil
                self.statusMessage = "Idle"
            }
        }
    }
    
    func handleCleanupTask(task: BGAppRefreshTask) {
        appendLog("Running BGTask: cleanup")
        sendNotification(title: "BGTask Running", body: "Cleanup task started.")
        
        DispatchQueue.global().async {
            for i in 1...10 {
                self.appendLog("BGTask cleanup progress: \(i)/10")
                DispatchQueue.main.async {
                    self.statusMessage = "Progress: \(i)/10"
                }
                sleep(1)
            }
            self.appendLog("BGTask cleanup completed")
            self.sendNotification(title: "BGTask Completed", body: "Cleanup task finished.")
            task.setTaskCompleted(success: true)
            DispatchQueue.main.async {
                self.currentTask = nil
                self.statusMessage = "Idle"
            }
        }
        
        scheduleCleanupTask()
    }
    
    // MARK: - 2. CoreML + Vision
    func performCoreMLVisionTask() {
        appendLog("Starting CoreML + Vision task")
        sendNotification(title: "CoreML Task Started", body: "Simulating ML processing.")
        
        coreMLTask = DispatchWorkItem {
            for i in 1...15 {
                if self.coreMLTask?.isCancelled ?? false { break }
                self.appendLog("CoreML + Vision progress: \(i)/15")
                DispatchQueue.main.async {
                    self.statusMessage = "Progress: \(i)/15"
                }
                if i == 8 {
                    self.sendNotification(title: "CoreML Progress", body: "50% complete.")
                }
                sleep(1)
            }
            if !(self.coreMLTask?.isCancelled ?? false) {
                self.appendLog("CoreML + Vision task completed")
                self.sendNotification(title: "CoreML Task Completed", body: "ML processing finished.")
                DispatchQueue.main.async {
                    self.currentTask = nil
                    self.statusMessage = "Idle"
                }
            }
        }
        
        DispatchQueue.global().async(execute: coreMLTask!)
    }
    
    // MARK: - 3. Background Fetch
    func performBackgroundFetch(completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        appendLog("Performing Background Fetch")
        sendNotification(title: "Background Fetch Started", body: "Fetching data.")
        DispatchQueue.main.async {
            self.statusMessage = "Fetching"
        }
        
        let url = URL(string: "https://jsonplaceholder.typicode.com/todos/1")!
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                self.appendLog("Background Fetch failed: \(error)")
                self.sendNotification(title: "Background Fetch Failed", body: "Error: \(error.localizedDescription)")
                completionHandler(.failed)
                DispatchQueue.main.async {
                    self.currentTask = nil
                    self.statusMessage = "Idle"
                }
                return
            }
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) {
                let fetchFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("fetch_result.json")
                try? data.write(to: fetchFileURL)
                self.appendLog("Background Fetch succeeded: \(json)")
                self.sendNotification(title: "Background Fetch Succeeded", body: "Data saved to fetch_result.json")
                completionHandler(.newData)
                DispatchQueue.main.async {
                    self.statusMessage = "Completed"
                }
            } else {
                self.appendLog("Background Fetch: no new data")
                self.sendNotification(title: "Background Fetch", body: "No new data.")
                completionHandler(.noData)
                DispatchQueue.main.async {
                    self.statusMessage = "No Data"
                }
            }
            DispatchQueue.main.async {
                self.currentTask = nil
                self.statusMessage = "Idle"
            }
        }
        task.resume()
    }
    
    // MARK: - 4. Background URLSession
    func startBackgroundDownload() {
        appendLog("Starting Background URLSession download")
        sendNotification(title: "Download Started", body: "Downloading file.")
        DispatchQueue.main.async {
            self.statusMessage = "Downloading"
        }
        
        let url = URL(string: "https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_10mb.mp4")!
        downloadTask = urlSession.downloadTask(with: url)
        downloadTask?.resume()
    }
    
    func handleBackgroundURLSession(identifier: String, completionHandler: @escaping () -> Void) {
        appendLog("Handling Background URLSession: \(identifier)")
        URLSessionDelegateHandler.shared.backgroundCompletionHandler = completionHandler
    }
    
    // MARK: - 5. beginBackgroundTask
    func startLongRunningTask() {
        appendLog("Starting long-running task")
        sendNotification(title: "Long-Running Task Started", body: "Processing started.")
        DispatchQueue.main.async {
            self.statusMessage = "Processing"
        }
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "LongRunningTask") {
            self.appendLog("Long-running task expired")
            self.sendNotification(title: "Long-Running Task Expired", body: "Task reached iOS time limit.")
            UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
            self.backgroundTaskID = .invalid
            DispatchQueue.main.async {
                self.currentTask = nil
                self.statusMessage = "Idle"
            }
        }
        
        DispatchQueue.global().async {
            for i in 1...30 {
                guard self.backgroundTaskID != .invalid else { break }
                self.appendLog("Long-running task progress: \(i)/30")
                DispatchQueue.main.async {
                    self.statusMessage = "Progress: \(i)/30"
                }
                if i == 15 {
                    self.sendNotification(title: "Long-Running Progress", body: "50% complete.")
                }
                if i % 10 == 0 {
                    self.appendLog("Long-running task still active in background")
                    self.sendNotification(title: "Long-Running Background", body: "Task active at \(i) seconds.")
                }
                sleep(1)
            }
            if self.backgroundTaskID != .invalid {
                self.appendLog("Long-running task completed")
                self.sendNotification(title: "Long-Running Task Completed", body: "Processing finished.")
                UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
                self.backgroundTaskID = .invalid
                DispatchQueue.main.async {
                    self.currentTask = nil
                    self.statusMessage = "Idle"
                }
            }
        }
    }
    
    // MARK: - 6. Background Modes
    // Audio
    func startBackgroundAudio() {
        appendLog("Starting background audio")
        sendNotification(title: "Background Audio Started", body: "Playing audio.")
        DispatchQueue.main.async {
            self.statusMessage = "Playing"
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            
            let url = Bundle.main.url(forResource: "sample", withExtension: "mp3")!
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.play()
            
            DispatchQueue.global().async {
                var lastNotification = Date()
                var seconds = 0
                while self.audioPlayer?.isPlaying == true {
                    seconds += 10
                    self.appendLog("Background audio playing for \(seconds) seconds")
                    DispatchQueue.main.async {
                        self.statusMessage = "Playing for \(seconds) seconds"
                    }
                    if Date().timeIntervalSince(lastNotification) >= 30 {
                        self.sendNotification(title: "Background Audio", body: "Audio playing for \(seconds) seconds.")
                        lastNotification = Date()
                    }
                    sleep(10)
                }
                self.appendLog("Background audio stopped")
                DispatchQueue.main.async {
                    self.currentTask = nil
                    self.statusMessage = "Idle"
                }
            }
            
            appendLog("Background audio playing")
        } catch {
            appendLog("Background audio failed: \(error)")
            sendNotification(title: "Background Audio Failed", body: "Error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.currentTask = nil
                self.statusMessage = "Idle"
            }
        }
    }
    
    // Location
    func startLocationUpdates() {
        appendLog("Starting background location updates")
        sendNotification(title: "Location Updates Started", body: "Tracking location.")
        DispatchQueue.main.async {
            self.statusMessage = "Tracking"
        }
        locationManager?.allowsBackgroundLocationUpdates = true
        locationManager?.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager?.stopUpdatingLocation()
        appendLog("Stopped location updates")
        sendNotification(title: "Location Updates Stopped", body: "Tracking ended.")
        DispatchQueue.main.async {
            self.currentTask = nil
            self.statusMessage = "Idle"
        }
    }
    
    // Bluetooth
    func startBluetoothScanning() {
        appendLog("Starting Bluetooth scanning")
        sendNotification(title: "Bluetooth Scanning Started", body: "Scanning for devices.")
        DispatchQueue.main.async {
            self.statusMessage = "Scanning"
        }
        if centralManager?.state == .poweredOn {
            centralManager?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        }
    }
    
    func stopBluetoothScanning() {
        centralManager?.stopScan()
        appendLog("Stopped Bluetooth scanning")
        sendNotification(title: "Bluetooth Scanning Stopped", body: "Scanning ended.")
        DispatchQueue.main.async {
            self.currentTask = nil
            self.statusMessage = "Idle"
        }
    }
}

// MARK: - URLSession Delegate
class URLSessionDelegateHandler: NSObject, URLSessionDownloadDelegate {
    static let shared = URLSessionDelegateHandler()
    var backgroundCompletionHandler: (() -> Void)?
    private var lastProgressNotification: Float = 0
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let destURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("downloaded_file.mp4")
        try? FileManager.default.moveItem(at: location, to: destURL)
        BackgroundTaskManager.shared.appendLog("Background download completed: \(destURL.lastPathComponent)")
        BackgroundTaskManager.shared.sendNotification(title: "Download Completed", body: "File saved to downloaded_file.mp4")
        DispatchQueue.main.async {
            BackgroundTaskManager.shared.currentTask = nil
            BackgroundTaskManager.shared.statusMessage = "Idle"
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        BackgroundTaskManager.shared.appendLog("Download progress: \(Int(progress * 100))%")
        DispatchQueue.main.async {
            BackgroundTaskManager.shared.statusMessage = "Progress: \(Int(progress * 100))%"
        }
        if progress >= lastProgressNotification + 0.5 {
            BackgroundTaskManager.shared.sendNotification(title: "Download Progress", body: "\(Int(progress * 100))% complete.")
            lastProgressNotification = progress
        }
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        BackgroundTaskManager.shared.appendLog("Background URLSession finished")
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}

// MARK: - Location Delegate
class LocationDelegateHandler: NSObject, CLLocationManagerDelegate {
    static let shared = LocationDelegateHandler()
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let manager = BackgroundTaskManager.shared
        manager.appendLog("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        DispatchQueue.main.async {
            manager.statusMessage = "Lat: \(String(format: "%.4f", location.coordinate.latitude)), Lon: \(String(format: "%.4f", location.coordinate.longitude))"
        }
        
        let now = Date()
        if manager.lastLocationNotification == nil || now.timeIntervalSince(manager.lastLocationNotification!) >= 3 {
            manager.sendNotification(title: "Location Updated", body: "Lat: \(location.coordinate.latitude), Lon: \(location.coordinate.longitude)")
            manager.lastLocationNotification = now
        }
    }
}

// MARK: - Bluetooth Delegate
class BluetoothDelegateHandler: NSObject, CBCentralManagerDelegate {
    static let shared = BluetoothDelegateHandler()
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            BackgroundTaskManager.shared.appendLog("Bluetooth powered on")
            if BackgroundTaskManager.shared.currentTask == .bluetooth {
                BackgroundTaskManager.shared.startBluetoothScanning()
            }
        case .poweredOff:
            BackgroundTaskManager.shared.appendLog("Bluetooth powered off")
            BackgroundTaskManager.shared.sendNotification(title: "Bluetooth Off", body: "Bluetooth is powered off.")
            BackgroundTaskManager.shared.stopBluetoothScanning()
        default:
            BackgroundTaskManager.shared.appendLog("Bluetooth state: \(central.state.rawValue)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        BackgroundTaskManager.shared.appendLog("Discovered Bluetooth peripheral: \(peripheral.name ?? "Unknown")")
        BackgroundTaskManager.shared.sendNotification(title: "Bluetooth Discovery", body: "Found peripheral: \(peripheral.name ?? "Unknown")")
        DispatchQueue.main.async {
            BackgroundTaskManager.shared.statusMessage = "Found: \(peripheral.name ?? "Unknown")"
        }
    }
}
