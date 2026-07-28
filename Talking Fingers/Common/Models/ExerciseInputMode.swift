//
//  ExerciseInputMode.swift
//  Talking Fingers
//

import Foundation

/// Which input modality the user is practising with during an exercise session.
/// `.mixed` means both Flashcards and Camera are active; each card randomly uses one.
enum ExerciseInputMode: Equatable {
    case flashcards
    case camera
    case mixed
}
