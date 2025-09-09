//
//  MovieDocCtrl.swift
//  Studio Media Player
//
//  Created by DannyNiu on 2025-09-09.
//

import Cocoa

class MovieDocCtrl: NSDocumentController {
    
    @IBOutlet var movied: MovieDoc!
    
    override func makeDocument(withContentsOf url: URL, ofType typeName: String) throws -> NSDocument {
        // My implementation doesn't have a throw.
        try! movied.read(from: url, ofType: typeName)
        return movied
    }
}
