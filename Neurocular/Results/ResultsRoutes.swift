//
//  ResultsRoutes.swift
//  Neurocular
//

import Foundation

struct ResultRoute: Hashable {
    let examId: ExamId
    let kind: String  // "smooth" | "saccades"
}


