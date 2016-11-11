//
//  FileSystemPickerCtl.swift
//  NoteBook
//
//  Created by Liwei Zhang on 2016-11-09.
//  Copyright © 2016 Liwei Zhang. All rights reserved.
//

import UIKit
import SwiftyDropbox

class FileSystemPickerCtl: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    func myButtonInControllerPressed() {
        DropboxClientsManager.authorizeFromController(UIApplication.shared, controller: self, openURL: { (url: URL) -> Void in
            UIApplication.shared.open(url, options: <#T##[String : Any]#>, completionHandler: <#T##((Bool) -> Void)?##((Bool) -> Void)?##(Bool) -> Void#>)
        })
    }
}


