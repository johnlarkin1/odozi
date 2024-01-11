//
//  ScreenTimeSelectAppsModel.swift
//  Odyssey
//
//  Created by John Larkin on 1/8/24.
//

import Foundation
import FamilyControls

class ScreenTimeSelectAppsModel: ObservableObject {
    @Published var activitySelection = FamilyActivitySelection()

    init() { }
}
