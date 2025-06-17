//
//  DataWriter.swift
//  Neurocular
//
//  Created by Max Taggart on 6/8/25.
//

import Foundation



class SessionSink {
    private var patient_info: PatientInfo?
    private var storage_manager: StorageManager
    private var rows: [Row] = []
    
    
    init(storage_manager: StorageManager, patient_info: PatientInfo?) {
        self.patient_info = patient_info
        self.storage_manager = storage_manager
    }
    
    func add_row(_ row: Row) {
        rows.append(row)
    }
    
    func done() {
        let session = Session(
            id: NSUUID().uuidString.lowercased(),
            demographics: self.patient_info,
            rows: self.rows,
            created: Date(),
            notes: ""
        )
        storage_manager.add_session(session)
    }
}
