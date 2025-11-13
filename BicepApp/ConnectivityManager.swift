//
//  ConnectivityManager.swift
//  BicepApp
//
//  Created by Luca Pagano on 11/13/25.
//

import Foundation
import WatchConnectivity
import Combine

class ConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {
    
    static let shared = ConnectivityManager()
    
    // --- UserDefaults Keys ---
    private let kTargetRepsKey = "WorkoutTargetReps"
    private let kHistoryKey = "WorkoutHistory"
    private let kHapticsEnabledKey = "WorkoutHapticsEnabled"
    
    // --- Published Data ---
    @Published var targetReps: Int = 10
    @Published var hapticsEnabled: Bool = true
    @Published var history: [WorkoutSet] = []
    @Published var isSessionActive: Bool = false
    
    private var session: WCSession?
    
    // --- Init ---
    private override init() {
        super.init()
        
        // Load saved data
        let loadedReps = UserDefaults.standard.integer(forKey: kTargetRepsKey)
        self.targetReps = (loadedReps == 0) ? 10 : loadedReps
        
        if UserDefaults.standard.object(forKey: kHapticsEnabledKey) == nil {
            self.hapticsEnabled = true
        } else {
            self.hapticsEnabled = UserDefaults.standard.bool(forKey: kHapticsEnabledKey)
        }
        
        // IMPORTANT: Activate the session first
        if WCSession.isSupported() {
            let wcSession = WCSession.default
            wcSession.delegate = self
            self.session = wcSession
            print("🔗 Activating WCSession...")
            wcSession.activate()
        } else {
            print("⚠️ WCSession NOT supported")
        }
        
        loadHistory()
    }
    
    // --- DELEGATE ---
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("❌ Activation Error: \(error.localizedDescription)")
                self.isSessionActive = false
                return
            }
            
            print("✅ WCSession ACTIVATED - State: \(activationState.rawValue)")
            self.isSessionActive = (activationState == .activated)
            
            #if os(iOS)
            print("📱 isPaired: \(session.isPaired)")
            print("📱 isWatchAppInstalled: \(session.isWatchAppInstalled)")

            // As soon as the iPhone activates, send the LAST settings state
            if self.isSessionActive {
                self.sendSettingsToWatch()
            }
            
            #else // os(watchOS)
            print("⌚️ isReachable: \(session.isReachable)")

            // When the watch activates, check if there's a "pending" context
            if self.isSessionActive {
                let context = session.receivedApplicationContext
                
                if !context.isEmpty {
                    print("⌚️ Found context on activation: \(context)")
                    self.handleReceivedMessage(context)
                }
            }
            #endif
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            print("📱 Session inactive")
            self.isSessionActive = false
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            print("📱 Session deactivated - reactivating")
            self.isSessionActive = false
        }
        session.activate()
    }
    
    // Useful for debugging reachability
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            print("📱 Reachability: \(session.isReachable)")
        }
    }
    #endif  // os(iOS)
    
    // --- MESSAGE RECEIVING ---
    
    // Receives `updateApplicationContext` (Settings from iPhone)
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            print("🔄 App Context received: \(applicationContext)")
            self.handleReceivedMessage(applicationContext)
        }
    }
    
    // Receives `transferUserInfo` (Set from Watch)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        DispatchQueue.main.async {
            print("ℹ️ UserInfo received: \(userInfo)")
            self.handleReceivedMessage(userInfo)
        }
    }
    
    // Legacy message handlers (fallback)
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            print("📥 Message received: \(message)")
            self.handleReceivedMessage(message)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            print("📥 Message (Reply) received: \(message)")
            self.handleReceivedMessage(message)
            replyHandler(["status": "success"])
        }
    }
    
    private func handleReceivedMessage(_ message: [String: Any]) {
        // iPhone receives completed set
        if let reps = message["setFinished"] as? Int {
            print("📱 Set completed: \(reps) reps")
            self.addSetToHistory(repCount: reps)
        }
        
        // Watch receives settings
        if let newTarget = message["targetReps"] as? Int {
            print("⌚️ Target updated: \(newTarget)")
            self.targetReps = newTarget
            UserDefaults.standard.set(newTarget, forKey: self.kTargetRepsKey)
        }
        
        if let haptics = message["hapticsEnabled"] as? Bool {
            print("⌚️ Haptics updated: \(haptics)")
            self.hapticsEnabled = haptics
            UserDefaults.standard.set(haptics, forKey: self.kHapticsEnabledKey)
        }
    }
    
    // --- MESSAGE SENDING ---
    
    #if os(iOS)
    // Uses `updateApplicationContext`
    func sendSettingsToWatch() {
        guard let session = session, isSessionActive else {
            print("⚠️ Session not active, cannot send context.")
            return
        }
        
        let context: [String: Any] = [
            "targetReps": targetReps,
            "hapticsEnabled": hapticsEnabled
        ]
        
        do {
            // This sends the latest state. If the watch is off,
            // it will receive it on launch in `activationDidCompleteWith`
            // or in `didReceiveApplicationContext` if already active.
            try session.updateApplicationContext(context)
            print("🔄 App Context sent: \(context)")
        } catch {
            print("❌ Error sending context: \(error.localizedDescription)")
        }
    }
    
    func updateTargetReps(_ reps: Int) {
        self.targetReps = reps
        UserDefaults.standard.set(reps, forKey: kTargetRepsKey)
        print("💾 Saved targetReps: \(reps)")
        sendSettingsToWatch() // Calls the updated function
    }
    
    func updateHaptics(_ enabled: Bool) {
        self.hapticsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: kHapticsEnabledKey)
        print("💾 Saved hapticsEnabled: \(enabled)")
        sendSettingsToWatch() // Calls the updated function
    }
    #endif  // os(iOS)
    
    #if os(watchOS)
    // Uses `transferUserInfo`
    func sendCompletedSet(reps: Int) {
        guard let session = session, isSessionActive else {
            print("⚠️ Session not active, cannot send set.")
            return
        }
        
        let userInfo: [String: Any] = ["setFinished": reps]
        
        // This queues the transfer. The iPhone will receive it
        // via `didReceiveUserInfo` even if the app is in the background or closed.
        session.transferUserInfo(userInfo)
        print("ℹ️ Queued UserInfo (set completed): \(userInfo)")
    }
    #endif  // os(watchOS)
    
    // --- HISTORY MANAGEMENT ---
    
    func addSetToHistory(repCount: Int) {
        let newSet = WorkoutSet(repCount: repCount)
        history.insert(newSet, at: 0)
        if history.count > 5 {
            history.removeLast()
        }
        saveHistory()
        print("📝 Set added to history")
    }
    
    func updateWeight(for setID: UUID, weight: Double) {
        if let index = history.firstIndex(where: { $0.id == setID }) {
            history[index].weight = weight
            saveHistory()
        }
    }
    
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            UserDefaults.standard.set(data, forKey: kHistoryKey)
        } catch {
            print("❌ Save error: \(error.localizedDescription)")
        }
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: kHistoryKey) else {
            return
        }
        do {
            self.history = try JSONDecoder().decode([WorkoutSet].self, from: data)
            print("📝 History loaded: \(history.count) sets")
        } catch {
            print("❌ Load error: \(error.localizedDescription)")
        }
    }
}
