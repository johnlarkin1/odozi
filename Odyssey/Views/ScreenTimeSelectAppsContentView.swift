//
//  ScreenTimeSelectAppsContentView.swift
//  Odyssey
//
//  Created by John Larkin on 1/8/24.
//

import SwiftUI

struct ScreenTimeSelectAppsContentView: View {
    @State private var pickerIsPresented = false
    @ObservedObject var model: ScreenTimeSelectAppsModel

    var body: some View {
        Button {
            pickerIsPresented = true
        } label: {
            Text("Select Apps")
        }
        .familyActivityPicker(
            isPresented: $pickerIsPresented,
            selection: $model.activitySelection
        )
    }
}

struct ScreenTimeSelectAppsContentView_Previews: PreviewProvider {
    static var previews: some View {
        ScreenTimeSelectAppsContentView(model: ScreenTimeSelectAppsModel())
    }
}
