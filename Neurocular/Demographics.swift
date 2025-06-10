//
//  Demographics.swift
//  Neurocular
//
//  Created by Max Taggart on 5/5/25.
//

import SwiftUI

enum Race: String, Codable {
    case Blank
    case White
    case Black
    case AmericanIndian
    case AsianIndian
    case Chinese
    case Filipino
    case Japanese
    case Korean
    case Vietnamese
    case OtherAsian
    case NativeHawaiian
    case Samoan
    case OtherPacificIslander
    case Other
    case ChooseNotToAnswer
}

enum Ethnicity: String, Codable {
    case Blank
    case NotHispanic
    case PuertoRican
    case Mexican
    case Cuban
    case OtherHispanic
    case ChooseNotToAnswer
}

enum Sex: String, Codable {
    case Blank
    case Female
    case Male
}

struct PatientInfo: Codable, Hashable {
    var first_name: String;
    var last_name: String;
    var birth_date: Date;
    var sex: Sex;
    var race: Race;
    var ethnicity: Ethnicity;
}

struct TestDestination: Hashable {}

struct Demographics: View {
    @State private var first_name: String = ""
    @State private var last_name: String = ""
    @State private var birth_date: Date = Date()
    @State private var sex: Sex = Sex.Blank
    @State private var race: Race = Race.Blank
    @State private var ethnicity: Ethnicity = Ethnicity.Blank
    @Binding var navigation_path: NavigationPath
    let storage_manager: StorageManager
    
    var body: some View {
        Form {
            Section {
                TextField("First Name", text: $first_name)
                TextField("Last Name", text: $last_name)
                DatePicker(
                    "Birth Date",
                    selection: $birth_date,
                    displayedComponents: [.date]
                )
            }
            Section {
                Picker("Sex", selection: $sex) {
                    Text("").tag(Sex.Blank)
                    Text("Female").tag(Sex.Female)
                    Text("Male").tag(Sex.Male)
                }
                Picker("Race", selection: $race) {
                    Text("").tag(Race.Blank)
                    Text("White").tag(Race.White)
                    Text("Black").tag(Race.Black)
                    Text("American Indian").tag(Race.AmericanIndian)
                    Text("Asian Indian").tag(Race.AsianIndian)
                    Text("Chinese").tag(Race.Chinese)
                    Text("Filipino").tag(Race.Filipino)
                    Text("Japanese").tag(Race.Japanese)
                    Text("Korean").tag(Race.Korean)
                    Text("Vietnamese").tag(Race.Vietnamese)
                    Text("Other Asian").tag(Race.OtherAsian)
                    Text("Native Hawaiian").tag(Race.NativeHawaiian)
                    Text("Samoan").tag(Race.Samoan)
                    Text("Other Pacific Islander").tag(Race.OtherPacificIslander)
                    Text("Other").tag(Race.Other)
                    Text("I Choose Not To Answer").tag(Race.ChooseNotToAnswer)
                }
                Picker("Ethnicity", selection: $ethnicity) {
                    Text("").tag(Ethnicity.Blank)
                    Text("Not of Hispanic, Latino, or Spanish Origin").tag(Ethnicity.NotHispanic)
                    Text("Puerto Rican").tag(Ethnicity.PuertoRican)
                    Text("Mexican").tag(Ethnicity.Mexican)
                    Text("Cuban").tag(Ethnicity.Cuban)
                    Text("Other Hispanic, Latino, or Spanish Origin").tag(Ethnicity.OtherHispanic)
                    Text("I Choose Not To Answer").tag(Ethnicity.ChooseNotToAnswer)
                }
            }
            
            NavigationLink("Begin Test", value: TestDestination())
        }
        .navigationTitle("Patient Information")
        .navigationDestination(for: TestDestination.self) { _ in
            Test(
                navigation_path: $navigation_path,
                patient_info: PatientInfo(
                    first_name: first_name,
                    last_name: last_name,
                    birth_date: birth_date,
                    sex: sex,
                    race: race,
                    ethnicity: ethnicity
                ),
                storage_manager: storage_manager
            )
        }
    }
}

#Preview {
    Demographics(navigation_path: .constant(NavigationPath()), storage_manager: StorageManager())
}
