//
//  OculoMetrixHome.swift
//  Neurocular
//
//  Created by Assistant on 10/28/25.
//

import SwiftUI

struct OculoMetrixHome: View {
    @State private var navigation_path = NavigationPath()
    @State private var storage_manager = StorageManager()

    var body: some View {
        NavigationStack(path: $navigation_path) {
            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Oculometrix")
                            .font(.title2)
                            .padding(.top, 8)

                        // Responsive grid: adapts to width for portrait/landscape and devices
                        let columns = [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: 16)]
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                            TestCard(title: "smooth pursuit") {
                                navigation_path.append("smooth")
                            }
                            TestCard(title: "saccades") {
                                navigation_path.append("saccades")
                            }
                            TestCard(title: "nystagmus") {
                                navigation_path.append("nystagmus")
                            }
                        }

                        HStack {
                            Spacer()
                            Text("© Oculometrix")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationDestination(for: String.self) { dest in
                switch dest {
                case "smooth":
                    SmoothPursuitScreen(
                        navigation_path: $navigation_path,
                        storage_manager: $storage_manager
                    )
                case "saccades":
                    SaccadesScreen(
                        navigation_path: $navigation_path,
                        storage_manager: $storage_manager
                    )
                case "nystagmus":
                    NystagmusScreen(
                        navigation_path: $navigation_path,
                        storage_manager: $storage_manager
                    )
                default:
                    EmptyView()
                }
            }
            .navigationDestination(for: ResultRoute.self) { route in
                switch route.kind {
                case "smooth":
                    SmoothPursuitResultView(
                        examId: route.examId,
                        navigation_path: $navigation_path,
                        storage_manager: $storage_manager
                    )
                case "saccades":
                    SaccadeResultView(
                        examId: route.examId,
                        navigation_path: $navigation_path,
                        storage_manager: $storage_manager
                    )
                case "nystagmus":
                    NystagmusResultView(
                        examId: route.examId,
                        navigation_path: $navigation_path,
                        storage_manager: $storage_manager
                    )
                default:
                    EmptyView()
                }
            }
        }
    }
}

struct TestCard: View {
    let title: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)
            Button("start") { action() }
                .padding(12)
                .foregroundColor(.white)
                .background(Color.green)
                .clipShape(Circle())
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.5))
        )
    }
}


