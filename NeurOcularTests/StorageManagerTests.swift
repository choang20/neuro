//
//  NeurOcularTests.swift
//  NeurOcularTests
//
//  Created by Max Taggart on 6/30/25.
//

import Testing
import Foundation
@testable import NeurOcular

struct StorageManagerTests {
    
    @Test("Exam creation")
    func test_add_exam() throws {
        let storage_manager = StorageManager(with_base_dir: URL(string: "testing/", relativeTo: URL.documentsDirectory)!)
        
        // Create ExamMetadata with demographics
        let examMetadata = ExamMetadata(
            id: "test-id-123",
            demographics: nil,
            created: Date(timeIntervalSince1970: 1640995200), // 2022-01-01
            notes: "Test exam without demographics"
        )
        storage_manager.add_exam(
            metadata: examMetadata,
            frames: ExamFrames(
                exam_id: examMetadata.id,
                spatial_transforms: [],
                stimulus_positions: [],
                stimulus_speeds: []
            )
        )
    }
    
    @Test("ExamMetadata serialization with demographics")
    func testExamMetadataSerializationWithDemographics() throws {
        // Create a PatientInfo object
        let patientInfo = PatientInfo(
            first_name: "John",
            last_name: "Doe",
            birth_date: Date(timeIntervalSince1970: 946684800), // 2000-01-01
            sex: .Male,
            race: .White,
            ethnicity: .NotHispanic
        )
        
        // Create ExamMetadata with demographics
        let examMetadata = ExamMetadata(
            id: "test-id-123",
            demographics: patientInfo,
            created: Date(timeIntervalSince1970: 1640995200), // 2022-01-01
            notes: "Test exam with demographics"
        )
        
        // Create a temporary URL for testing
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_metadata_with_demographics.json")
        
        // Write to file using the struct's method
        examMetadata.write(to: tempURL)
        
        // Verify file was created
        #expect(FileManager.default.fileExists(atPath: tempURL.path))
        
        // Read from file using the struct's method
        let deserializedMetadata = ExamMetadata.from(url: tempURL)
        
        // Verify all fields match
        #expect(deserializedMetadata.id == examMetadata.id)
        #expect(deserializedMetadata.created == examMetadata.created)
        #expect(deserializedMetadata.notes == examMetadata.notes)
        
        // Verify demographics are preserved
        #expect(deserializedMetadata.demographics != nil)
        let deserializedPatientInfo = deserializedMetadata.demographics!
        #expect(deserializedPatientInfo.first_name == patientInfo.first_name)
        #expect(deserializedPatientInfo.last_name == patientInfo.last_name)
        #expect(deserializedPatientInfo.birth_date == patientInfo.birth_date)
        #expect(deserializedPatientInfo.sex == patientInfo.sex)
        #expect(deserializedPatientInfo.race == patientInfo.race)
        #expect(deserializedPatientInfo.ethnicity == patientInfo.ethnicity)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    @Test("ExamMetadata serialization without demographics")
    func testExamMetadataSerializationWithoutDemographics() throws {
        // Create ExamMetadata without demographics
        let examMetadata = ExamMetadata(
            id: "test-id-456",
            demographics: nil,
            created: Date(timeIntervalSince1970: 1640995200), // 2022-01-01
            notes: "Test exam without demographics"
        )
        
        // Create a temporary URL for testing
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_metadata_without_demographics.json")
        
        // Write to file using the struct's method
        examMetadata.write(to: tempURL)
        
        // Verify file was created
        #expect(FileManager.default.fileExists(atPath: tempURL.path))
        
        // Read from file using the struct's method
        let deserializedMetadata = ExamMetadata.from(url: tempURL)
        
        // Verify all fields match
        #expect(deserializedMetadata.id == examMetadata.id)
        #expect(deserializedMetadata.created == examMetadata.created)
        #expect(deserializedMetadata.notes == examMetadata.notes)
        
        // Verify demographics is still nil
        #expect(deserializedMetadata.demographics == nil)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    @Test("ExamMetadata round-trip serialization with demographics")
    func testExamMetadataRoundTripWithDemographics() throws {
        // Create a PatientInfo object with various enum values
        let patientInfo = PatientInfo(
            first_name: "Jane",
            last_name: "Smith",
            birth_date: Date(timeIntervalSince1970: 978307200), // 2001-01-01
            sex: .Female,
            race: .AsianIndian,
            ethnicity: .PuertoRican
        )
        
        // Create ExamMetadata with demographics
        let originalMetadata = ExamMetadata(
            id: "round-trip-test-123",
            demographics: patientInfo,
            created: Date(timeIntervalSince1970: 1640995200), // 2022-01-01
            notes: "Round trip test with demographics"
        )
        
        // Create temporary URLs for testing
        let tempURL1 = FileManager.default.temporaryDirectory.appendingPathComponent("round_trip_test1.json")
        let tempURL2 = FileManager.default.temporaryDirectory.appendingPathComponent("round_trip_test2.json")
        
        // First round trip: write -> read
        originalMetadata.write(to: tempURL1)
        let deserialized1 = ExamMetadata.from(url: tempURL1)
        
        // Second round trip: write -> read
        deserialized1.write(to: tempURL2)
        let deserialized2 = ExamMetadata.from(url: tempURL2)
        
        // Verify all data is preserved through multiple round trips
        #expect(deserialized2.id == originalMetadata.id)
        #expect(deserialized2.created == originalMetadata.created)
        #expect(deserialized2.notes == originalMetadata.notes)
        
        #expect(deserialized2.demographics != nil)
        let finalPatientInfo = deserialized2.demographics!
        #expect(finalPatientInfo.first_name == patientInfo.first_name)
        #expect(finalPatientInfo.last_name == patientInfo.last_name)
        #expect(finalPatientInfo.birth_date == patientInfo.birth_date)
        #expect(finalPatientInfo.sex == patientInfo.sex)
        #expect(finalPatientInfo.race == patientInfo.race)
        #expect(finalPatientInfo.ethnicity == patientInfo.ethnicity)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL1)
        try? FileManager.default.removeItem(at: tempURL2)
    }
    
    @Test("ExamMetadata round-trip serialization without demographics")
    func testExamMetadataRoundTripWithoutDemographics() throws {
        // Create ExamMetadata without demographics
        let originalMetadata = ExamMetadata(
            id: "round-trip-test-456",
            demographics: nil,
            created: Date(timeIntervalSince1970: 1640995200), // 2022-01-01
            notes: "Round trip test without demographics"
        )
        
        // Create temporary URLs for testing
        let tempURL1 = FileManager.default.temporaryDirectory.appendingPathComponent("round_trip_test3.json")
        let tempURL2 = FileManager.default.temporaryDirectory.appendingPathComponent("round_trip_test4.json")
        
        // First round trip: write -> read
        originalMetadata.write(to: tempURL1)
        let deserialized1 = ExamMetadata.from(url: tempURL1)
        
        // Second round trip: write -> read
        deserialized1.write(to: tempURL2)
        let deserialized2 = ExamMetadata.from(url: tempURL2)
        
        // Verify all data is preserved through multiple round trips
        #expect(deserialized2.id == originalMetadata.id)
        #expect(deserialized2.created == originalMetadata.created)
        #expect(deserialized2.notes == originalMetadata.notes)
        
        // Verify demographics remains nil through all round trips
        #expect(deserialized2.demographics == nil)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL1)
        try? FileManager.default.removeItem(at: tempURL2)
    }
    
    @Test("ExamMetadata with edge case demographics values")
    func testExamMetadataWithEdgeCaseDemographics() throws {
        // Create a PatientInfo object with edge case values
        let patientInfo = PatientInfo(
            first_name: "", // Empty string
            last_name: "O'Connor", // Name with apostrophe
            birth_date: Date(timeIntervalSince1970: 0), // Unix epoch
            sex: .Blank,
            race: .ChooseNotToAnswer,
            ethnicity: .ChooseNotToAnswer
        )
        
        // Create ExamMetadata with edge case demographics
        let examMetadata = ExamMetadata(
            id: "edge-case-test",
            demographics: patientInfo,
            created: Date(timeIntervalSince1970: 1640995200),
            notes: "Test with edge case values"
        )
        
        // Create a temporary URL for testing
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("edge_case_test.json")
        
        // Write and read using the struct's methods
        examMetadata.write(to: tempURL)
        let deserializedMetadata = ExamMetadata.from(url: tempURL)
        
        // Verify edge case values are preserved
        #expect(deserializedMetadata.demographics != nil)
        let deserializedPatientInfo = deserializedMetadata.demographics!
        #expect(deserializedPatientInfo.first_name == patientInfo.first_name)
        #expect(deserializedPatientInfo.last_name == patientInfo.last_name)
        #expect(deserializedPatientInfo.birth_date == patientInfo.birth_date)
        #expect(deserializedPatientInfo.sex == patientInfo.sex)
        #expect(deserializedPatientInfo.race == patientInfo.race)
        #expect(deserializedPatientInfo.ethnicity == patientInfo.ethnicity)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    @Test("ExamMetadata static factory methods")
    func testExamMetadataFactoryMethods() throws {
        // Test new() method (without demographics)
        let metadataWithoutDemographics = ExamMetadata.new()
        #expect(metadataWithoutDemographics.id != "")
        #expect(metadataWithoutDemographics.demographics == nil)
        #expect(metadataWithoutDemographics.notes == "")
        
        // Test new(withDemographics:) method
        let patientInfo = PatientInfo(
            first_name: "Test",
            last_name: "User",
            birth_date: Date(),
            sex: .Male,
            race: .White,
            ethnicity: .NotHispanic
        )
        
        let metadataWithDemographics = ExamMetadata.new(withDemographics: patientInfo)
        #expect(metadataWithDemographics.id != "")
        #expect(metadataWithDemographics.demographics != nil)
        #expect(metadataWithDemographics.demographics?.first_name == patientInfo.first_name)
        #expect(metadataWithDemographics.demographics?.last_name == patientInfo.last_name)
        #expect(metadataWithDemographics.notes == "")
        
        // Verify both can be serialized and deserialized using the struct's methods
        let tempURL1 = FileManager.default.temporaryDirectory.appendingPathComponent("factory_test1.json")
        let tempURL2 = FileManager.default.temporaryDirectory.appendingPathComponent("factory_test2.json")
        
        // Test without demographics
        metadataWithoutDemographics.write(to: tempURL1)
        let deserialized1 = ExamMetadata.from(url: tempURL1)
        #expect(deserialized1.demographics == nil)
        
        // Test with demographics
        metadataWithDemographics.write(to: tempURL2)
        let deserialized2 = ExamMetadata.from(url: tempURL2)
        #expect(deserialized2.demographics != nil)
        #expect(deserialized2.demographics?.first_name == patientInfo.first_name)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL1)
        try? FileManager.default.removeItem(at: tempURL2)
    }
}
