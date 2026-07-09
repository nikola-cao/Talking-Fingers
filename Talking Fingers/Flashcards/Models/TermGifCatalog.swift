//
//  TermGifCatalog.swift
//  Talking Fingers
//
//  Resolves the bundled GIF file for a flashcard term. File names follow a
//  convention (alphabet terms use the uppercase letter, e.g. "A.gif";
//  everything else uses the lowercase case name, e.g. "hello.gif"), so adding
//  a GIF for a new term only requires bundling a file with a matching name.
//

import Foundation

enum TermGifCatalog {
    /// Terms whose GIF file doesn't follow the naming convention.
    private static let overrides: [Term: String] = [
        .surprised: "surprise.gif",
        .her: "his.gif", // HIS/HER share one ASL sign; only his.gif is bundled
    ]

    /// Terms mapped to GIF files that actually exist in the app bundle.
    private static let fileNames: [Term: String] = {
        var map: [Term: String] = [:]
        for term in Term.allCases {
            let name = overrides[term] ?? conventionalFileName(for: term)
            if Bundle.main.url(forResource: name, withExtension: nil) != nil {
                map[term] = name
            }
        }
        return map
    }()

    private static func conventionalFileName(for term: Term) -> String {
        term.category == .alphabet ? "\(term.rawValue).gif" : "\(term).gif"
    }

    static func gifFileName(for term: Term) -> String? {
        fileNames[term]
    }
}

extension Term {
    var defaultGifFileName: String? {
        TermGifCatalog.gifFileName(for: self)
    }
}
