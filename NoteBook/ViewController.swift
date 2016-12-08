//
//  ViewController.swift
//  NoteBook
//
//  Created by Liwei Zhang on 2016-11-09.
//  Copyright © 2016 Liwei Zhang. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

/// Submit process:
/// User input:
/// 1. source file url: 
///     function: Save the original url (if not available, use “N/A”).
///     UI: text input box
/// 2. annotation
///     function: user’s own input, such as comment.
///     UI: text input box
/// 3. tags
///     UI: text input box and table view to show existing tags
/// 4. content selected
///     UI: text input box
/// 5. content selected location
///     more detailed location for selected content, e.g, page number in a pdf file.
///     UI: text input box

//
//Check if the original url already exists in db. If yes, get file title from existing one. If not, have a title name for the file (no need to take version into account here).
//Get existing folder path or create a new folder based on title and for the file. There are two levels of folder the root folder is named by the title and the root folder contains another folder named by the original url. This is to distinguish same title file from different sources.
//Check the last version of the file to prepare a name for the file. File name is title + version no. The first version does not need a version number, e.g, “xxx” , and the second one is named “xxx_1”.
//Download the file from the original url and save with name prepared in the target folder.
//Save the path for the file.
//Have a timestamp.
