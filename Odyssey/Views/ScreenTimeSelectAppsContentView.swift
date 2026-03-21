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
                model.activitySelection.categoryTokens.isEmpty
            {
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

#Preview {
    ScreenTimeSelectAppsContentView(model: ScreenTimeSelectAppsModel())
}
