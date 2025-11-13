//
//  FileReceiver.swift
//  CurlBicepLogger
//
//  Created by Luca Pagano on 11/11/25.
//

import Foundation
import WatchConnectivity
import Combine

class FileReceiver: NSObject, WCSessionDelegate, ObservableObject {
    
    @Published var receivedFiles: [URL] = []
    @Published var statusMessage = "Waiting for connection..."
    
    private let wcSession = WCSession.default
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            wcSession.delegate = self
            wcSession.activate()
        }
    }
    
    // --- WCSession Delegate (iOS) ---
    
    func sessionDidBecomeInactive(_ session: WCSession) { }
    
    func sessionDidDeactivate(_ session: WCSession) {
        wcSession.activate()
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if activationState == .activated {
                self.statusMessage = "Connected to watch. Ready to receive data."
            } else {
                self.statusMessage = "Watch Connection error."
            }
        }
    }
    
    // --- FILE RECEIVE HANDLER (Background) ---
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        
        let tempURL = file.fileURL
        let fileName: String
        
        if let metadata = file.metadata, let name = metadata["fileName"] as? String {
            fileName = name
        } else {
            fileName = "received_data.csv"
        }
        
        let permanentURL = getDocumentsDirectory().appendingPathComponent(fileName)
        
        do {
            if FileManager.default.fileExists(atPath: permanentURL.path) {
                try FileManager.default.removeItem(at: permanentURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: permanentURL)
            
            DispatchQueue.main.async {
                if !self.receivedFiles.contains(permanentURL) {
                     self.receivedFiles.append(permanentURL)
                }
                self.statusMessage = "Received file: \(fileName)"
            }
        } catch {
            let errorMsg = error.localizedDescription
            DispatchQueue.main.async {
                self.statusMessage = "Error saving file: \(errorMsg)"
            }
        }
    }
    
    // --- FILE RECEIVE HANDLER (Foreground) ---
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        
        if let error = error {
            DispatchQueue.main.async {
                self.statusMessage = "Transfer error: \(error.localizedDescription)"
            }
            return
        }

        let tempURL = fileTransfer.file.fileURL
        let fileName: String
        
        if let metadata = fileTransfer.file.metadata, let name = metadata["fileName"] as? String {
            fileName = name
        } else {
            fileName = "received_data.csv"
        }
        
        let permanentURL = getDocumentsDirectory().appendingPathComponent(fileName)
        
        do {
            if FileManager.default.fileExists(atPath: permanentURL.path) {
                try FileManager.default.removeItem(at: permanentURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: permanentURL)
            
            DispatchQueue.main.async {
                if !self.receivedFiles.contains(permanentURL) {
                     self.receivedFiles.append(permanentURL)
                }
                self.statusMessage = "Received File: \(fileName)"
            }
            
        } catch {
            let errorMsg = error.localizedDescription
            DispatchQueue.main.async {
                self.statusMessage = "Error saving file: \(errorMsg)"
            }
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
