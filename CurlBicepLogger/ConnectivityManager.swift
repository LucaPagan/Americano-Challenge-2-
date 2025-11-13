//
//  ConnectivityManager.swift
//  CurlBicepLogger
//
//  Created by Luca Pagano on 11/11/25.
//

import Foundation
import WatchConnectivity
import Combine

class ConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {
    
    @Published var targetReps: Int = 10
    
    static let shared = ConnectivityManager()
    
    private let session: WCSession
    
    private override init() {
        self.session = WCSession.default
        super.init()
        
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    // --- Delegate Functions ---
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("WCSession activated with state: \(activationState)")
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif  // os(iOS)
    
    // --- Receiving ---
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let newTarget = message["targetReps"] as? Int {
                print("Received new target: \(newTarget)")
                self.targetReps = newTarget
            }
        }
    }
    
    // --- Sending ---
    func sendTargetReps(_ reps: Int) {
        guard session.isReachable else {
            print("WCSession not reachable")
            return
        }
        
        let message: [String: Any] = ["targetReps": reps]
        session.sendMessage(message, replyHandler: nil) { error in
            print("Error sending message: \(error.localizedDescription)")
        }
    }
}
