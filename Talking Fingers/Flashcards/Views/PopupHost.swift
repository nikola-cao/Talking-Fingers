//
//  PopupHost.swift
//  Talking Fingers
//
//  Created by Ria Sharma/Isha Jain on 3/15/26.
//

import SwiftUI

/// Presents a popup for an optional item.
///
/// Item-driven rather than `Bool`-driven on purpose. The content closure is
/// stored in the modifier, so it captures a *copy* of the presenting view —
/// `@Observable` objects inside it stay live (they're references), but plain
/// `@State` values go stale, and a popup built from one would render whatever
/// the value was before it was presented. Passing the item through a `Binding`
/// and handing it to the closure means the content can never disagree with
/// what was tapped.
struct PopupHostModifier<Item: Equatable, PopupContent: View>: ViewModifier {
    @Binding var item: Item?
    var onDismiss: (() -> Void)?
    @ViewBuilder var popupContent: (Item) -> PopupContent

    @State private var showDim: Bool = false
    @State private var showPopupContainer: Bool = false
    /// Held so the popup keeps its content while animating out, after `item`
    /// has already cleared.
    @State private var presentedItem: Item?

    private var isPresented: Bool { item != nil }

    func body(content: Content) -> some View {
        ZStack {
            content

            if showDim {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .allowsHitTesting(isPresented)
                    .onTapGesture {
                        dismiss()
                    }
                    .zIndex(1)
            }

            if showPopupContainer, let presentedItem {
                VStack {
                    Spacer()
                    popupContent(presentedItem)
                }
                .transition(.move(edge: .bottom))
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(isPresented)
                .zIndex(2)
            }
        }
        .onChange(of: item) { _, newValue in
            if let newValue {
                presentedItem = newValue
                withAnimation(.easeInOut(duration: 0.32)) {
                    showDim = true
                    showPopupContainer = true
                }
            } else {
                withAnimation(.easeInOut(duration: 0.35)) {
                    showPopupContainer = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    // If the popup re-opened quickly, do not hide the dimmer.
                    guard item == nil else { return }
                    withAnimation(.easeInOut(duration: 0.35)) {
                        showDim = false
                    }
                }
            }
        }
        .onAppear {
            if let item {
                presentedItem = item
                showDim = true
                showPopupContainer = true
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.35)) {
            item = nil
        }
        onDismiss?()
    }
}

extension View {
    func popupHost<Item: Equatable, PopupContent: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> PopupContent
    ) -> some View {
        self.modifier(PopupHostModifier(item: item, onDismiss: onDismiss, popupContent: content))
    }

    /// Convenience for popups whose content doesn't depend on what was tapped.
    /// When it does, use the item-based version — content built from the
    /// presenting view's `@State` can be a step behind.
    func popupHost<PopupContent: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> PopupContent
    ) -> some View {
        let item = Binding<Bool?>(
            get: { isPresented.wrappedValue ? true : nil },
            set: { isPresented.wrappedValue = $0 ?? false }
        )
        return self.modifier(
            PopupHostModifier(item: item, onDismiss: onDismiss, popupContent: { _ in content() })
        )
    }
}
