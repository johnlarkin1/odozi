import SwiftData
import SwiftUI

struct GuidedPromptFlowView: View {
    var entryDate: Date?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: GuidedPromptViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                ZStack {
                    Color.black.ignoresSafeArea()

                    VStack(spacing: 0) {
                        PromptProgressBar(
                            currentStep: vm.currentStepIndex,
                            totalSteps: vm.totalSteps
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        #if os(macOS)
                            promptCard(for: vm.currentStep, viewModel: vm)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .id(vm.currentStep)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                                .animation(.easeInOut(duration: 0.3), value: vm.currentStep)
                        #else
                            TabView(selection: Binding(
                                get: { vm.currentStep },
                                set: { vm.currentStep = $0 }
                            )) {
                                ForEach(PromptStep.allCases) { step in
                                    promptCard(for: step, viewModel: vm)
                                        .tag(step)
                                }
                            }
                            .tabViewStyle(.page(indexDisplayMode: .never))
                            .ignoresSafeArea(.keyboard)
                        #endif

                        PromptNavigationBar(
                            isFirstStep: vm.isFirstStep,
                            isLastStep: vm.isLastStep,
                            onBack: { vm.goToPrevious() },
                            onSkip: { vm.skip() },
                            onNext: { vm.goToNext() },
                            onSubmit: { vm.submit() }
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(12)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 12)
                }
                #if os(macOS)
                .sheet(isPresented: Binding(
                    get: { vm.showingCompletion },
                    set: { vm.showingCompletion = $0 }
                )) {
                    CompletionCard(
                        entryDate: vm.isPastEntry ? vm.targetDate : nil,
                        locationDisplay: vm.currentLocationDisplay == "No location captured" ? nil : vm.currentLocationDisplay,
                        unlockedAchievements: vm.newlyUnlockedAchievements
                    ) {
                        dismiss()
                    }
                    .frame(minWidth: 400, minHeight: 500)
                }
                #else
                .fullScreenCover(isPresented: Binding(
                            get: { vm.showingCompletion },
                            set: { vm.showingCompletion = $0 }
                        )) {
                            CompletionCard(
                                entryDate: vm.isPastEntry ? vm.targetDate : nil,
                                locationDisplay: vm.currentLocationDisplay == "No location captured" ? nil : vm.currentLocationDisplay,
                                unlockedAchievements: vm.newlyUnlockedAchievements
                            ) {
                                dismiss()
                            }
                        }
                #endif
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .onAppear {
            if viewModel == nil {
                if let date = entryDate {
                    viewModel = GuidedPromptViewModel(modelContext: modelContext, date: date)
                } else {
                    viewModel = GuidedPromptViewModel(modelContext: modelContext)
                }
            }
        }
    }

    @ViewBuilder
    private func promptCard(for step: PromptStep, viewModel: GuidedPromptViewModel) -> some View {
        switch step {
        case .mood:
            MoodPromptCard(feeling: Binding(
                get: { viewModel.responses.feeling },
                set: { viewModel.responses.feeling = $0 }
            ))
        case .feeling:
            FeelingPromptCard(
                word: Binding(
                    get: { viewModel.responses.singleWordFeeling },
                    set: { viewModel.responses.singleWordFeeling = $0 }
                ),
                colorHex: Binding(
                    get: { viewModel.responses.feelingColorHex },
                    set: { viewModel.responses.feelingColorHex = $0 }
                )
            )
        case .sleep:
            SleepPromptCard(sleepQuality: Binding(
                get: { viewModel.responses.sleepQuality },
                set: { viewModel.responses.sleepQuality = $0 }
            ))
        case .gratitude:
            GratitudePromptCard(text: Binding(
                get: { viewModel.responses.gratitude },
                set: { viewModel.responses.gratitude = $0 }
            ))
        case .win:
            WinPromptCard(text: Binding(
                get: { viewModel.responses.win },
                set: { viewModel.responses.win = $0 }
            ))
        case .tension:
            TensionPromptCard(text: Binding(
                get: { viewModel.responses.tension },
                set: { viewModel.responses.tension = $0 }
            ))
        case .journal:
            JournalPromptCard(text: Binding(
                get: { viewModel.responses.journalEntry },
                set: { viewModel.responses.journalEntry = $0 }
            ))
        case .photo:
            PhotoPromptCard(photoData: Binding(
                get: { viewModel.responses.attachedPhotoData },
                set: { viewModel.responses.attachedPhotoData = $0 }
            ))
        case .drinks:
            DrinksPromptCard(drinks: Binding(
                get: { viewModel.responses.drinks },
                set: { viewModel.responses.drinks = $0 }
            ))
        case .location:
            LocationCard(
                currentLocationDisplay: viewModel.currentLocationDisplay,
                locationCapturedAt: viewModel.locationCapturedAt,
                isUpdating: viewModel.isUpdatingLocation,
                onUpdateLocation: {
                    Task { await viewModel.updateLocationFromGPS() }
                }
            )
            .onAppear { viewModel.loadCurrentLocation() }
        }
    }
}
