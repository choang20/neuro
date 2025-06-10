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
    
    var body: some View {
        ScrollView{
            VStack {
                SessionInfo(session: session)
                DemographicInfo(patient_info: session.demographics)
                GazeAnglePlot(
                    transforms: session.rows.map {row in row.transforms}
                ).frame(height: 300)
            }
        }
    }
}

struct DemographicInfo: View {
    let patient_info: PatientInfo
    
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
            InfoRow(
                label: "name",
                value: "\(patient_info.first_name) \(patient_info.last_name)")
            InfoRow(
                label: "birthday",
                value: "\(date_formatter.formatter.string(from: patient_info.birth_date))")
            InfoRow(label: "sex", value: "\(patient_info.sex)")
            InfoRow(label: "race", value: "\(patient_info.race)")
            InfoRow(label: "ethnicity", value: "\(patient_info.ethnicity)")
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
