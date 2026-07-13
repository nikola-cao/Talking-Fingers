//
//  Array+Safe.swift
//  Talking Fingers
//
//  Bounds-checked subscript: returns nil instead of crashing on
//  out-of-range indices.
//

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
