//
//  ContentView.swift
//  Odyssey
//
//  Created by John Larkin on 1/6/24.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @State private var hasSubmittedData = false // Track if the daily entry has been submitted
    @State private var showingHomeView = true // Initially, we want to show the HomeView

    var body: some View {
        ZStack {
            // The main TabView for daily input and analysis, which will be shown after HomeView is dismissed
            TabView {
                DailyPromptsView()
                    .tabItem {
                        Image(systemName: "pencil.circle")
                        Text("Daily Input")
                    }
                    .disabled(hasSubmittedData) // Disable this tab if data has been submitted today

                AnalysisView()
                    .tabItem {
                        Image(systemName: "chart.xyaxis.line")
                        Text("Year Analysis")
                    }
                
                ExportView()
                    .tabItem {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Data")
                    }
            }
            .opacity(showingHomeView ? 0 : 1) // Hide the TabView when showingHomeView is true

            // Conditionally show HomeView as a full-screen modal presentation
            if showingHomeView {
                HomeView(showingHomeView: $showingHomeView)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
