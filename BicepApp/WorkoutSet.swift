//
//  WorkoutSet.swift
//  BicepApp
//
//  Created by Luca Pagano on 11/13/25.
//

import Foundation

struct WorkoutSet: Identifiable, Codable {
    var id: UUID          // Identificatore unico per la lista
    var date: Date          // La data e ora in cui la serie è stata completata
    var repCount: Int       // Il numero di ripetizioni fatte
    var weight: Double?     // Il peso usato (opzionale, così l'utente può aggiungerlo)
    
    // Costruttore per una nuova serie
    init(repCount: Int) {
        self.id = UUID()
        self.date = Date()
        self.repCount = repCount
        self.weight = nil // Il peso è nullo finché non lo aggiunge l'utente
    }
    
    // Helper per mostrare la data in modo carino
    var dateString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    // Helper per mostrare il peso
    var weightString: String {
        if let weight = weight {
            // Rimuove ".0" se è un numero intero (es. 10.0 -> 10)
            return String(format: "%g", weight)
        } else {
            return "---"
        }
    }
}
