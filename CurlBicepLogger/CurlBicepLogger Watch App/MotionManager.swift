//
//  MotionManager.swift
//  CurlBicepLogger
//
//  Created by Luca Pagano on 11/11/25.
//

import Foundation
import CoreMotion
import Combine
import WatchConnectivity
import WatchKit

class MotionManager: NSObject, WCSessionDelegate, ObservableObject {
    
    private let motionManager = CMMotionManager()
    private let wcSession = WCSession.default
    
    private var dataBuffer: [String] = []
    
    @Published var isRecording = false
    @Published var statusMessage = "Ready"
    
    private let frequency = 1.0 / 50.0
    private var recordingStartTime: Date?
    
    private var recordingTimer: Timer?
    private let recordingDuration: TimeInterval = 30.0
    
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            wcSession.delegate = self
            wcSession.activate()
        }
    }
    
    func startRecording() {
        guard motionManager.isDeviceMotionAvailable else {
            DispatchQueue.main.async { self.statusMessage = "Sensors not available" }
            return
        }
        
        guard wcSession.isReachable else {
            DispatchQueue.main.async { self.statusMessage = "iPhone not connected" }
            return
        }
        
        dataBuffer = []
        dataBuffer.append("timestamp,accel_x,accel_y,accel_z,gyro_x,gyro_y,gyro_z")
        
        motionManager.deviceMotionUpdateInterval = frequency
        recordingStartTime = Date()
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (data, error) in
            guard let self = self, let data = data, let startTime = self.recordingStartTime else { return }
            
            let timestamp = Date().timeIntervalSince(startTime)
            let ax = data.userAcceleration.x
            let ay = data.userAcceleration.y
            let az = data.userAcceleration.z
            let gx = data.rotationRate.x
            let gy = data.rotationRate.y
            let gz = data.rotationRate.z
            
            let csvLine = "\(timestamp),\(ax),\(ay),\(az),\(gx),\(gy),\(gz)"
            self.dataBuffer.append(csvLine)
        }
        
        DispatchQueue.main.async {
            self.isRecording = true
            self.statusMessage = "Recording (30s)..."
        }
        
        recordingTimer?.invalidate()
        
        recordingTimer = Timer.scheduledTimer(
            withTimeInterval: recordingDuration,
            repeats: false
        ) { [weak self] _ in
            print("Timer fired! Auto-stopping recording.")
            
            WKInterfaceDevice.current().play(.notification)
            
            self?.stopRecording()
        }
    }
    
    func stopRecording() {
        if recordingTimer != nil {
            recordingTimer?.invalidate()
            recordingTimer = nil
            print("Timer invalidated (manual stop).")
        }
        
        motionManager.stopDeviceMotionUpdates()
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.statusMessage = "Transferring..."
        }
        
        transferData()
    }
    
    private func transferData() {
        let dataString = dataBuffer.joined(separator: "\n")
        
        guard let data = dataString.data(using: .utf8) else {
            DispatchQueue.main.async { self.statusMessage = "Data conversion error" }
            return
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "curl_data2_\(timestamp).csv"
        let tempURL = getDocumentsDirectory().appendingPathComponent(fileName)
        
        do {
            try data.write(to: tempURL)
            wcSession.transferFile(tempURL, metadata: ["fileName": fileName])
            DispatchQueue.main.async { self.statusMessage = "File Sent!" }
            
        } catch {
            let errorMsg = error.localizedDescription
            DispatchQueue.main.async { self.statusMessage = "Save error: \(errorMsg)" }
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // --- WCSessionDelegate ---
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if activationState == .activated {
                self.statusMessage = "Ready (iPhone connected)"
            } else {
                self.statusMessage = "iPhone not activated"
            }
        }
    }
}
