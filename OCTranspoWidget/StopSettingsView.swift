import SwiftUI

struct StopSettingsView: View {
    @ObservedObject var stopManager = StopManager.shared
    @State private var newStopId: String = ""
    @State private var showingAddStop = false
    @State private var editingIndex: Int?
    @State private var editingStopId: String = ""
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Configure your favorite bus stops. The widget will show departures from the first stop in this list.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Favorite Stops")) {
                    if stopManager.favoriteStops.isEmpty {
                        Text("No stops configured")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(stopManager.favoriteStops.enumerated()), id: \.offset) { index, stopId in
                            if editingIndex == index {
                                HStack {
                                    TextField("Stop ID", text: $editingStopId)
                                        .textFieldStyle(.roundedBorder)
                                        .keyboardType(.numberPad)
                                    
                                    Button("Save") {
                                        HapticFeedback.medium()
                                        stopManager.updateStop(at: index, with: editingStopId)
                                        editingIndex = nil
                                    }
                                    .buttonStyle(.borderedProminent)
                                    
                                    Button("Cancel") {
                                        HapticFeedback.medium()
                                        editingIndex = nil
                                    }
                                    .buttonStyle(.bordered)
                                }
                            } else {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Stop \(stopId)")
                                            .font(.headline)
                                        if index == 0 {
                                            Text("Primary (used by widget)")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        HapticFeedback.medium()
                                        editingStopId = stopId
                                        editingIndex = index
                                    }) {
                                        Image(systemName: "pencil")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                        }
                        .onDelete { indexSet in
                            stopManager.favoriteStops.remove(atOffsets: indexSet)
                            stopManager.saveStops()
                        }
                        .onMove { source, destination in
                            stopManager.moveStop(from: source, to: destination)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        HapticFeedback.medium()
                        showingAddStop = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Stop")
                        }
                    }
                }
            }
            .navigationTitle("Configure Stops")
            .toolbar {
                EditButton()
            }
            .sheet(isPresented: $showingAddStop) {
                AddStopView(stopManager: stopManager)
            }
        }
    }
}

struct AddStopView: View {
    @ObservedObject var stopManager: StopManager
    @Environment(\.dismiss) var dismiss
    @State private var stopId: String = ""
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Stop ID")) {
                    TextField("Enter stop ID (e.g., 8922)", text: $stopId)
                        .keyboardType(.numberPad)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Text("Enter the Ottawa Transpo stop ID. You can find stop IDs on bus stop signs or on the Ottawa Transpo website.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticFeedback.medium()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        HapticFeedback.medium()
                        addStop()
                    }
                    .disabled(stopId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func addStop() {
        let trimmed = stopId.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            errorMessage = "Stop ID cannot be empty"
            return
        }
        
        guard trimmed.allSatisfy({ $0.isNumber }) else {
            errorMessage = "Stop ID must contain only numbers"
            return
        }
        
        if stopManager.favoriteStops.contains(trimmed) {
            errorMessage = "This stop is already in your list"
            return
        }
        
        stopManager.addStop(trimmed)
        dismiss()
    }
}

