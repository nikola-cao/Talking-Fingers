//
//  PoseOverlaysView.swift
//  Talking Fingers
//

import SwiftUI
import Vision

/// Visual styling for the pose overlays. The standard style matches the
/// practice/exercise camera views; the mac debug camera uses slightly
/// different opacities and the system caption font.
struct PoseOverlayStyle {
    var outlineFillOpacity: Double = 0.3
    var handSkeletonOpacity: Double = 0.6
    var bodySkeletonOpacity: Double = 0.7
    var usesSystemLabelFont: Bool = false

    static let standard = PoseOverlayStyle()
    static let macCameraDebug = PoseOverlayStyle(
        outlineFillOpacity: 0.25,
        handSkeletonOpacity: 0.75,
        bodySkeletonOpacity: 0.75,
        usesSystemLabelFont: true
    )
}

/// Draws the hand/body joint overlays (outline, dots, name labels, skeletons)
/// on top of a camera preview. Coordinate conversion is delegated to the
/// owning `CameraVM` so overlays stay aligned with its aspect-fill preview.
struct PoseOverlaysView: View {
    let hands: [VNHumanHandPoseObservation]
    let bodies: [VNHumanBodyPoseObservation]
    let size: CGSize
    let cameraVM: CameraVM
    let jointVisibility: [VNHumanHandPoseObservation.JointName: Bool]
    let bodyJointVisibility: [VNHumanBodyPoseObservation.JointName: Bool]
    let dotsVisibility: Bool
    let jointNamesVisibility: Bool
    let handOutlineVisibility: Bool
    let handSkeletonVisibility: Bool
    let bodySkeletonVisibility: Bool
    var style: PoseOverlayStyle = .standard

    static let handConnections: [(VNHumanHandPoseObservation.JointName, VNHumanHandPoseObservation.JointName)] = [
        // Thumb
        (.wrist, .thumbCMC), (.thumbCMC, .thumbMP), (.thumbMP, .thumbIP), (.thumbIP, .thumbTip),
        // Index
        (.wrist, .indexMCP), (.indexMCP, .indexPIP), (.indexPIP, .indexDIP), (.indexDIP, .indexTip),
        // Middle
        (.wrist, .middleMCP), (.middleMCP, .middlePIP), (.middlePIP, .middleDIP), (.middleDIP, .middleTip),
        // Ring
        (.wrist, .ringMCP), (.ringMCP, .ringPIP), (.ringPIP, .ringDIP), (.ringDIP, .ringTip),
        // Little
        (.wrist, .littleMCP), (.littleMCP, .littlePIP), (.littlePIP, .littleDIP), (.littleDIP, .littleTip)
    ]

    static let bodyConnections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.leftShoulder, .leftElbow),
        (.rightShoulder, .rightElbow)
    ]

    /// Points forming the closed hand-outline polygon.
    static let perimeterJoints: [VNHumanHandPoseObservation.JointName] = [
        .wrist,
        .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
        .indexTip,
        .middleTip,
        .ringTip,
        .littleTip,
        .littleDIP, .littlePIP, .littleMCP,
        .wrist
    ]

    var body: some View {
        handOutlineOverlay
        handJointLabelsOverlay
        bodyJointLabelsOverlay
        handSkeletonOverlay
        bodySkeletonOverlay
    }

    private func convert(_ visionPoint: CGPoint) -> CGPoint {
        cameraVM.convertVisionPointToScreenPosition(visionPoint: visionPoint, viewSize: size)
    }

    @ViewBuilder
    private var handOutlineOverlay: some View {
        if handOutlineVisibility {
            ForEach(hands, id: \.uuid) { hand in
                let points = Self.perimeterJoints.compactMap { jointName -> CGPoint? in
                    guard let point = try? hand.recognizedPoint(jointName),
                          point.confidence > 0.5 else { return nil }
                    return convert(point.location)
                }
                if points.count > 3 {
                    Path { path in
                        path.addLines(points)
                        path.closeSubpath()
                    }
                    .fill(Color.green.opacity(style.outlineFillOpacity))
                    .stroke(Color.green, lineWidth: 2)
                }
            }
        }
    }

    @ViewBuilder
    private var handJointLabelsOverlay: some View {
        ForEach(hands, id: \.uuid) { hand in
            let visibleJoints = JointsSheetView.handJointLabels.filter { jointVisibility[$0.name] == true }
            ForEach(visibleJoints, id: \.name) { joint in
                if let point = try? hand.recognizedPoint(joint.name), point.confidence > 0.5 {
                    let pos = convert(point.location)

                    let handSide = (cameraVM.isMirrored
                                    ? (hand.chirality == .left ? "R" : "L")
                                    : (hand.chirality == .left ? "L" : "R"))

                    ZStack {
                        if jointNamesVisibility {
                            jointLabel("\(handSide) \(joint.label)")
                                .position(pos)
                        }

                        if dotsVisibility {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 7, height: 7)
                                .position(pos)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var bodyJointLabelsOverlay: some View {
        ForEach(bodies, id: \.uuid) { body in
            let visibleBodyJoints = JointsSheetView.bodyJointLabels.filter { bodyJointVisibility[$0.name] == true }
            ForEach(visibleBodyJoints, id: \.name) { joint in
                if let point = try? body.recognizedPoint(joint.name), point.confidence > 0.3 {
                    let pos = convert(point.location)
                    ZStack {
                        if jointNamesVisibility {
                            jointLabel(joint.label)
                                .position(pos)
                        }

                        if dotsVisibility {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                                .position(pos)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func jointLabel(_ text: String) -> some View {
        if style.usesSystemLabelFont {
            Text(text)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
        } else {
            Text(text)
                .font(.jakartaCaption2)
                .padding(4)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    @ViewBuilder
    private var handSkeletonOverlay: some View {
        if handSkeletonVisibility {
            ForEach(hands, id: \.uuid) { hand in
                let handSkeletonColor = (cameraVM.isMirrored
                                         ? (hand.chirality == .left ? Color.purple : Color.blue)
                                         : (hand.chirality == .left ? Color.blue : Color.purple))

                Path { path in
                    for connection in Self.handConnections {
                        if let p1 = try? hand.recognizedPoint(connection.0),
                           let p2 = try? hand.recognizedPoint(connection.1),
                           p1.confidence > 0.5, p2.confidence > 0.5,
                           jointVisibility[connection.0] == true,
                           jointVisibility[connection.1] == true {

                            path.move(to: convert(p1.location))
                            path.addLine(to: convert(p2.location))
                        }
                    }
                }
                .stroke(handSkeletonColor.opacity(style.handSkeletonOpacity), lineWidth: 3)
            }
        }
    }

    @ViewBuilder
    private var bodySkeletonOverlay: some View {
        if bodySkeletonVisibility {
            ForEach(bodies, id: \.uuid) { body in
                Path { path in
                    for connection in Self.bodyConnections {
                        if let p1 = try? body.recognizedPoint(connection.0),
                           let p2 = try? body.recognizedPoint(connection.1),
                           p1.confidence > 0.3, p2.confidence > 0.3,
                           bodyJointVisibility[connection.0] == true,
                           bodyJointVisibility[connection.1] == true {

                            path.move(to: convert(p1.location))
                            path.addLine(to: convert(p2.location))
                        }
                    }
                }
                .stroke(Color.orange.opacity(style.bodySkeletonOpacity), lineWidth: 4)
            }
        }
    }
}
