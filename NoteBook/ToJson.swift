//
//  ToJson.swift
//  NoteBook
//
//  Created by Liwei Zhang on 2016-12-08.
//  Copyright © 2016 Liwei Zhang. All rights reserved.
//

import Foundation
import Gloss

struct Note {
    let url: String
    let tags: [String]?
    let annotation: String?
    let content: String
    let location: String?
}

extension Note: Glossy {
    public init?(json: JSON) {
        self.url = ("url" <~~ json)!
        self.tags = "tags" <~~ json
        self.annotation = "annotation" <~~ json
        self.content = ("content" <~~ json)!
        self.location = "location" <~~ json
    }
    
    func toJSON() -> JSON? {
        return jsonify([
            "url" ~~> self.url,
            "tags" ~~> self.tags,
            "annotation" ~~> self.annotation,
            "content" ~~> self.content,
            "location" ~~> self.location
            ])
    }
}

