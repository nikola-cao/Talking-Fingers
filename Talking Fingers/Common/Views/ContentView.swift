//
//  ContentView.swift
//  Talking Fingers
//
//  Created by Nikola Cao on 1/24/26.
//
import SwiftUI
struct ContentView: View {
    @Environment(AuthenticationViewModel.self) var authVM
    @Environment(SwiftDataVM.self) private var dataVM
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if authVM.isInitializingSession {
                Color.white
                    .ignoresSafeArea()
            } else if authVM.currentUser != nil {
                MainNavigationView()
            } else {
                EntryView()
            }
        }
        .onAppear {
            if let user = authVM.currentUser {
                Task { await dataVM.syncAuthenticatedUser(user) }
            }
        }
        .onChange(of: authVM.currentUser?.userId) { _, userId in
            guard userId != nil, let user = authVM.currentUser else { return }
            Task { await dataVM.syncAuthenticatedUser(user) }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active,
               let userId = authVM.currentUser?.userId,
               let localUser = dataVM.localUser(matching: userId) {
                dataVM.checkAndResetStreak(for: localUser)
            }
        }
    }
}
struct MainNavigationView: View {
    @Environment(AuthenticationViewModel.self) var authVM
    @State private var selectedSection: NavigationSection = .home
    #if os(macOS)
    @State private var isSidebarCollapsed: Bool = false
    #endif
    
    var body: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            MacSidebarView(
                selection: $selectedSection,
                isCollapsed: $isSidebarCollapsed,
                userName: authVM.currentUser?.name ?? ""
            )

            detailView(for: selectedSection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .ignoresSafeArea(.container, edges: .top)
        .configureMacWindowChrome()
        #else
        ZStack(alignment: .bottom) {
            detailView(for: selectedSection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            MainFloatingTabBar(selectedSection: $selectedSection)
        }
        .background(Color.white.ignoresSafeArea())
        .ignoresSafeArea(.keyboard, edges: .bottom)
        #endif
    }
    
    @ViewBuilder
    private func detailView(for section: NavigationSection) -> some View {
        switch section {
        case .home:
            DashboardView()
        case .stats:
            StatsView()
        case .camera:
            NavigationStack {
                CameraView()
            }
        case .review:
            NavigationStack {
                ReviewView()
            }
        case .practice:
            NavigationStack {
                SavedPracticeView()
            }
        }
    }
    
    enum NavigationSection: Hashable {
        case home, stats, camera, review, practice
    }

    /// One entry in the main navigation (Mac sidebar / iOS floating tab bar).
    struct NavItem {
        let section: NavigationSection
        let title: String
        let icon: String
    }

    /// Single source for the sections exposed in the main navigation on both
    /// platforms. (`.camera`/`.review` are dev tools and deliberately absent.)
    static let mainNavItems: [NavItem] = [
        NavItem(section: .home, title: "Home", icon: "house.fill"),
        NavItem(section: .practice, title: "Practice", icon: "hand.raised.fill"),
        NavItem(section: .stats, title: "Profile", icon: "person.fill"),
    ]
}

#if os(iOS)
private struct MainFloatingTabBar: View {
    @Binding var selectedSection: MainNavigationView.NavigationSection
    
    var body: some View {
        HStack {
            Spacer()
            ForEach(MainNavigationView.mainNavItems, id: \.section) { item in
                tabButton(
                    icon: item.icon,
                    title: item.title,
                    section: item.section
                )
                Spacer()
            }
        }
        .padding(.vertical, 9)
        .background(Color.white)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 5)
        .padding(.horizontal, 30)
        .padding(.bottom, -20)
    }
    
    private func tabButton(
        icon: String,
        title: String,
        section: MainNavigationView.NavigationSection
    ) -> some View {
        let isSelected = selectedSection == section
        return Button {
            selectedSection = section
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.jakarta(size: 22))
                Text(title)
                    .font(.jakarta(size: 10))
                    .fontWeight(.semibold)
            }
            .foregroundColor(
                isSelected
                ? TFColors.tabBlue
                : Color.gray.opacity(0.6)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(
                        isSelected
                        ? TFColors.tabBlue.opacity(0.15)
                        : Color.clear
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
#endif
struct StatsView: View {
    var body: some View {
        #if os(iOS)
        ProfileWidgetsView(presentation: .embedded)
        #else
        MacProfileView()
        #endif
    }
}
#Preview {
    ContentView()
}
