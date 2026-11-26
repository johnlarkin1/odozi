import SwiftData
import SwiftUI

struct GuidedPromptFlowView: View {
    var entryDate: Date?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: GuidedPromptViewModel?
    @State private var navigatingForward = true

    /// Shared focus state lives in the parent so keyboard survives
    /// card-swap transitions. Each text card binds against this via
    /// `.focused($focusedField, equals: <its step>)`.
    @FocusState private var focusedField: PromptStep?

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

                        promptCard(for: vm.currentStep, viewModel: vm)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .id(vm.currentStep)
                            .transition(.asymmetric(
                                insertion: .move(edge: navigatingForward ? .trailing : .leading),
                                removal: .move(edge: navigatingForward ? .leading : .trailing)
                            ))
                            .animation(.easeInOut(duration: 0.3), value: vm.currentStep)
                        #if !os(macOS)
                            .gesture(
                                DragGesture(minimumDistance: 50)
                                    .onEnded { value in
                                        guard abs(value.translation.width) > 2 * abs(value.translation.height) else { return }
                                        if value.translation.width < -50, !vm.isLastStep {
                                            vm.goToNext()
                                        } else if value.translation.width > 50, !vm.isFirstStep {
                                            vm.goToPrevious()
                                        }
                                    }
                            )
                        #endif

                        #if os(macOS)
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
                        #endif
                    }
                }
                .onChange(of: vm.currentStep) { oldStep, newStep in
                    navigatingForward = newStep.rawValue > oldStep.rawValue
                    // After the new card is mounted, auto-focus its text field
                    // (if any). Non-text steps clear focus, dismissing the
                    // keyboard cleanly. Deferring by one runloop tick ensures
                    // SwiftUI has installed the new TextEditor/TextField before
                    // we try to claim focus on it.
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                        focusedField = newStep.hasTextInput ? newStep : nil
                    }
                }
                #if !os(macOS)
                .safeAreaInset(edge: .bottom, spacing: 0) {
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
                    .background(Color.black)
                }
                #endif
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
                        unlockedAchievements: vm.newlyUnlockedAchievements,
                        isGeneratingInsight: vm.isGeneratingInsight,
                        insight: vm.insight
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
                                unlockedAchievements: vm.newlyUnlockedAchievements,
                                isGeneratingInsight: vm.isGeneratingInsight,
                                insight: vm.insight
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
                ),
                focusedField: $focusedField
            )
        case .sleep:
            SleepPromptCard(sleepQuality: Binding(
                get: { viewModel.responses.sleepQuality },
                set: { viewModel.responses.sleepQuality = $0 }
            ))
        case .gratitude:
            GratitudePromptCard(
                text: Binding(
                    get: { viewModel.responses.gratitude },
                    set: { viewModel.responses.gratitude = $0 }
                ),
                focusedField: $focusedField
            )
        case .win:
            WinPromptCard(
                text: Binding(
                    get: { viewModel.responses.win },
                    set: { viewModel.responses.win = $0 }
                ),
                focusedField: $focusedField
            )
        case .tension:
            TensionPromptCard(
                text: Binding(
                    get: { viewModel.responses.tension },
                    set: { viewModel.responses.tension = $0 }
                ),
                focusedField: $focusedField
            )
        case .journal:
            JournalPromptCard(
                text: Binding(
                    get: { viewModel.responses.journalEntry },
                    set: { viewModel.responses.journalEntry = $0 }
                ),
                focusedField: $focusedField
            )
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
                errorMessage: viewModel.locationErrorMessage,
                showOpenSettings: viewModel.locationPermissionDenied,
                onUpdateLocation: {
                    Task { await viewModel.updateLocationFromGPS() }
                }
            )
            .onAppear {
                viewModel.loadCurrentLocation()
                Task { await viewModel.autoCaptureLocationIfNeeded() }
            }
        }
    }
}
