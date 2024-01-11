//
//  DailyPromptsView.swift
//  Odyssey
//
//  Created by John Larkin on 1/6/24.
//

import SwiftUI
import CoreLocation

struct DailyPromptsView: View {
    @ObservedObject var viewModel = DailyEntryViewModel()
    @State private var feeling: Double = 5
    @State private var sleepQuality: Double = 5
    @State private var singleWordFeeling: String = ""
    @State private var feelingColor: Color = .white
    @State private var journalEntry: String = ""
    @State private var drinks: Int = 0
    @State private var win: String = ""
    @State private var tension: String = ""
    @State private var gratitude: String = ""
    
    var body: some View {
        NavigationView {
            if viewModel.hasSubmittedData {
                Text(viewModel.submissionMessage)
            } else {
                
                Form {
                    Section(header: Text("How are you feeling? (1-10)")) {
                        Slider(value: $feeling, in: 1...10, step: 1)
                        Text("Feeling: \(Int(feeling))")
                    }
                    
                    Section(header: Text("How well did you sleep last night? (1-10)")) {
                        Slider(value: $sleepQuality, in: 1...10, step: 1)
                        Text("Sleep Quality: \(Int(sleepQuality))")
                    }
                    
                    Section(header: Text("How many drinks did you have last night?")) {
                        Stepper(value: $drinks, in: 0...20) {
                            Text("\(drinks) drinks")
                        }
                    }
                    
                    Section(header: Text("Describe how you're feeling with a single word")) {
                        TextField("Enter a word", text: $singleWordFeeling)
                    }
                    
                    Section(header: Text("Describe with a color how you're feeling")) {
                        ColorPicker("Pick a color", selection: $feelingColor)
                    }
                    
                    Section(header: Text("Record 1 win from today")) {
                        TextField("Win", text: $win)
                    }
                    
                    Section(header: Text("Record 1 point of tension, stress, or anxiety")) {
                        TextField("Tension", text: $tension)
                    }
                    
                    Section(header: Text("Record 1 point of gratitude")) {
                        TextField("Gratitude", text: $gratitude)
                    }
                    
                    Section(header: Text("Write a journal entry")) {
                        TextEditor(text: $journalEntry)
                            .frame(minHeight: 150) // Adjust the height as needed
                    }
                    
                    Section {
                        Button(action: submitData) {
                            Text("Submit")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .navigationBarTitle("Daily Prompts")
            }
        }
        .onAppear {
            viewModel.checkForTodayEntry()
        }
    }
    
    func submitData() {
        // Update this to call a method on the viewModel
        viewModel.submitData(feeling: feeling,
                             sleepQuality: sleepQuality,
                             singleWordFeeling: singleWordFeeling,
                             feelingColor: feelingColor,
                             journalEntry: journalEntry,
                             drinks: drinks,
                             win: win,
                             tension: tension,
                             gratitude: gratitude)
    }
}

struct DailyPromptsView_Previews: PreviewProvider {
    static var previews: some View {
        DailyPromptsView()
    }
}
