//
//  LeaveConfirmationSheet.swift
//  Talking Fingers
//
//  Save / Don't save prompt shown when leaving an unsaved practice session.
//

import SwiftUI

struct LeaveConfirmationSheet: View {
    var onDontSave: () -> Void
    var onSave: () -> Void

    private let dontSaveRed = Color(hex: "#E85C5C")
    private let saveGreen = Color(hex: "#97C171")

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("Leave this practice?")
                    .font(.jakarta(size: 22, weight: .bold))
                    .foregroundColor(.black)

                Text("If you'd like to be able to come back to this practice, tap Save.")
                    .font(.jakarta(size: 15, weight: .regular))
                    .foregroundColor(Color(hex: "#767676"))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button(action: onDontSave) {
                        Text("Don't save")
                            .font(.jakarta(size: 17, weight: .semibold))
                            .foregroundColor(dontSaveRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(dontSaveRed.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: onSave) {
                        Text("Save")
                            .font(.jakarta(size: 17, weight: .semibold))
                            .foregroundColor(saveGreen)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(saveGreen.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
