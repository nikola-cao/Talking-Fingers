//
//  LocalAccountStore.swift
//  Talking Fingers
//
//  Records which account the on-device SwiftData store currently holds data
//  for. Nothing in that store carries a uid except the `User` row itself, so
//  this is what lets sign-in tell "same account as last time" from "someone
//  else's device data" and wipe before the new user ever sees it.
//
//  Deliberately survives sign-out: signing back into the *same* account keeps
//  its local progress, practices and stats.
//

import Foundation

enum LocalAccountStore {
    private static let lastSignedInUserIdKey = "lastSignedInUserId"

    static var lastSignedInUserId: String? {
        get { UserDefaults.standard.string(forKey: lastSignedInUserIdKey) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: lastSignedInUserIdKey)
            } else {
                UserDefaults.standard.removeObject(forKey: lastSignedInUserIdKey)
            }
        }
    }
}
