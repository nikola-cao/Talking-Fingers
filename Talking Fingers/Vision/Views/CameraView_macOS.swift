//
//  CameraView_macOS.swift
//  Talking Fingers
//
//  Created by Jihoon Kim on 1/29/26.
//

#if os(macOS)
import SwiftUI
import AVFoundation
import Vision
import AppKit
import Observation

struct CameraView: View {
    @State private var cameraVM = CameraVM()
    @Environment(AuthenticationViewModel.self) private var authVM

    @State private var hands: [VNHumanHandPoseObservation] = []
    @State private var bodies: [VNHumanBodyPoseObservation] = []

    @State private var dotsVisibility: Bool = true
    @State private var jointNamesVisibility: Bool = false
    @State private var handOutlineVisibility: Bool = false
    @State private var handSkeletonVisibility: Bool = true
    @State private var bodySkeletonVisibility: Bool = true

    /// Live, user-editable name of the sign reference to compare against.
    /// When blank, no comparison runs and the Bad/Okay/Good label is hidden.
    @State private var signNameInput: String = ""

    /// When `true`, the comparison overlay shows the raw numeric score
    /// instead of the Bad/Okay/Good word.
    @State private var showRawConfidence: Bool = false

    /// Trimmed version of `signNameInput`. `nil` when blank.
    private var activeSignName: String? {
        let trimmed = signNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    @State private var jointVisibility: [VNHumanHandPoseObservation.JointName: Bool] = {
        var dict: [VNHumanHandPoseObservation.JointName: Bool] = [:]
        for joint in JointsSheetView.handJointLabels {
            dict[joint.name] = true
        }
        return dict
    }()

    @State private var bodyJointVisibility: [VNHumanBodyPoseObservation.JointName: Bool] = {
        var dict: [VNHumanBodyPoseObservation.JointName: Bool] = [:]
        for joint in JointsSheetView.bodyJointLabels {
            dict[joint.name] = true
        }
        return dict
    }()

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vision")
                            .font(.system(size: 28, weight: .semibold))
                        Text("Live camera feed with mirrored preview and pose overlays")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "hand.raised.fingers.spread")
                            .foregroundStyle(.secondary)
                        TextField("Sign reference (e.g. a)", text: $signNameInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 220)
                            .disableAutocorrection(true)
                        if !signNameInput.isEmpty {
                            Button {
                                signNameInput = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .help("Clear comparison reference")
                        }
                    }

