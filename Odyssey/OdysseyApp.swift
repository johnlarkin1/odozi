//
//  OdysseyApp.swift
//  Odyssey
//
//  Created by John Larkin on 1/6/24.
//

import SwiftUI

@main
struct OdysseyApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
