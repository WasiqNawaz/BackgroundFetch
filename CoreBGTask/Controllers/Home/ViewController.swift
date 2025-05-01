import UIKit

class ViewController: UIViewController {
    static var shared: ViewController?
    
    // MARK: - Outlets
    @IBOutlet weak var resultLbl: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ViewController.shared = self
        self.notificationPermission()
    }
    
    @IBAction func tappedStartTaskBtn(_ sender: Any) {
        BackgroundTaskManager.shared.performMLTask()
    }
    
    func updateStats(text: String) {
        DispatchQueue.main.async {
            self.resultLbl.text = text
        }
    }
    
}

extension ViewController {
    /**** Notification Setup */
    func notificationPermission(){
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
            
            if !granted {
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Notifications Disabled",
                                                  message: "Please enable notifications in Settings to receive task updates.",
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                    alert.addAction(UIAlertAction(title: "Open Settings", style: .default, handler: { _ in
                        if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(appSettings)
                        }
                    }))
                    self.present(alert, animated: true)
                }
            }
        }
    }
}
