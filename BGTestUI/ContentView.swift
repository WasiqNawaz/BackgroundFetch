import SwiftUI

struct ContentView: View {
    @StateObject private var taskManager = BackgroundTaskManager.shared
    @State private var isLogExpanded = false
    
    var body: some View {
        NavigationView {
            List {
                // BackgroundTasks Framework
                Section(header: Text("BackgroundTasks Framework").font(.headline)) {
                    Text("Schedules a cleanup task to run in the background (e.g., when device is charging). Logs progress for 10 seconds.\n\n**Test:**\n1. Tap 'Start' to schedule.\n2. Background app (switch apps or lock device).\n3. Simulate task in Xcode: `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@\"com.example.pocbackground.cleanup\"]`\n4. Check logs (`Documents/background_logs.txt`) and notifications.\n5. Tap 'Stop' to cancel (if scheduled).")
                        .font(.caption)
                    HStack {
                        Button(action: {
                            taskManager.startTask(.backgroundTask)
                        }) {
                            HStack {
                                Image(systemName: "clock")
                                Text("Start")
                            }
                            .frame(minWidth: 100)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(taskManager.currentTask != nil && taskManager.currentTask != .backgroundTask)
                        
                        Button(action: {
                            taskManager.stopTask(.backgroundTask)
                        }) {
                            HStack {
                                Image(systemName: "stop")
                                Text("Stop")
                            }
                            .frame(minWidth: 100)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(taskManager.currentTask != .backgroundTask)
                    }
                    Text("Status: \(taskManager.currentTask == .backgroundTask ? taskManager.statusMessage : "Idle")")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // CoreML + Vision
                Section(header: Text("CoreML + Vision").font(.headline)) {
                    Text("Simulates a 15-second ML task in the background. Logs progress.\n\n**Test:**\n1. Tap 'Start'.\n2. Background app.\n3. Wait 15 seconds.\n4. Check logs and notifications for progress (50% and completion).\n5. Tap 'Stop' to cancel.")
                        .font(.caption)
                    HStack {
                        Button(action: {
                            taskManager.startTask(.coreML)
                        }) {
                            HStack {
                                Image(systemName: "brain")
                                Text("Start")
                            }
                            .frame(minWidth: 100)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(taskManager.currentTask != nil && taskManager.currentTask != .coreML)
                        
                        Button(action: {
                            taskManager.stopTask(.coreML)
                        }) {
                            HStack {
                                Image(systemName: "stop")
                                Text("Stop")
                            }
                            .frame(minWidth: 100)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(taskManager.currentTask != .coreML)
                    }
                    Text("Status: \(taskManager.currentTask == .coreML ? taskManager.statusMessage : "Idle")")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Background Fetch
                Section(header: Text("Background Fetch").font(.headline)) {
                    Text("Fetches data periodically in the background. Saves JSON to a file.\n\n**Test:**\n1. Tap 'Start' to simulate fetch.\n2. Background app.\n3. Check `Documents/fetch_result.json`, logs, and notifications.\n4. Use Xcode: Debug > Simulate Background Fetch.\n5. Tap 'Stop' to cancel.")
                        .font(.caption)
                    HStack {
                        Button(action: {
                            taskManager.startTask(.backgroundFetch)
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.circle")
                                Text("Start")
                            }
                            .frame(minWidth: 100)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(taskManager.currentTask != nil && taskManager.currentTask != .backgroundFetch)
                        
                        Button(action: {
                            taskManager.stopTask(.backgroundFetch)
                        }) {
                            HStack {
                                Image(systemName: "stop")
                                Text("Stop")
                            }
                            .frame(minWidth: 100)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(taskManager.currentTask != .backgroundFetch)
                    }
                    Text("Status: \(taskManager.currentTask == .backgroundFetch ? taskManager.statusMessage : "Idle")")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Background URLSession
                Section(header: Text("Background URLSession").font(.headline)) {
                    Text("Downloads a 10MB file in the background, even if app is terminated.\n\n**Test:**\n1. Tap 'Start'.\n2. Background or terminate app.\n3. Check `Documents/downloaded_file.mp4`, logs, and notifications (50% and completion).\n4. Tap 'Stop' to cancel download.")
                        .font(.caption)
                    HStack {
                        Button(action: {
                            taskManager.startTask(.urlSession)
                        }) {
                            HStack {
                                Image(systemName: "cloud.download")
                                Text("Start")
                            }
                            .frame(minWidth: 100)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(taskManager.currentTask != nil && taskManager.currentTask != .urlSession)
                        
                        Button(action: {
                            taskManager.stopTask(.urlSession)
                        }) {
                            HStack {
                                Image(systemName: "stop")
                                Text("Stop")
                            }
                            .frame(minWidth: 100)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(taskManager.currentTask != .urlSession)
                    }
                    Text("Status: \(taskManager.currentTask == .urlSession ? taskManager.statusMessage : "Idle")")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // beginBackgroundTask
                Section(header: Text("beginBackgroundTask").font(.headline)) {
                    Text("Runs a 30-second task when app is backgrounded. Logs progress.\n\n**Test:**\n1. Tap 'Start'.\n2. Switch to another app.\n3. Wait 30 seconds.\n4. Check logs and notifications (50% and completion).\n5. Tap 'Stop' to cancel.")
                        .font(.caption)
                    HStack {
                        Button(action: {
                            taskManager.startTask(.longRunning)
                        }) {
                            HStack {
                                Image(systemName: "timer")
                                Text("Start")
                            }
                            .frame(minWidth: 100)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(taskManager.currentTask != nil && taskManager.currentTask != .longRunning)
                        
                        Button(action: {
                            taskManager.stopTask(.longRunning)
                        }) {
                            HStack {
                                Image(systemName: "stop")
                                Text("Stop")
                            }
                            .frame(minWidth: 100)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(taskManager.currentTask != .longRunning)
                    }
                    Text("Status: \(taskManager.currentTask == .longRunning ? taskManager.statusMessage : "Idle")")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Background Modes
                Section(header: Text("Background Modes").font(.headline)) {
                    // Audio
                    Text("Plays looping audio in the background. Logs every 10 seconds.\n\n**Test:**\n1. Tap 'Start'.\n2. Background app or lock device.\n3. Listen for audio.\n4. Check logs and notifications (every 30 seconds).\n5. Tap 'Stop' to end playback.")
                        .font(.caption)
                    HStack {
                        Button(action: {
                            taskManager.startTask(.audio)
                        }) {
                            HStack {
                                Image(systemName: "speaker.wave.2")
                                Text("Start")
                            }
                            .frame(minWidth: 100)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(taskManager.currentTask != nil && taskManager.currentTask != .audio)
                        
                        Button(action: {
                            taskManager.stopTask(.audio)
                        }) {
                            HStack {
                                Image(systemName: "stop")
                                Text("Stop")
                            }
                            .frame(minWidth: 100)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(taskManager.currentTask != .audio)
                    }
                    Text("Status: \(taskManager.currentTask == .audio ? taskManager.statusMessage : "Idle")")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    // Location
                    Text("Tracks location in the background. Notifies every 3 seconds.\n\n**Test:**\n1. Tap 'Start'.\n2. Background app.\n3. Move device to trigger updates.\n4. Check logs and notifications (throttled).\n5. Tap 'Stop' to end tracking.")
                        .font(.caption)
                    HStack {
                        Button(action: {
                            taskManager.startTask(.location)
                        }) {
                            HStack {
                                Image(systemName: "location")
                                Text("Start")
                            }
                            .frame(minWidth: 100)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(taskManager.currentTask != nil && taskManager.currentTask != .location)
                        
                        Button(action: {
                            taskManager.stopTask(.location)
                        }) {
                            HStack {
                                Image(systemName: "stop")
                                Text("Stop")
                            }
                            .frame(minWidth: 100)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(taskManager.currentTask != .location)
                    }
                    Text("Status: \(taskManager.currentTask == .location ? taskManager.statusMessage : "Idle")")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    // Bluetooth
                    Text("Scans for Bluetooth devices when started. Logs discoveries.\n\n**Test:**\n1. Tap 'Start'.\n2. Background app.\n3. Use a Bluetooth device nearby.\n4. Check logs and notifications.\n5. Tap 'Stop' to end scanning.")
                        .font(.caption)
                    HStack {
                        Button(action: {
                            taskManager.startTask(.bluetooth)
                        }) {
                            HStack {
                                Image(systemName: "bluetooth")
                                Text("Start")
                            }
                            .frame(minWidth: 100)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(taskManager.currentTask != nil && taskManager.currentTask != .bluetooth)
                        
                        Button(action: {
                            taskManager.stopTask(.bluetooth)
                        }) {
                            HStack {
                                Image(systemName: "stop")
                                Text("Stop")
                            }
                            .frame(minWidth: 100)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(taskManager.currentTask != .bluetooth)
                    }
                    Text("Status: \(taskManager.currentTask == .bluetooth ? taskManager.statusMessage : "Idle")")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Logs
                Section(header: Text("Logs").font(.headline)) {
                    DisclosureGroup("View Logs", isExpanded: $isLogExpanded) {
                        ScrollView {
                            Text(taskManager.logText)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .navigationTitle("Background Tasks PoC")
            .toolbar {
                Button("Clear Logs") {
                    taskManager.clearLogs()
                }
            }
            .onAppear {
                taskManager.loadPersistedLogs()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
