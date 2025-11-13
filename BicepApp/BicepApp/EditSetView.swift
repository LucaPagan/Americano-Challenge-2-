//
//  EditSetView.swift
//  BicepApp
//
//  Created by Luca Pagano on 11/13/25.
//

import SwiftUI

struct EditSetView: View {
    
    // To close the modal sheet
    @Environment(\.dismiss) var dismiss
    
    // Received data
    let set: WorkoutSet
    var manager: ConnectivityManager
    
    // Local state for the text field
    @State private var weightString: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Set Details").fontWeight(.medium)) {
                    // Display static data
                    HStack {
                        Text("Repetitions")
                        Spacer()
                        Text("\(set.repCount)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(set.dateString)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Weight (kg)").fontWeight(.medium)) {
                    // Text field for weight
                    TextField("e.g., 10.5", text: $weightString)
                        .keyboardType(.decimalPad) // Numeric keyboard
                }
                
                // Save Button
                Section {
                    Button("Save") {
                        // Converts the string to a number and updates the manager
                        if let weightValue = Double(weightString) {
                            manager.updateWeight(for: set.id, weight: weightValue)
                            dismiss() // Closes the sheet
                        }
                    }
                }
            }
            .navigationTitle("Edit Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss() // Closes the sheet
                    }
                }
            }
            .onAppear {
                // Populate the text field with existing weight, if any
                self.weightString = set.weightString.replacingOccurrences(of: "---", with: "")
            }
        }
    }
}
