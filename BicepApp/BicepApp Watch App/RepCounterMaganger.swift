//
//  RepCounterManager.swift
//  BicepApp Watch App
//
//  Created by Luca Pagano on 11/13/25.
//

import Foundation
import CoreMotion
import CoreML
import Combine

enum RepState {
    case in_rep
    case other
}

// Ensure "FianlModelV1" is the exact name of your .mlmodel file
typealias ActivityClassifierModel = FianlModelV1

class RepCounterManager: ObservableObject {
    
    // --- Core Managers ---
    private let motionManager = CMMotionManager()
    private var model: ActivityClassifierModel!
    
    // --- Connectivity ---
    private var connectivity = ConnectivityManager.shared
    @Published var goalHapticTrigger: Bool = false
    @Published var repHapticTrigger: Bool = false
    
    // --- Data Buffer (Fast Sliding Window) ---
    private let predictionWindowSize = 100 // 100 samples (2-second window)
    private let samplingRate = 50.0      // 50Hz (50 samples/sec)
    private let slideWindowOverlap = 25    // Predict every 0.5 seconds
    private var dataBufferIndex = 0
    
    private var accel_x_buffer: MLMultiArray!
    private var accel_y_buffer: MLMultiArray!
    private var accel_z_buffer: MLMultiArray!
    private var gyro_x_buffer: MLMultiArray!
    private var gyro_y_buffer: MLMultiArray!
    private var gyro_z_buffer: MLMultiArray!
    
    private var statelessStateIn: MLMultiArray! // "Empty" buffer

    // --- UI State Properties ---
    @Published var repCount = 0
    @Published var statusMessage = "Ready"
    @Published var isCounting = false
    
    private var repState: RepState = .other
    
    // --- Jitter-Filter Logic ---
    private var recentPredictions: [String] = []
    // Use a history of 5 predictions (5 * 0.5s = 2.5 seconds)
    private let predictionHistorySize = 5
    private let confidenceThreshold = 0.50
    
    // How many "curl" predictions out of 5 are needed to confirm?
    private let curlConfirmationThreshold = 3
    
    // --- Initialization ---
    init() {
        do {
            model = try ActivityClassifierModel(configuration: MLModelConfiguration())
            
            let shape: [NSNumber] = [NSNumber(value: predictionWindowSize)]
            accel_x_buffer = try MLMultiArray(shape: shape, dataType: .double)
            accel_y_buffer = try MLMultiArray(shape: shape, dataType: .double)
            accel_z_buffer = try MLMultiArray(shape: shape, dataType: .double)
            gyro_x_buffer = try MLMultiArray(shape: shape, dataType: .double)
            gyro_y_buffer = try MLMultiArray(shape: shape, dataType: .double)
            gyro_z_buffer = try MLMultiArray(shape: shape, dataType: .double)
            
            let stateShape: [NSNumber] = [400]
            statelessStateIn = try MLMultiArray(shape: stateShape, dataType: .double)
            for i in 0..<stateShape[0].intValue { statelessStateIn[i] = 0.0 }
            
        } catch {
            let errorMsg = error.localizedDescription
            DispatchQueue.main.async {
                self.statusMessage = "Model Error: \(errorMsg)"
            }
        }
    }

    // --- Public Controls ---
    func startCounting() {
        guard motionManager.isDeviceMotionAvailable else {
            DispatchQueue.main.async { self.statusMessage = "Sensors not available" }
            return
        }
        
        // Reset everything
        self.repCount = 0
        self.repState = .other
        self.recentPredictions.removeAll()
        self.resetBuffers()
        self.goalHapticTrigger = false
        self.repHapticTrigger = false
        
        motionManager.deviceMotionUpdateInterval = 1.0 / samplingRate
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (data, error) in
            guard let self = self, let data = data, error == nil else { return }
            self.addSensorDataToBuffer(accel: data.userAcceleration, gyro: data.rotationRate)
        }
        
