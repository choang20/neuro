//
//  Notes.swift
//  Neurocular
//
//  Created by Max Taggart on 8/20/25.
//

import SwiftUI


struct Notes: View {
    let storage_manager: StorageManager
    @Binding var exam_metadata: ExamMetadata
    @State private var editing = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack{
                Text("Notes")
                    .font(.headline)
                    .padding(.horizontal)
                Spacer()
                Button {
                    editing = true
                } label: {
                    HStack {
                        Text("Edit")
                        Image(systemName: "pencil")
                            .foregroundStyle(Color.blue)
                            .padding(.trailing)
                    }
                }
                
            }
            Text(exam_metadata.notes)
                .padding()
        }
        .sheet(isPresented: $editing) {
            NoteEdit(
                storage_manager: storage_manager,
                exam_metadata: $exam_metadata,
                editing_active: $editing
            )
            .presentationDetents([.medium])
        }
    }
}

struct NoteEdit: View {
    let storage_manager: StorageManager
    @Binding var exam_metadata: ExamMetadata
    @Binding var editing_active: Bool
    @State var current_note: String
    @FocusState private var is_text_editor_focused: Bool
    
    init(
        storage_manager: StorageManager,
        exam_metadata: Binding<ExamMetadata>,
        editing_active: Binding<Bool>
    ) {
        self.storage_manager = storage_manager
        self._exam_metadata = exam_metadata
        self._editing_active = editing_active
        self._current_note = State(initialValue: exam_metadata.wrappedValue.notes)
    }
    
    var body: some View {
        VStack {
            HStack {
                Button {
                    editing_active = false
                } label: {
                    Text("Cancel")
                }
                
                Spacer()
                
                Text("Edit Note")
                
                Spacer()
                
                Button {
                    print("current note: \(current_note)")
                    self.exam_metadata.notes = current_note
                    print("notes from metadata: \(self.exam_metadata.notes)")
                    storage_manager.update_exam(metadata: exam_metadata)
                    editing_active = false
                } label: {
                    Text("Save")
                }
            }
            .padding()
        }
        TextEditor(text: $current_note)
            .focused($is_text_editor_focused)
            .frame(minHeight: 100)
            .padding(4)
//            .overlay(
//                RoundedRectangle(cornerRadius: 8)
//                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
//            )
            .padding(.horizontal)
            .onAppear {
                is_text_editor_focused = true
            }
    }
}

#Preview {
    let storage_manager = StorageManager(
        with_base_dir: URL(
            fileURLWithPath: "/Users/max.taggart/Developer/Ehrenkranz/Neurocular/test_data/exams"
        )
    );
    var exam_metadata = storage_manager.get_exam_metadata_by_id("c4bee50c-ff9f-4c4e-8034-15bdcd3253dc")!
    
    Notes(
        storage_manager: storage_manager,
        exam_metadata: .constant(exam_metadata)
    )
}
