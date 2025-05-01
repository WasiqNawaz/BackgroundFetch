import CoreML
import UIKit
import Vision

class MLModelHelper {
    
    private let model: DiceDetector = {
        do {
            let config = MLModelConfiguration()
            return try DiceDetector(configuration: config)
        } catch {
            fatalError("Failed to load DiceDetector.mlmodel: \(error)")
        }
    }()
    
    func runModelPrediction(with image: UIImage) -> String? {
        guard let pixelBuffer = image.pixelBuffer(width: 736, height: 736) else {
            print("Failed to convert UIImage to CVPixelBuffer.")
            return nil
        }
        
        do {
            let input = DiceDetectorInput(
                image: pixelBuffer,
                iouThreshold: 0.45, // or leave nil if you want default
                confidenceThreshold: 0.25 // or leave nil
            )
            
            let output = try model.prediction(input: input)
            
            // Handle output
            let confidenceArray = output.confidence
            let coordinatesArray = output.coordinates
            
            // Example: Just log counts
            return "Predicted \(confidenceArray.count) confidence scores and \(coordinatesArray.count) bounding boxes."
            
        } catch {
            print("Prediction failed: \(error.localizedDescription)")
            return nil
        }
    }
}

