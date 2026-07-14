//
//  SigningPracticeView.swift
//  Talking Fingers
//

import SwiftUI
import AVFoundation
import Vision

#if os(iOS)
struct SigningPracticeView: View {
    @State private var cameraVM: CameraVM
    /// When `true` the view manages the camera's `start`/`stop` lifecycle in
    /// `.onAppear`/`.onDisappear`. When an external VM is passed in, the parent
    /// is responsible for lifecycle, so we skip those calls.
    private let ownsCameraLifecycle: Bool

    @State private var hands: [VNHumanHandPoseObservation] = []
    @State private var bodies: [VNHumanBodyPoseObservation] = []

    @Environment(AuthenticationViewModel.self) var authVM

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

    let signName: String?
    var onConfidenceChange: ((Double) -> Void)?
    /// Present for API parity with the macOS variant; the iOS view has no
    /// built-in leave button so this value is currently unused.
    var showsLeaveButton: Bool
    /// When `true` (default) the view applies its own horizontal padding and a
    /// 9:16 aspect ratio constraint to the camera. Set to `false` when
    /// embedding in a parent that wants to control sizing directly.
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

    var body: some View {
        Group {
            if cameraVM.isAuthorized {
                ZStack {
                    CameraPreviewView(session: cameraVM.session)
                        .ignoresSafeArea()
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
                .clipped()
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
            cameraVM.checkPermission()

            cameraVM.onPoseDetected = { handObservations, _ in
                hands = handObservations
            }

            cameraVM.onBodyPoseDetected = { bodyObservations, _ in
                bodies = bodyObservations
            }
            cameraVM.startComparing(forSign: signName ?? "")
        }
        .onChange(of: authVM.effectiveHandedness) { _, newValue in
            cameraVM.userHandedness = newValue
        }
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            cameraVM.start()
        }
        .onDisappear {
            cameraVM.stop()
        }
        .onChange(of: cameraVM.confidenceScore) { _, newValue in
            let goodThreshold: Double = cameraVM.activeComparisonType == .static ? 62 : 50
            if cameraVM.confidenceScore >= goodThreshold {
                onConfidenceChange?(newValue)
            }
        }
        .onChange(of: signName ?? "") { _, newValue in
            print("Current word is \(newValue)")
            cameraVM.startComparing(forSign: newValue)
        }
        .navigationBarBackButtonHidden(true)
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
#endif

#if os(macOS)
struct SigningPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthenticationViewModel.self) private var authVM

    /// Optional sign reference name to compare the user's pose against.
    /// When `nil`, the comparison overlay (Bad/Okay/Good label) is hidden
    /// and no reference is loaded.
    let signName: String?
    var onConfidenceChange: ((Double) -> Void)?
    /// When `false`, hides the top "Leave" button so the view can be embedded
    /// inside another view that already provides navigation.
    var showsLeaveButton: Bool
    /// When `true` (default) the view applies its own horizontal padding and a
    /// 16:9 aspect ratio constraint to the camera. Set to `false` when
    /// embedding in a parent that wants to control sizing directly.
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
    /// `.onAppear`/`.onDisappear`. When an external VM is passed in, the parent
    /// is responsible for lifecycle, so we skip those calls.
    private let ownsCameraLifecycle: Bool

    @State private var hands: [VNHumanHandPoseObservation] = []
    @State private var bodies: [VNHumanBodyPoseObservation] = []

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

    @State private var dotsVisibility: Bool = true
    @State private var jointNamesVisibility: Bool = false
    @State private var handOutlineVisibility: Bool = false
    @State private var handSkeletonVisibility: Bool = true
    @State private var bodySkeletonVisibility: Bool = true

    var body: some View {
        Group {
            if cameraVM.isAuthorized {
                ZStack {
                    CameraPreviewView(
                        session: cameraVM.session,
                        isMirrored: cameraVM.isMirrored
                    )
                    .ignoresSafeArea()

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
            if ownsCameraLifecycle {
                cameraVM.isMirrored = true
                cameraVM.checkPermission()
            }

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
            guard ownsCameraLifecycle else { return }
            try? await Task.sleep(for: .milliseconds(300))
            cameraVM.start()
        }
        .onDisappear {
            if ownsCameraLifecycle {
                cameraVM.stop()
            }
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
#endif
