//
//  DropboxWorker.swift
//  NoteBook
//
//  Created by Liwei Zhang on 2016-11-09.
//  Copyright © 2016 Liwei Zhang. All rights reserved.
//

import Foundation
import SwiftyDropbox
import Swiftz

typealias ErrorTypeInFileSystem = CustomStringConvertible

enum FileSystemError : ErrorTypeInFileSystem {
    case NoResponse
    
    var description: String {
        switch self {
        case .NoResponse:
            return "No response from file system."
        default:
            return "No match found."
        }
    }
}

protocol FileSystemWorkable {
    
    func maxVersion(queue: DispatchQueue, completionHandler: @escaping (Int?, ErrorTypeInFileSystem?) -> Void, under dir: String)
    func createFolder(queue: DispatchQueue, completionHandler: @escaping (String?, ErrorTypeInFileSystem?) -> Void, at folderFullPath: String)
    func upload(queue: DispatchQueue, completionHandler: @escaping (String?, ErrorTypeInFileSystem?) -> Void, data: Data, at fileFullPath: String)
    
}

// Reference after programmatic auth flow
let dropboxClient = DropboxClientsManager.authorizedClient

// Steps to upload a file:
// 1. Get title name from user input and use as file base name.
// 2. Find out existance of same title name content in file system. Check folder
//    anddifferent versions of the file. If no folder exists, create one.
// 3. Find out the version for the file and combine the title wih the version
//    picked as the file name.
// 4. Upload file.

protocol DropboxWorkable : FileSystemWorkable {
//    func continueListing(currentResult: Files.ListFolderResult?, error: ErrorTypeInFileSystem?, previousOnes: [Files.Metadata]?)
//    func listAll(queue: DispatchQueue, completionHandler: @escaping (Files.ListFolderResult?, ErrorTypeInFileSystem?, [Files.Metadata]?) -> Void, under fullPath: String)
}

extension DropboxWorkable {
    func continueListing(
        queue: DispatchQueue?,
        previousOnes: [Files.Metadata],
        errorHandler: @escaping (ErrorTypeInFileSystem?) -> Void,
        allDoneHandler: @escaping ([Files.Metadata]) -> Void,
        currentResult: Files.ListFolderResult?,
        error: ErrorTypeInFileSystem?) {
        switch (currentResult, error) {
        case (nil, nil):
            errorHandler(FileSystemError.NoResponse)
        case (nil, let e?):
            errorHandler(e)
        case (let m?, nil):
            switch m.hasMore {
            case true:
                let curriedSelf = curry(continueListing)
                let partialAppliedSelf = curriedSelf(queue)(previousOnes)(errorHandler)(allDoneHandler)
                dropboxClient?.files.listFolderContinue(cursor: m.cursor).response(queue: queue, completionHandler: uncurry(partialAppliedSelf))
            default:
                allDoneHandler(previousOnes + m.entries)
            }
        }
    }
    
    func listAll(
        queue: DispatchQueue,
        completionHandler: @escaping ([Files.Metadata]?, ErrorTypeInFileSystem?) -> Void,
        under fullPath: String,
        errorHandler: @escaping (ErrorTypeInFileSystem?) -> Void,
        next: @escaping ([Files.Metadata]) -> Void) {
        let curriedContinue = curry(continueListing)
        let partialAppliedContinue = uncurry(curriedContinue(queue)([])(errorHandler)(next))
        dropboxClient?.files.listFolder(path: fullPath).response(queue: queue, completionHandler: partialAppliedContinue)
    }
    

    
    func createFolder(completionHandler: @escaping (String?, ErrorTypeInFileSystem?) -> Void, byName: String, underPath: String) {
        dropboxClient?.files.createFolder(path: underPath).response(completionHandler: { folderMetadata, folderCallError in
            completionHandler(folderMetadata?.id, folderCallError)
        })
    }
    func upload(completionHandler: @escaping (String?, ErrorTypeInFileSystem?) -> Void, fileData: Data, withName: String, underPath: String) {
        dropboxClient?.files.upload(path: underPath, input: fileData).response(completionHandler: { fileMetadata, uploadCallError in
            completionHandler(fileMetadata?.id, uploadCallError)
        })
    }
    
    
    func maxTailingInt(among names: [String], seperator: String) -> Int? {
        guard names.count > 0 else {
            return nil
        }
        let intStrings = names.map { $0.splitInReversedOrder(by: seperator)?.right }
        guard intStrings.contains(where: { $0 == nil }) == false else {
            return nil
        }
        guard intStrings.contains(where: { Int($0!) == nil }) == false else {
            return nil
        }
        let ints = intStrings.map { Int($0!)! }
        return ints.reduce(ints.first!, { max($0, $1) })
    }
    
    func prepareToUpload(withName: String, underPath: String) {
        
    }
}

