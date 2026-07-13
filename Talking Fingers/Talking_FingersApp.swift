//
//  Talking_FingersApp.swift
//  Talking Fingers
//
//  Created by Nikola Cao on 1/24/26.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct Talking_FingersApp: App {
    @Environment(\.scenePhase) private var scenePhase
        
    @State private var dataVM = SwiftDataVM()
    @State private var authVM: AuthenticationViewModel
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FlashcardModel.self,
            User.self,
            SavedPracticeModel.self,
            AnalyticsModel.self,
            PracticeAttemptModel.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Last resort after schema/store issues (e.g. failed lightweight migration): wipe local store once.
            let storeURL = modelConfiguration.url
            let fm = FileManager.default
            try? fm.removeItem(at: storeURL)
            let path = storeURL.path
            try? fm.removeItem(at: URL(fileURLWithPath: path + "-shm"))
            try? fm.removeItem(at: URL(fileURLWithPath: path + "-wal"))
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()
        
    init() {
        #if os(macOS)
        MacOSBundledFontRegistration.registerPlusJakartaSansTTFs()
        #endif
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        _authVM = State(initialValue: AuthenticationViewModel())
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
#if os(macOS)
                .preferredColorScheme(.light)
#endif
                .environment(authVM)
                .environment(dataVM)
                .onAppear {
                    dataVM.modelContext = sharedModelContainer.mainContext
                }
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        #endif
    }
}
