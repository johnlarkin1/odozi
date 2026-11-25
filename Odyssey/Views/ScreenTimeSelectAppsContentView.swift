//
//  ScreenTimeSelectAppsContentView.swift
//  Odyssey
//
//  Created by John Larkin on 1/8/24.
//

import FamilyControls
import SwiftUI

struct ScreenTimeSelectAppsContentView: View {
    @State private var pickerIsPresented = false
    @Bindable var model: ScreenTimeSelectAppsModel

    var body: some View {
        List {
            Section {
                Button {
                    pickerIsPresented = true
                } label: {
                    Label("Choose Apps", systemImage: "apps.iphone")
                }
            }

            if !model.activitySelection.applicationTokens.isEmpty {
                Section("Selected Apps (\(model.activitySelection.applicationTokens.count))") {
                    ForEach(Array(model.activitySelection.applicationTokens), id: \.self) { token in
                        Label(token)
                    }
                }
            }

            if !model.activitySelection.categoryTokens.isEmpty {
                Section("Selected Categories (\(model.activitySelection.categoryTokens.count))") {
                    ForEach(Array(model.activitySelection.categoryTokens), id: \.self) { token in
                        Label(token)
                    }
                }
            }

            if model.activitySelection.applicationTokens.isEmpty &&
                model.activitySelection.categoryTokens.isEmpty {
                Section {
                    Text("No apps selected")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Select Apps")
        .familyActivityPicker(
            isPresented: $pickerIsPresented,
            selection: $model.activitySelection
        )
        .onChange(of: model.activitySelection) {
            model.saveSelection()
        }
    }
}

/// Shown from the Today Screen Time tile when nothing is being captured yet. Walks the
/// user through the two things Screen Time capture needs: Family Controls permission,
/// then a set of apps or categories to measure (threshold events can't watch "everything"
/// without at least one token).
struct ScreenTimeSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model = ScreenTimeSelectAppsModel()
    @State private var state = ScreenTimeMonitoringManager.setupState
    @State private var pickerIsPresented = false
    @State private var authError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("iOS doesn't let apps read your total Screen Time directly. Odozi measures time spent in the apps and categories you choose. Select every category to track your whole day.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section {
                    switch state {
                    case .notAuthorized:
                        Button {
                            requestAuthorization()
                        } label: {
                            Label("Allow Screen Time Access", systemImage: "hourglass")
                        }
                        if let authError {
                            Text(authError)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    case .noSelection, .ready:
                        Button {
                            pickerIsPresented = true
                        } label: {
                            Label("Choose Apps & Categories", systemImage: "apps.iphone")
                        }
                    }
                }

                if state == .ready {
                    Section {
                        Label("Tracking is on. Your first number shows up after a minute of use.",
                              systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color.successGreen)
                    }
                }
            }
            .navigationTitle("Track Screen Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .familyActivityPicker(
                isPresented: $pickerIsPresented,
                selection: $model.activitySelection
            )
            .onChange(of: model.activitySelection) {
                model.saveSelection()
                state = ScreenTimeMonitoringManager.setupState
            }
        }
    }

    private func requestAuthorization() {
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                authError = nil
            } catch {
                authError = "Screen Time access wasn't granted. You can turn it on in Settings › Screen Time."
            }
            state = ScreenTimeMonitoringManager.setupState
            if state == .noSelection {
                pickerIsPresented = true
            }
        }
    }
}

#Preview {
    ScreenTimeSelectAppsContentView(model: ScreenTimeSelectAppsModel())
}
