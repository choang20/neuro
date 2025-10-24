//
//  SessionDetail.swift
//  Neurocular
//
//  Created by Max Taggart on 6/8/25.
//

import SwiftUI

struct SessionDetail: View {
    @Binding var storage_manager: StorageManager
    @Binding var navigation_path: NavigationPath
    @State private var showing_delete_alert = false
    @State private var exam_metadata: ExamMetadata
    @State private var actively_deleting: Bool = false
    private var interpolated_frames: [InterpolatedFrame]
    
    
    init(
        exam_metadata: ExamMetadata,
        navigation_path: Binding<NavigationPath>,
        storage_manager: Binding<StorageManager>
    ) {
        self._storage_manager = storage_manager
        self._navigation_path = navigation_path
        self.exam_metadata = exam_metadata
        let exam_frames = storage_manager.wrappedValue.get_exam_frames_by_id(exam_metadata.id)!
        self.interpolated_frames = interpolate_frames(exam_frames)
    }
    
    private func delete_exam() {
        actively_deleting = true
        storage_manager.delete_exam(id: exam_metadata.id)
        navigation_path.removeLast()
    }
    
    struct BirthdayDateFormatter {
        var formatter = DateFormatter()
        
        init() {
            self.formatter.dateStyle = .short
            self.formatter.timeStyle = .none
        }
    }
    let date_formatter = BirthdayDateFormatter()
    
    var body: some View {
        if actively_deleting {
            ProgressView()
        } else {
            ScrollView{
                VStack {
                    VStack {
                        Text(date_formatter.formatter.string(from: exam_metadata.created))
                            .font(.title3)
                            .padding(.bottom)
                            .padding(.top)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        InfoRow(label: "id", value: exam_metadata.id)
                    }
                    .padding()
                    
                    PatientInfoView(patient_info: exam_metadata.demographics)
                    GazeAnglePlot(
                        interpolated_frames: self.interpolated_frames
                    ).frame(height: 300)
                    
                    Notes(
                        storage_manager: storage_manager,
                        exam_metadata: $exam_metadata
                    )
                    
                    Button(action: {
                        showing_delete_alert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Exam")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                }
            }
            .alert("Delete Exam", isPresented: $showing_delete_alert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    delete_exam()
                }
            } message: {
                Text("Are you sure you want to delete this exam? This action cannot be undone.")
            }
        }
    }
}

struct PatientInfoView: View {
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

#Preview {
    let test_data_dir = URL(fileURLWithPath: "/Users/max.taggart/Developer/Ehrenkranz/Neurocular/test_data/exams")
    let storage_manager = StorageManager(with_base_dir: test_data_dir);
    let exam_metadata = storage_manager.get_exam_metadata_by_id("c4bee50c-ff9f-4c4e-8034-15bdcd3253dc")!
    let navigation_path = NavigationPath();
    SessionDetail(
        exam_metadata: exam_metadata,
        navigation_path: .constant(navigation_path),
        storage_manager: .constant(storage_manager)
    )
}