        DispatchQueue.main.async {
            self.isCounting = true
            self.statusMessage = "Started!"
        }
    }
    
    func stopCounting() {
        motionManager.stopDeviceMotionUpdates()
        DispatchQueue.main.async {
            self.isCounting = false
            self.statusMessage = "Ready"
        }
        
        if self.repCount > 0 {
            print("⌚️ Sending completed set: \(self.repCount) reps")
            // Make sure the function in ConnectivityManager is named 'sendCompletedSet'
            self.connectivity.sendCompletedSet(reps: self.repCount)
        }
    }
    
    // --- Data Handling (Sliding Window) ---
    
    private func addSensorDataToBuffer(accel: CMAcceleration, gyro: CMRotationRate) {
        accel_x_buffer[dataBufferIndex] = accel.x as NSNumber
        accel_y_buffer[dataBufferIndex] = accel.y as NSNumber
        accel_z_buffer[dataBufferIndex] = accel.z as NSNumber
        gyro_x_buffer[dataBufferIndex] = gyro.x as NSNumber
        gyro_y_buffer[dataBufferIndex] = gyro.y as NSNumber
        gyro_z_buffer[dataBufferIndex] = gyro.z as NSNumber
        
        dataBufferIndex += 1
        
        if dataBufferIndex == predictionWindowSize {
            predict()
            slideBuffers()
            dataBufferIndex = predictionWindowSize - slideWindowOverlap
        }
    }
    
    private func slideBuffers() {
        let samplesToKeep = predictionWindowSize - slideWindowOverlap
        for i in 0..<samplesToKeep {
            accel_x_buffer[i] = accel_x_buffer[i + slideWindowOverlap]
            accel_y_buffer[i] = accel_y_buffer[i + slideWindowOverlap]
            accel_z_buffer[i] = accel_z_buffer[i + slideWindowOverlap]
            gyro_x_buffer[i] = gyro_x_buffer[i + slideWindowOverlap]
            gyro_y_buffer[i] = gyro_y_buffer[i + slideWindowOverlap]
            gyro_z_buffer[i] = gyro_z_buffer[i + slideWindowOverlap]
        }
    }
    
    private func resetBuffers() {
        for i in 0..<predictionWindowSize {
            accel_x_buffer[i] = 0.0
            accel_y_buffer[i] = 0.0
            accel_z_buffer[i] = 0.0
            gyro_x_buffer[i] = 0.0
            gyro_y_buffer[i] = 0.0
            gyro_z_buffer[i] = 0.0
        }
        dataBufferIndex = 0
    }
    
    // --- Prediction Logic (Stateless) ---
    
    private func predict() {
        
        let modelInput = FianlModelV1Input(
            accel_x: accel_x_buffer,
            accel_y: accel_y_buffer,
            accel_z: accel_z_buffer,
            gyro_x: gyro_x_buffer,
            gyro_y: gyro_y_buffer,
            gyro_z: gyro_z_buffer,
            stateIn: self.statelessStateIn
        )
        
        guard let prediction = try? model.prediction(input: modelInput) else {
            DispatchQueue.main.async { self.statusMessage = "Prediction Error" }
            return
        }
        
        var finalLabel = prediction.label
        
        // Confidence Filter
        let labelProbs = prediction.labelProbability
        if let confidence = labelProbs[prediction.label] {
            if (confidence) < confidenceThreshold {
                finalLabel = "other"
            }
        } else {
            finalLabel = "other"
        }
        
        DispatchQueue.main.async {
            self.processPrediction(finalLabel)
        }
    }
    
    // --- State Machine (Simplified) ---
    
    private func processPrediction(_ label: String) {
        
        // --- ANTI-JITTER FILTER (Smoothing) ---
        recentPredictions.append(label)
        if recentPredictions.count > predictionHistorySize {
            recentPredictions.removeFirst()
        }
        
        let curlCount = recentPredictions.filter { $0 == "bicep_curl" }.count
        
        // If 3 of 5 say "curl", it's a curl.
        let smoothedLabel = curlCount >= curlConfirmationThreshold ? "bicep_curl" : "other"
        
        // --- SIMPLE STATE MACHINE (based ONLY on 'smoothedLabel') ---
        switch self.repState {
            
        case .other:
            // If the filtered signal says "curl", START the rep
            if smoothedLabel == "bicep_curl" {
                self.repState = .in_rep
                self.statusMessage = "In Rep..."
            }
            
        case .in_rep:
            // If the filtered signal says "other", FINISH the rep
            if smoothedLabel == "other" {
                self.repCount += 1
                self.repState = .other
                self.statusMessage = "Done!"
                
                // Handle haptics
                if self.connectivity.hapticsEnabled {
                    self.repHapticTrigger.toggle()
                }
                if self.repCount == self.connectivity.targetReps {
                    self.goalHapticTrigger.toggle()
                    self.statusMessage = "Goal Reached!"
                }
            }
        }
    }
}
