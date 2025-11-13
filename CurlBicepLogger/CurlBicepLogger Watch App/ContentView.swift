//
//  ContentView.swift
//  CurlBicepLogger Watch App
//
//  Created by Luca Pagano on 11/11/25.
//

import SwiftUI
import WatchKit

struct ContentView: View {
    
    @StateObject private var motionManager = MotionManager()
    
    var body: some View {
        VStack(spacing: 8) {
            
            Text("Curl Data Logger")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.secondary)
            
            Spacer()
            
            if motionManager.isRecording {
                HStack(spacing: 6) {
                    Image(systemName: "record.circle.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                    
                    Text(motionManager.statusMessage)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                }
            } else {
                Text(motionManager.statusMessage)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            
            if motionManager.isRecording {
                Button(action: {
                    motionManager.stopRecording()
                }) {
                    Image(systemName: "stop.fill")
                        .font(.title)
                }
                .glassEffect()
                .background(Color.red)
                .clipShape(Capsule())
                
            } else {
                Button(action: {
                    motionManager.startRecording()
                }) {
                    Image(systemName: "play.fill")
                        .font(.title)
                }
                .glassEffect()
                .background(Color.green)
                .clipShape(Capsule())
            }
        }
        .padding(.vertical)
        .sensoryFeedback(.impact, trigger: motionManager.isRecording)
    }
}

extension View {
    func glassEffect() -> some View {
        self
            .padding()
            .frame(height: 55)
            .background(.black.opacity(0.3))
            .foregroundColor(.white)
    }
}

#Preview {
    ContentView()
}
