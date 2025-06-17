//
//  SessionDetail.swift
//  Neurocular
//
//  Created by Max Taggart on 6/8/25.
//

import SwiftUI

struct SessionDetail: View {
    let session: Session
    @Binding var navigation_path: NavigationPath
    @State private var notes: String
    @State private var debounce_timer: Timer?
    let storage_manager: StorageManager
    
    init(session: Session, navigation_path: Binding<NavigationPath>, storage_manager: StorageManager) {
        self.session = session
        self._navigation_path = navigation_path
        self.storage_manager = storage_manager
        self._notes = State(initialValue: session.notes)
    }
    
    private func debounced_update_notes(_ newValue: String) {
        // Cancel any existing timer
        debounce_timer?.invalidate()
        
        // Create a new timer
        debounce_timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: false) { _ in
            // Create a new session with updated notes
            let updated_session = Session(
                id: session.id,
                demographics: session.demographics,
                rows: session.rows,
                created: session.created,
                notes: newValue
            )
            // Update the session in storage
            storage_manager.update_session(updated_session)
        }
    }
    
    private func save_current_notes() {
        // Cancel any pending timer
        guard let debounce_timer = debounce_timer else {
            return
        }
        debounce_timer.invalidate()
        self.debounce_timer = nil
        
        // Save the current notes immediately
        let updated_session = Session(
            id: session.id,
            demographics: session.demographics,
            rows: session.rows,
            created: session.created,
            notes: notes
        )
        storage_manager.update_session(updated_session)
    }
    
    var body: some View {
        ScrollView{
            VStack {
                SessionInfo(session: session)
                DemographicInfo(patient_info: session.demographics)
                GazeAnglePlot(
                    transforms: session.rows.map {row in row.transforms},
                    degrees_per_second: session.rows.map {row in row.degrees_per_second}
                ).frame(height: 300)
                
                VStack(alignment: .leading) {
                    Text("Notes")
                        .font(.headline)
                        .padding(.horizontal)
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        .onChange(of: notes) { _, newValue in
                            debounced_update_notes(newValue)
                        }
                }
            }
        }
        .onDisappear {
            save_current_notes()
        }
    }
}

struct DemographicInfo: View {
    let patient_info: PatientInfo?
    
    struct BirthdayDateFormatter {
        var formatter = DateFormatter()
        
        init() {
            self.formatter.dateStyle = .short
            self.formatter.timeStyle = .none
        }
    }
    let date_formatter = BirthdayDateFormatter()
    
    var body: some View {
        VStack(alignment: .leading) {
            if let info = patient_info {
                InfoRow(
                    label: "name",
                    value: "\(info.first_name) \(info.last_name)")
                InfoRow(
                    label: "birthday",
                    value: "\(date_formatter.formatter.string(from: info.birth_date))")
                InfoRow(label: "sex", value: "\(info.sex)")
                InfoRow(label: "race", value: "\(info.race)")
                InfoRow(label: "ethnicity", value: "\(info.ethnicity)")
            } else {
                Text("No demographic information available")
                    .foregroundStyle(.gray)
                    .italic()
            }
        }.padding()
    }
}

struct SessionInfo: View {
    let session: Session
    
    struct SessionDateFormatter {
        var formatter = DateFormatter()
        
        init() {
            self.formatter.dateStyle = .long
            self.formatter.timeStyle = .short
        }
    }
    let date_formatter = SessionDateFormatter()
    
    var body: some View {
//        if app_config.print_changes {let _ = Self._printChanges()}
        VStack {
            Text(date_formatter.formatter.string(from: session.created))
                .font(.title3)
                .padding(.bottom)
                .padding(.top)
                .frame(maxWidth: .infinity, alignment: .leading)
            InfoRow(label: "id", value: session.id)
        }
        .padding()
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 14))
        }
    }
}
//#Preview {
//    SessionDetail()
//}
