//
//  DashboardView.swift
//  Talking Fingers
//
//  Created by Isha Jain on 2/5/26.
//

import SwiftUI
import SwiftData

enum ActiveFlow: Identifiable {
    case learn(TermCategory)
    case exercise(TermCategory)
    case dailyChallenge

    var id: String {
        switch self {
        case .learn(let cat): return "learn_\(cat.rawValue)"
        case .exercise(let cat): return "exercise_\(cat.rawValue)"
        case .dailyChallenge: return "dailyChallenge"
        }
    }
}

struct DashboardView: View {
    @State var flashcardVM = FlashcardVM()
    @State private var currentView: String = "Home"
    @State private var showOnboarding: Bool = false

    // for learn/exercise popup
    @State private var showModePopup: Bool = false
    @State private var selectedCategoryForPopup: TermCategory? = nil

    @State private var activeFlow: ActiveFlow? = nil
    @Environment(SwiftDataVM.self) private var dataVM
    @Environment(\.modelContext) var modelContext
    @Query var users: [User]

    var body: some View {
#if os(macOS)
        // MARK: - Mac Layout
        NavigationStack {
            HStack(spacing: 0) {

                // MAIN CONTENT
                Group {
                    if currentView == "Home" {
                        dashboardContent
                    } else {
                        categoryDetailView(currentView)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .background(Color.categoryComponentColor)
            .popupHost(isPresented: $showModePopup) {
                modePopup
            }
            .overlay {
                if let flow = activeFlow {
                    ZStack {
                        Color(NSColor.windowBackgroundColor)
                            .ignoresSafeArea()
                        flowDestination(for: flow)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .onAppear {
                loadUserFlashcardsIfNeeded()
            }
         }
#else
        // MARK: - iOS Layout
        NavigationStack {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    Color.white
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {

                        // MARK: - Top Nav
                        HStack {
                            Spacer()
                            Text("Talking Fingers")
                                .font(.jakarta(size: 18))
                                .fontWeight(.medium)
                                .foregroundColor(Color.gray.opacity(0.8))
                                .padding(.leading, 24)
                            Spacer()
                            Button {
                                showOnboarding = true
                            } label: {
                                Image(systemName: "questionmark.circle")
                                    .font(.jakarta(size: 20))
                                    .foregroundColor(TFColors.softBlue)
                            }
                            .padding(.trailing, 12)

                            NavigationLink {
                                SearchView()
                                    .navigationBarBackButtonHidden(true)
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.jakarta(size: 20))
                                    .foregroundColor(TFColors.softBlue) // TF Blue
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)

                        // MARK: - Welcome Header
                        welcomeHeader
                            .padding(.horizontal)

                        // MARK: - Jump back in! (White Bubble)
                        if !inProgressCategories.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Jump back in!")
                                    .font(.jakarta(size: 20))
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color.black.opacity(0.8))
                                    .padding(.horizontal, 20)
                                    .padding(.top, 20)

                                GeometryReader { geometry in
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(Array(inProgressCategories.enumerated()), id: \.element.category) { index, item in
                                                inProgressButton(for: item, width: 155)
                                            }
                                        }
                                        .frame(minWidth: max(0, geometry.size.width - 40), alignment: .center)
                                        .padding(.horizontal, 20)
                                        .padding(.bottom, 20)
                                    }
                                }
                                .frame(height: 240)
                            }
                            .background(Color.white)
                            .cornerRadius(24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .strokeBorder(Color.gray.opacity(0.6), lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
                            .padding(.horizontal, 16)
                        }

                        // MARK: - Daily Challenge
                        Text("Keep up your streak!")
                            .font(.jakarta(size: 20))
                            .fontWeight(.semibold)
                            .foregroundColor(Color.black.opacity(0.8))
                            .padding(.horizontal)

                        dailyChallengeButton
                            .padding(.horizontal)

                        // MARK: - Categories
                        Text("Categories")
                            .font(.jakarta(size: 20))
                            .fontWeight(.semibold)
                            .foregroundColor(Color.black.opacity(0.8))
                            .padding(.horizontal)

                        let columns = [
                            GridItem(.flexible(), spacing: 12)
                        ]
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(TermCategory.allCases, id: \.self) { category in
                                categoryButton(for: category, title: category.displayName)
                            }
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 120) // Give space for the floating tab bar
                        }
                        .padding(.top, proxy.safeAreaInsets.top + 8)
                        .background(alignment: .top) {
                            LinearGradient(
                                colors: [
                                    TFColors.headerGradientTop,
                                    TFColors.headerGradientBottom
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 320 + proxy.safeAreaInsets.top)
                        }
                    }
                    .ignoresSafeArea(edges: .top)
                }
            }
            .popupHost(isPresented: $showModePopup) {
                modePopup
            }
            .fullScreenCover(item: $activeFlow) { flow in
                flowDestination(for: flow)
            }
            .onAppear {
                loadUserFlashcardsIfNeeded()
            }
            .universalFullScreenCover(isPresented: $showOnboarding) {
                OnboardingView { _, _ in
                    showOnboarding = false
                }
            }
        }

#endif
    }

    // MARK: - Shared building blocks

    /// Learn/Exercise chooser shown when a category is tapped; identical on
    /// both platforms.
    private var modePopup: some View {
        ModePopupView(
            isPresented: $showModePopup,
            isExerciseUnlocked: selectedCategoryForPopup.map { canAccessCategory($0) && isExerciseUnlocked(for: $0) } ?? false,
            onLearn: {
                if let cat = selectedCategoryForPopup {
                    guard canAccessCategory(cat) else { return }
                    activeFlow = .learn(cat)
                }
            },
            onExercise: {
                if let cat = selectedCategoryForPopup {
                    guard canAccessCategory(cat) else { return }
                    activeFlow = .exercise(cat)
                }
            }
        )
    }

