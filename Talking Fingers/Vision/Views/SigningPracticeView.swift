//
//  SigningPracticeView.swift
//  Talking Fingers
//

import SwiftUI
import AVFoundation
import Vision

/// Live camera view that scores the user's signing against a reference sign
/// and shows a Bad/Okay/Good confidence label plus joint overlays.
struct SigningPracticeView: View {
    /// Optional sign reference name to compare the user's pose against.
    /// When `nil`, the comparison overlay (Bad/Okay/Good label) is hidden
    /// and no reference is loaded.
    let signName: String?
    var onConfidenceChange: ((Double) -> Void)?
    /// Retained for call-site compatibility; the view currently renders no
    /// leave button on either platform.
    var showsLeaveButton: Bool
    /// Retained for call-site compatibility; the view no longer applies its
    /// own padding or aspect-ratio constraint.
    var usesInternalPadding: Bool

    init(signName: String? = nil,
         onConfidenceChange: ((Double) -> Void)? = nil,
         showsLeaveButton: Bool = true,
         usesInternalPadding: Bool = true,
         externalCameraVM: CameraVM? = nil) {
        self.signName = signName
        self.onConfidenceChange = onConfidenceChange
        self.showsLeaveButton = showsLeaveButton
        self.usesInternalPadding = usesInternalPadding
        _cameraVM = State(initialValue: externalCameraVM ?? CameraVM())
        self.ownsCameraLifecycle = externalCameraVM == nil
    }

    @State private var cameraVM: CameraVM
    /// When `true` the view manages the camera's `start`/`stop` lifecycle in
    /// `.onAppear`/`.onDisappear`. When an external VM is passed in, the
    /// parent is responsible for lifecycle, so those calls are skipped.
    /// Note: only macOS honors this; iOS has always managed the camera
    /// unconditionally and that behavior is preserved (see the lifecycle
    /// modifiers below).
    private let ownsCameraLifecycle: Bool

    @Environment(AuthenticationViewModel.self) private var authVM

    @State private var hands: [VNHumanHandPoseObservation] = []
    @State private var bodies: [VNHumanBodyPoseObservation] = []

    /// Tracks which hand joints the user wants visible on the overlay.
    @State private var jointVisibility: [VNHumanHandPoseObservation.JointName: Bool] = {
        var dict: [VNHumanHandPoseObservation.JointName: Bool] = [:]
        for joint in JointsSheetView.handJointLabels {
            dict[joint.name] = true
        }
        return dict
    }()

    /// Tracks which body joints the user wants visible on the overlay.
    @State private var bodyJointVisibility: [VNHumanBodyPoseObservation.JointName: Bool] = {
        var dict: [VNHumanBodyPoseObservation.JointName: Bool] = [:]
        for joint in JointsSheetView.bodyJointLabels {
            dict[joint.name] = true
        }
        return dict
    }()

    @State private var dotsVisibility: Bool = true
    @State private var jointNamesVisibility: Bool = false
    @State private var handOutlineVisibility: Bool = false
    @State private var handSkeletonVisibility: Bool = true
    @State private var bodySkeletonVisibility: Bool = true

    var body: some View {
        Group {
            if cameraVM.isAuthorized {
                ZStack {
                    #if os(iOS)
                    CameraPreviewView(session: cameraVM.session)
                        .ignoresSafeArea()
                    #else
                    CameraPreviewView(
                        session: cameraVM.session,
                        isMirrored: cameraVM.isMirrored
                    )
                    .ignoresSafeArea()
                    #endif

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
                            bodySkeletonVisibility: bodySkeletonVisibility
                        )
                    }

                    if signName != nil && hands.count > 0 {
                        VStack {
                            HStack {
                                Spacer()
                                Text(confidenceLabel)
                                    .foregroundStyle(confidenceColor)
                                    .contentTransition(.interpolate)
                                    .animation(.easeInOut(duration: 0.15), value: confidenceLabel)
                                    .font(.jakarta(size: 18, weight: .bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                    .padding(10)
                            }
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                #if os(iOS)
                .clipped()
                #endif
            } else {
                ContentUnavailableView(
                    "Camera Access Required",
                    systemImage: "camera.fill",
                    description: Text("Please allow camera access in Settings to use sign language recognition.")
                )
            }
        }
        .onAppear {
            cameraVM.userHandedness = authVM.effectiveHandedness

            #if os(iOS)
            cameraVM.checkPermission()
            #else
            if ownsCameraLifecycle {
                cameraVM.isMirrored = true
                cameraVM.checkPermission()
            }
            #endif

            cameraVM.onPoseDetected = { handObservations, _ in
                hands = handObservations
            }

            cameraVM.onBodyPoseDetected = { bodyObservations, _ in
                bodies = bodyObservations
            }

            if let signName {
                cameraVM.startComparing(forSign: signName)
            }
        }
        .onChange(of: authVM.effectiveHandedness) { _, newValue in
            cameraVM.userHandedness = newValue
        }
        .task {
            #if os(macOS)
            guard ownsCameraLifecycle else { return }
            #endif
            try? await Task.sleep(for: .milliseconds(300))
            cameraVM.start()
        }
        .onDisappear {
            #if os(macOS)
            guard ownsCameraLifecycle else { return }
            #endif
            cameraVM.stop()
        }
        .onChange(of: signName) { _, newValue in
            if let newValue {
                cameraVM.startComparing(forSign: newValue)
            } else {
                cameraVM.stopComparing()
            }
        }
        .onChange(of: cameraVM.confidenceScore) { _, newValue in
            let goodThreshold: Double = cameraVM.activeComparisonType == .static ? 62 : 50
            if cameraVM.confidenceScore >= goodThreshold {
                onConfidenceChange?(newValue)
            }
        }
        #if os(iOS)
        .navigationBarBackButtonHidden(true)
        #endif
    }

    private var confidenceColor: Color {
        let score = cameraVM.confidenceScore
        let goodThreshold: Double = cameraVM.activeComparisonType == .static ? 62 : 50
        let okayThreshold: Double = cameraVM.activeComparisonType == .static ? 46 : 27
        if score >= goodThreshold { return .green }
        if score >= okayThreshold { return .yellow }
        return .red
    }

    private var confidenceLabel: String {
        let score = cameraVM.confidenceScore
        let goodThreshold: Double = cameraVM.activeComparisonType == .static ? 62 : 50
        let okayThreshold: Double = cameraVM.activeComparisonType == .static ? 46 : 27
        if score >= goodThreshold { return "Good" }
        if score >= okayThreshold { return "Okay" }
        return "Bad"
    }
}

#Preview {
    //SigningPracticeView()
}