                    Toggle(isOn: $showRawConfidence) {
                        HStack(spacing: 6) {
                            Image(systemName: showRawConfidence ? "number" : "textformat")
                            Text(showRawConfidence ? "Score" : "Label")
                        }
                    }
                    .toggleStyle(.switch)
                    .help("Toggle between word label and raw confidence score")
                }
                .padding(.horizontal, 28)
                .padding(.top, 20)

                Group {
                    if cameraVM.isAuthorized {
                        ZStack {
                            CameraPreviewView(
                                session: cameraVM.session,
                                isMirrored: cameraVM.isMirrored
                            )

                            GeometryReader { geo in
                                PoseOverlaysView(
                                    hands: hands,
                                    bodies: bodies,
                                    size: geo.size,
                                    cameraVM: cameraVM,
                                    jointVisibility: jointVisibility,
                                    bodyJointVisibility: bodyJointVisibility,
                                    dotsVisibility: dotsVisibility,
                                    jointNamesVisibility: jointNamesVisibility,
                                    handOutlineVisibility: handOutlineVisibility,
                                    handSkeletonVisibility: handSkeletonVisibility,
                                    bodySkeletonVisibility: bodySkeletonVisibility,
                                    style: .macCameraDebug
                                )
                            }

                            if activeSignName != nil {
                                VStack {
                                    Spacer()
                                    Text(confidenceDisplay)
                                        .font(.system(size: 56, weight: .bold, design: .rounded))
                                        .foregroundStyle(confidenceColor)
                                        .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                                        .contentTransition(.interpolate)
                                        .animation(.easeInOut(duration: 0.15), value: confidenceDisplay)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .padding(.bottom, 20)
                                }
                            }
                        }
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .frame(maxWidth: 1100)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 8)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 24)
                    } else {
                        ContentUnavailableView(
                            "Camera Access Required",
                            systemImage: "camera.fill",
                            description: Text("Allow camera access in System Settings to view the live feed.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .onAppear {
            cameraVM.userHandedness = authVM.effectiveHandedness
            cameraVM.isMirrored = true

            cameraVM.onPoseDetected = { handObservations, _ in
                hands = handObservations
            }

            cameraVM.onBodyPoseDetected = { bodyObservations, _ in
                bodies = bodyObservations
            }

            cameraVM.checkPermission()

            if let activeSignName {
                cameraVM.startComparing(forSign: activeSignName)
            }
        }
        .onChange(of: authVM.effectiveHandedness) { _, newValue in
            cameraVM.userHandedness = newValue
        }
        .task {
            try? await Task.sleep(for: .milliseconds(250))
            cameraVM.start()
        }
        .onDisappear {
            cameraVM.stop()
        }
        .onChange(of: signNameInput) { _, _ in
            if let activeSignName {
                cameraVM.startComparing(forSign: activeSignName)
            } else {
                cameraVM.stopComparing()
            }
        }
    }

    /// Thresholds for the Good / Okay / Bad bands, relaxed proportionally to
    /// the loaded reference's kinematic complexity (wrist path length, from
    /// `CameraVM.referenceComplexity`).
    ///
    /// DTW on long-travel signs accumulates more 2D alignment error per frame
    /// just by virtue of covering more pixels; a perfect performance of such
    /// a sign caps lower than a tight planar sign. The shift is single-
    /// direction (negative only) — complexity can only relax the thresholds,
    /// never tighten them — because path length is a "cost" signal, not a
    /// "precision" one.
    ///
    /// Max shift is 8 pts at complexity = 1 (`pathLength >= 0.20`), giving
    /// a dynamic-sign Good threshold range of 62..70.
    private var activeThresholds: (good: Double, okay: Double) {
        let isStatic = cameraVM.activeComparisonType == .static
        let baseGood: Double = isStatic ? 80 : 70
        let baseOkay: Double = isStatic ? 60 : 51

        let shift = -cameraVM.referenceComplexity * 8

        return (good: baseGood + shift, okay: baseOkay + shift)
    }

    private var confidenceColor: Color {
        let score = cameraVM.confidenceScore
        let t = activeThresholds
        if score >= t.good { return .green }
        if score >= t.okay { return .yellow }
        return .red
    }

    private var confidenceLabel: String {
        let score = cameraVM.confidenceScore
        let t = activeThresholds
        if score >= t.good { return "Good" }
        if score >= t.okay { return "Okay" }
        return "Bad"
    }

    private var confidenceDisplay: String {
        showRawConfidence ? "\(Int(cameraVM.confidenceScore.rounded()))%" : confidenceLabel
    }

}

// MARK: - Preview

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    var isMirrored: Bool = true

    final class VideoPreviewView: NSView {
        let previewLayer = AVCaptureVideoPreviewLayer()

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer = CALayer()
            layer?.masksToBounds = true
            previewLayer.videoGravity = .resizeAspectFill
            layer?.addSublayer(previewLayer)
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            wantsLayer = true
            layer = CALayer()
            layer?.masksToBounds = true
            previewLayer.videoGravity = .resizeAspectFill
            layer?.addSublayer(previewLayer)
        }

        override func layout() {
            super.layout()
            previewLayer.frame = bounds
        }
    }

    func makeNSView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        configure(view)
        return view
    }

    func updateNSView(_ nsView: VideoPreviewView, context: Context) {
        configure(nsView)
    }

    private func configure(_ view: VideoPreviewView) {
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.frame = view.bounds

        if isMirrored {
            view.previewLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
        } else {
            view.previewLayer.setAffineTransform(.identity)
        }
    }
}

#Preview {
    CameraView()
}
#endif
