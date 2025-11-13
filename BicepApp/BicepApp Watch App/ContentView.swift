//
//  ContentView.swift (watchOS)
//  BicepApp Watch App
//
//  Created by Luca Pagano on 11/13/25.
//

import SwiftUI
import WatchConnectivity

struct ContentView: View {
    
    @StateObject private var counter = RepCounterManager()
    @StateObject private var connectivity = ConnectivityManager.shared
    
    // To show the connection status
    @State private var showConnectionStatus = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 4) {
                
                // --- 1. GOAL SECTION ---
                HStack {
                    Text("Goal")
                        .font(.system(.footnote, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(connectivity.targetReps)")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                    
                    // Connection indicator
                    Button(action: {
                        showConnectionStatus = true
                    }) {
                        Image(systemName: WCSession.default.isReachable ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            .font(.caption)
                            .foregroundColor(WCSession.default.isReachable ? .green : .red)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // --- 2. COUNTER SECTION ---
                Text("\(counter.repCount)")
                    .font(.system(size: 95, weight: .bold, design: .rounded))
                    .foregroundColor(counter.isCounting ? .white : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
                // --- 3. STATUS SECTION ---
                Text(counter.statusMessage)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)
                
                Spacer()
                
                // --- 4. ACTION SECTION ---
                if counter.isCounting {
                    Button(action: {
                        counter.stopCounting()
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .background(Color.red.opacity(0.4))
                    .clipShape(Capsule())
                } else {
                    Button(action: {
                        counter.startCounting()
                    }) {
                        Image(systemName: "play.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .background(Color.green.opacity(0.4))
                    .clipShape(Capsule())
                }
            }
            .padding()
            
            // --- 5. FEEDBACK ---
            .sensoryFeedback(.impact, trigger: counter.repHapticTrigger)
            .sensoryFeedback(.success, trigger: counter.goalHapticTrigger)
        }
        .alert("Connection Status", isPresented: $showConnectionStatus) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(connectionStatusMessage)
        }
    }
    
    private var connectionStatusMessage: String {
        let session = WCSession.default
        var message = ""
        
        if !connectivity.isSessionActive {
            message = "⚠️ Session not active\n\nPlease wait...\nIf the problem persists, restart the app."
        } else if session.isReachable {
            message = "✅ Connected to iPhone\n\nTarget: \(connectivity.targetReps) reps\nHaptics: \(connectivity.hapticsEnabled ? "ON" : "OFF")"
        } else {
            message = "⚠️ iPhone not reachable\n\nTo sync:\n1. Open the iPhone app\n2. Return here\n\nSets will be sent when the iPhone is reachable."
        }
        
        return message
    }
}

#Preview {
    ContentView()
}