    /// The start card presented for an active flow (macOS overlay,
    /// iOS full-screen cover).
    @ViewBuilder
    private func flowDestination(for flow: ActiveFlow) -> some View {
        switch flow {
        case .learn(let category):
            FlexibleStartCardComponent(context: .learn(category), completed: 0, total: FlashcardVM.learnRoundSize) {
                activeFlow = nil
            }
            .environment(dataVM)
        case .exercise(let category):
            FlexibleStartCardComponent(context: .exercise(category), completed: 0, total: 12) {
                activeFlow = nil
            }
            .environment(dataVM)
        case .dailyChallenge:
            FlexibleStartCardComponent(context: .dailyChallenge, completed: 0, total: 5) {
                activeFlow = nil
            }
            .environment(dataVM)
        }
    }

    private var welcomeHeader: some View {
        HStack(spacing: 16) {
            Image("DashboardWelcome")
                .font(.jakarta(size: 45))
                .foregroundColor(TFColors.welcomeGold)

            VStack(alignment: .leading, spacing: 0) {
                if let userName = users.first?.name, !userName.isEmpty {
                    Text("Welcome back,")
                        .font(.jakarta(size: 26))
                        .fontWeight(.semibold)
                        .foregroundColor(Color.black.opacity(0.7))

                    Text(userName)
                        .font(.jakarta(size: 26))
                        .fontWeight(.semibold)
                        .foregroundColor(TFColors.tabBlue) // TF Blue
                } else {
                    Text("Welcome back!")
                        .font(.jakarta(size: 26))
                        .fontWeight(.semibold)
                        .foregroundColor(Color.black.opacity(0.7))
                }
            }
            Spacer()
        }
    }

    /// "Jump back in" card button. `width` pins the card width (iOS
    /// horizontal scroller); when nil the card stretches (macOS row).
    private func inProgressButton(for item: (category: TermCategory, progress: Float, mode: String), width: CGFloat? = nil) -> some View {
        let maxWidth: CGFloat? = width == nil ? .infinity : nil
        return Button {
            guard canAccessCategory(item.category) else { return }
            if item.mode == "Learn" {
                activeFlow = .learn(item.category)
            } else {
                activeFlow = .exercise(item.category)
            }
        } label: {
            InProgressCard(
                category: item.category,
                mode: item.mode,
                progress: item.progress,
                backgroundColor: item.mode == "Exercise" ? TFColors.cardBlueBg : TFColors.cardGreenBg,
                borderColor: item.mode == "Exercise" ? TFColors.cardBlueBorder : TFColors.cardGreenBorder
            )
            .frame(width: width)
            .frame(maxWidth: maxWidth)
            .opacity(canAccessCategory(item.category) ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!canAccessCategory(item.category))
    }

    private var dailyChallengeButton: some View {
        Button {
            activeFlow = .dailyChallenge
        } label: {
            DailyChallengeCard(
                streak: currentStreak,
                completed: dailyChallengeCompleted,
                total: dailyQueue.requestedLimit
            )
        }
        .buttonStyle(.plain)
    }

    private func categoryButton(for category: TermCategory, title: String) -> some View {
        Button {
            guard canAccessCategory(category) else { return }
            selectedCategoryForPopup = category
            showModePopup = true
        } label: {
            CategoryComponent(title: title, percentLearned: learnedPercentage(for: category))
                .frame(maxWidth: .infinity)
                .opacity(canAccessCategory(category) ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!canAccessCategory(category))
    }

    // MARK: - Mac content

    var dashboardContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: - Search
                NavigationLink {
                    SearchView()
                } label: {
                    HStack {
                        Text("Search for a word or phrase...")
                            .foregroundColor(.gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                        Image(systemName: "magnifyingglass")
                            .font(.jakarta(size: 20))
                            .foregroundColor(TFColors.softBlue) // TF Blue
                            .padding(.leading, 8)
                    }
                }
                .buttonStyle(.plain)

                HStack {
                    Spacer()
                    Button {
                        showOnboarding = true
                    } label: {
                        Label("View Onboarding", systemImage: "questionmark.circle")
                            .font(.jakarta(size: 16, weight: .semibold))
                            .foregroundColor(TFColors.softBlue)
                    }
                    .buttonStyle(.plain)
                }

                // MARK: - Welcome Header
                welcomeHeader
                    .padding(.top, 10)

                // MARK: - Mac Jump Back In
                if !inProgressCategories.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Jump back in!")
                            .font(.jakartaTitle)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        HStack(spacing: 16) {
                            ForEach(Array(inProgressCategories.enumerated()), id: \.element.category) { index, item in
                                inProgressButton(for: item)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .background(Color.white)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
                }

                // MARK: - Mac Daily Challenge
                Text("Daily Challenge")
                    .font(.jakartaTitle)

                dailyChallengeButton

                // MARK: - Categories
                Text("Categories")
                    .font(.jakartaTitle)

                VStack(spacing: 12) {
                    ForEach(TermCategory.allCases, id: \.self) { category in
                        categoryButton(for: category, title: category.rawValue.capitalized)
                    }
                }
            }
            .padding()
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .universalFullScreenCover(isPresented: $showOnboarding) {
            OnboardingView { _, _ in
                showOnboarding = false
            }
        }
    }


    func categoryDetailView(_ category: String) -> some View {
        VStack {
             HStack {
                Button {
                    currentView = "Home"
                } label: {
                    Image(systemName: "arrow.left")
                }

                Spacer()
            }

            Text(category)
                .font(.jakartaLargeTitle)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    DashboardView()
        .environment(SwiftDataVM())
}
