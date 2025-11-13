//
//  ContentView.swift (iOS)
//  BicepApp
//
//  Created by Luca Pagano on 11/13/25.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject private var connectivity = ConnectivityManager.shared
    @State private var setBeingEdited: WorkoutSet? = nil
    @State private var localReps: Int = 10
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // --- SETTINGS SECTION ---
                Form {
                    Section(header: Text("Workout Settings").fontWeight(.medium)) {
                        
                        // Haptics
                        Toggle(isOn: Binding(
                            get: { connectivity.hapticsEnabled },
                            set: { connectivity.updateHaptics($0) }
                        )) {
                            Label("Haptics per Rep", systemImage: "iphone.radiowaves.left.and.right")
                        }
                        
                        // Goal
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Repetition Goal")
                                .font(.headline)
                            Text("Set your goal for the set.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Stepper(value: $localReps, in: 1...50) {
                                HStack {
                                    Text("Repetitions:")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(localReps)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                }
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
                .frame(height: 220)
                .scrollDisabled(true)
                
                // --- SEND BUTTON ---
                Button(action: {
                    connectivity.updateTargetReps(localReps)
                }) {
                    Label("Send Goal to Watch", systemImage: "applewatch.radiowaves.left.and.right")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
                
                // --- HISTORY ---
                List {
                    Section(header: Text("Last 5 Sets History").fontWeight(.medium)) {
                        if connectivity.history.isEmpty {
                            Text("Complete a set on your watch to see it here.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(connectivity.history) { set in
                                Button(action: {
                                    self.setBeingEdited = set
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(set.repCount) Repetitions")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            Text(set.dateString)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Text("\(set.weightString) kg")
                                            .font(.title2.weight(.bold))
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Curl Counter")
            .onAppear {
                // Sync the stepper with the saved data
                self.localReps = connectivity.targetReps
            }
            .sheet(item: $setBeingEdited) { set in
                EditSetView(set: set, manager: connectivity)
            }
        }
    }
}

#Preview {
    ContentView()
}
