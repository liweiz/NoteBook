//
//  NoteBookTests.swift
//  NoteBookTests
//
//  Created by Liwei Zhang on 2016-11-09.
//  Copyright © 2016 Liwei Zhang. All rights reserved.
//

import XCTest
@testable import NoteBook
import Gloss

class NoteBookTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testToJson() {
        /// Given
        let aNote = Note(url: "/sd/dsa", tags: ["a", "43"], annotation: "xxx", content: "setup code here", location: "page 42")
        XCTAssertNotNil(aNote.toJSON())
        print("note in JSON: \(aNote.toJSON())")
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
