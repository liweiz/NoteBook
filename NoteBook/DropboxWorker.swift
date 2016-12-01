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
import RxSwift
//import Alamofire

//App key: y87c23cufz9ds2k
//App secret: hltjj0dhg866hek
//access token: _t5sqh9TeTsAAAAAAAAABzyJ2nBj3OG1wocKmGMCPOCYziDUnXKN6xQCdh21XNTt

/// Client and alternative queues to work with API.
struct DropboxWorker {
    let client: DropboxClient
    let dispatchQueues: [DispatchQueue]
}

/// Path to work with API.
struct Path {
    let dirPath: String
    let objName: String
}

/// Request to API.
class DropboxRequest {
    /// Worker.
    fileprivate var worker: DropboxWorker?
    fileprivate var client: DropboxClient {
        get { return worker!.client }
    }
    var queues: [DispatchQueue] {
        get { return worker!.dispatchQueues }
    }
    /// Path.
    var path: Path?
    var dirPath: String {
        get { return path!.dirPath }
    }
    var objName: String {
        get { return path!.objName }
    }
    var fullPath: String {
        get { return path!.dirPath + "/" + path!.objName }
    }
    var dirPathUrl: URL? {
        get {
            guard let url = URL(string: dirPath) else {
                return nil
            }
            return url }
    }
    var fullPathUrl: URL? {
        get {
            guard let url = URL(string: path!.dirPath + "/" + path!.objName) else {
                return nil
            }
            return url }
    }
    /// Error handler.
    var errorHandler: ((CustomStringConvertible) -> Void)?
    /// Queue.
    var queue: DispatchQueue = DispatchQueue.main
}

/// Constructor of DropboxRequest.
func createDropboxRequest(worker: DropboxWorker, path: Path, errorHandler: @escaping (CustomStringConvertible) -> Void) -> DropboxRequest {
    let req = DropboxRequest()
    req.worker = worker
    req.path = path
    req.errorHandler = errorHandler
    return req
}

/// Recategorized error from API.
enum ConvertedDropboxError {
    case unknown
    case invalidCursor
    case malformedPath
    case notFound
    case noPermission
    case needDifferentName
    case noSpace
    case lineBusy
}

/// Handle recategorized error.
func handleConvertedDropboxError(unknown: () -> Void,
                 invalidCursor: () -> Void,
                 malformedPath: () -> Void,
                 notFound: () -> Void,
                 noPermission: () -> Void,
                 needDifferentName: () -> Void,
                 noSpace: () -> Void,
                 lineBusy: () -> Void,
                 _ error: ConvertedDropboxError) {
    switch error {
    case .unknown:
        unknown()
    case .invalidCursor:
        invalidCursor()
    case .malformedPath:
        malformedPath()
    case .notFound:
        notFound()
    case .noPermission:
        noPermission()
    case .needDifferentName:
        needDifferentName()
    case .noSpace:
        noSpace()
    case .lineBusy:
        lineBusy()
    default:
        print("error not categorized: \(error)")
    }
}

/// Recategorize error.
func convertDropboxError(from apiError: CustomStringConvertible) -> ConvertedDropboxError {
    switch apiError {
    case let list as Files.ListFolderError:
        switch list {
        case .path(let lookupError):
            /// Get into nested.
            return convertDropboxError(from: lookupError)
        default:
            /// Unknown.
            return .unknown
        }
    case let listC as Files.ListFolderContinueError:
        switch listC {
        case .path(let lookupError):
            /// Get into nested.
            return convertDropboxError(from: lookupError)
        case .reset:
            /// Cursor not valid any more. Restart new listing needed.
            return .invalidCursor
        default:
            /// Unknown.
            return .unknown
        }
    case let lookup as Files.LookupError:
        switch lookup {
        case .malformedPath:
            /// Path alert needed.
            return .malformedPath
        case .notFound:
            /// File/folder to find not found.
            return .notFound
        case .restrictedContent:
            /// Permission alert needed.
            return .noPermission
        default:
            /// Unknown.
            return .unknown
        }
    case let upload as Files.UploadError:
        switch upload {
        case .path(let uploadWriteFailed):
            /// Get into nested.
            return convertDropboxError(from: uploadWriteFailed)
        default:
            /// Unknown.
            return .unknown
        }
    case let createFolder as Files.CreateFolderError:
        switch createFolder {
        case .path(let writeErr):
            /// Get into nested.
            return convertDropboxError(from: writeErr)
        }
    case let write as Files.WriteError:
        switch write {
        case .conflict:
            /// Other operations are undergoing, try later.
            return .lineBusy
        case .disallowedName:
            /// Name change needed.
            return .needDifferentName
        case .noWritePermission:
            /// Permission alert needed.
            return .noPermission
        case .insufficientSpace:
            /// Space alert needed.
            return .noSpace
        case .malformedPath:
            /// Path alert needed.
            return .malformedPath
        default:
            /// Unknown.
            return .unknown
        }
    case let uploadWrite as Files.UploadWriteFailed:
        return convertDropboxError(from: uploadWrite.reason)
    default:
        /// Unknown.
        return .unknown
    }
}

/// Generic type for API response.
protocol DropboxResponsable {
    associatedtype Ok
    associatedtype Err
    associatedtype Req
    func response(queue: DispatchQueue?, completionHandler: @escaping (Ok?, CallError<Err>?) -> Void) -> Req
}

/// To meet the rx's Swift.Error requirement for onError.
extension CallError : Error {}

/// Type-erased wrapper for Dropbox API response.
struct AnyDropboxResponsable<K, E, Q> : DropboxResponsable {
    typealias Ok = K
    typealias Err = E
    typealias Req = Q
    
    typealias ResponseHandler = (DispatchQueue?, @escaping (Ok?, CallError<Err>?) -> Void) -> Req
    
    let dropboxResponsable: ResponseHandler
    
    @discardableResult
    func response(queue: DispatchQueue?, completionHandler: @escaping (Ok?, CallError<Err>?) -> Void) -> Req {
        return self.dropboxResponsable(queue, completionHandler)
    }
}

/// Wrapper turns API response to an obverable.
func observableDropboxResponse<Ok, Err, Req>(queue: DispatchQueue? = nil, responsable: AnyDropboxResponsable<Ok, Err, Req>) -> Observable<Ok> {
    return Observable.create { observer in
        responsable.response(queue: queue, completionHandler: {
            switch $0 {
            case (nil, let err?):
                observer.on(.error(err))
            case (let res?, nil):
                observer.on(.next(res))
                observer.on(.completed)
            default:
                observer.on(.error(FileSystemError.unknownResponseError))
            }
        })
        return Disposables.create()
    }
}

/// Rx wrapper for API request.
class DropboxRequestRx: DropboxRequest {
    var disposeBag: DisposeBag = DisposeBag()
    var dirPathUrlRx: URL {
        get {
            guard let url = URL(string: dirPath) else {
                errorHandlerRx!(Files.LookupError.malformedPath(nil) as! Error)
                return
            }
            return path!.dirPath }
    }
    var errorHandlerRx: ((Error) -> Void)? {
        get {
            guard let h = errorHandler else {
                return nil
            }
            return {
                guard let err = $0 as? CustomStringConvertible else {
                    return
                }
                h(err)
            }
        }
    }
}

/// Constructor of DropboxRequestRx.
func createDropboxRequestRx(worker: DropboxWorker, path: Path, errorHandler: @escaping (CustomStringConvertible) -> Void) -> DropboxRequestRx {
    let req = DropboxRequestRx()
    req.worker = worker
    req.path = path
    req.errorHandler = errorHandler
    return req
}

/// Requests.
extension DropboxRequestRx {
    
    /// Upload request.
    
    typealias OkUp = Files.FileMetadata
    typealias ErrUp = Files.UploadError
    typealias OkUpSerializer = Files.FileMetadataSerializer
    typealias ErrUpSerializer = Files.UploadErrorSerializer
    typealias ReqUp = UploadRequest<OkUpSerializer, ErrUpSerializer>
    
    func upload(fileData: Data,
                completionHandler: @escaping (OkUp) -> Void) {
        let request = client.files.upload(path: dirPath, input: fileData)
        let responsable = AnyDropboxResponsable<OkUp, ErrUp, ReqUp>(dropboxResponsable: request.response)
        let observable = observableDropboxResponse(queue: queue, responsable: responsable)
        observable
            .subscribe(onNext: { completionHandler($0) },
                       onError: { self.errorHandlerRx!($0) },
                       onCompleted: { print("upload completed.") })
            .addDisposableTo(disposeBag)
    }
    
    /// List request
    
    typealias OkLi = Files.ListFolderResult
    typealias ErrLi = Files.ListFolderError
    typealias OkLiSerializer = Files.ListFolderResultSerializer
    typealias ErrLiSerializer = Files.ListFolderErrorSerializer
    typealias ReqLi = RpcRequest<OkLiSerializer, ErrLiSerializer>
    
    func listing(all: Bool, doneHandler: @escaping ([OkUp]) -> Void) {
        let request = client.files.listFolder(path: fullPath)
        let responsable = AnyDropboxResponsable<OkLi, ErrLi, ReqLi>(dropboxResponsable: request.response)
        let observable = observableDropboxResponse(queue: queue, responsable: responsable)
        observable
            .subscribe(onNext: {
                guard let initialResults = $0.entries as? [OkUp] else {
                    print("initialListing results type not consistent.")
                    return
                }
                if all && $0.hasMore {
                    self.continueListing(from: $0.cursor,
                                         previousResults: initialResults,
                                         doneHandler: doneHandler)
                } else {
                    doneHandler(initialResults)
                }
                
            },
                       onError: { self.errorHandlerRx!($0) },
                       onCompleted:  { print("initialListing completed.") })
            .addDisposableTo(disposeBag)
    }
    
    typealias ErrLiCon = Files.ListFolderContinueError
    typealias ErrLiConSerializer = Files.ListFolderContinueErrorSerializer
    typealias ReqLiCon = RpcRequest<OkLiSerializer, ErrLiConSerializer>
    
    func continueListing(from cursor: String,
                         previousResults: [OkUp],
                         doneHandler: @escaping ([OkUp]) -> Void) {
        let request = client.files.listFolderContinue(cursor: cursor)
        let responsable = AnyDropboxResponsable<OkLi, ErrLiCon, ReqLiCon>(dropboxResponsable: request.response)
        let observable = observableDropboxResponse(queue: queue, responsable: responsable)
        observable
            .subscribe(onNext: {
                guard let continuedResults = $0.entries as? [OkUp] else {
                    print("continueListing results type not consistent.")
                    return
                }
                if $0.hasMore {
                    self.continueListing(from: $0.cursor,
                                         previousResults: previousResults + continuedResults,
                                         doneHandler: doneHandler)
                } else {
                    doneHandler(previousResults + continuedResults)
                }
            },
                       onError: { self.errorHandlerRx!($0) },
                       onCompleted:  { print("continueListing completed.") })
            .addDisposableTo(disposeBag)
    }
    
    /// Create folder.
    
    typealias OkCr = Files.FolderMetadata
    typealias ErrCr = Files.CreateFolderError
    typealias OkCrSerializer = Files.FolderMetadataSerializer
    typealias ErrCrSerializer = Files.CreateFolderErrorSerializer
    typealias ReqCr = RpcRequest<OkCrSerializer, ErrCrSerializer>
    
    func createFolder(completionHandler: @escaping (OkCr) -> Void,
                      errorHandler: @escaping (Error) -> Void) {
        let request = client.files.createFolder(path: fullPath)
        let responsable = AnyDropboxResponsable<OkCr, ErrCr, ReqCr>(dropboxResponsable: request.response)
        let observable = observableDropboxResponse(queue: queue, responsable: responsable)
        observable
            .subscribe(onNext: { completionHandler($0) },
                       onError: { self.errorHandlerRx!($0) },
                       onCompleted: { print("folderCreation completed.") })
            .addDisposableTo(disposeBag)
    }
}


/// Error handling.
extension DropboxRequestRx {
    func handleError(_ error: Error) {
        
    }
    
    /// Check and create dir path when needed.
    func handleDirPathError(doneHandler: @escaping () -> Void) {
        guard let url = URL(string: fullPath) else {
            handleError(Files.LookupError.malformedPath(nil) as! Error)
            return
        }
        let urlAbove = url.deletingLastPathComponent()
        guard let urlDirPath = URL(string: dirPath) else {
            handleError(Files.LookupError.malformedPath(nil) as! Error)
            return
        }
        let
        let pathAbove = Path(dirPath: , objName: urlDirPathAbove.lastPathComponent)
        createDropboxRequestRx(worker: worker, path: , errorHandler: <#T##(CustomStringConvertible) -> Void#>)
        listing(all: false, doneHandler: { _ in
            self.createFolder(client: client,
                              on: q,
                              with: url.lastPathComponent,
                              under: urlAbove.absoluteString,
                              completionHandler: { _ in
                                doneHandler() },
                              errorHandler: self.handle(path: urlAbove.absoluteString)) })
    }
}

enum FileSystemError : ErrorTypeInFileSystem {
    case noResponse
    case unknownResponseError
    
    var description: String {
        switch self {
        case .noResponse:
            return "No response from file system."
        default:
            return "No match found."
        }
    }
}

typealias ErrorTypeInFileSystem = CustomStringConvertible & Error






protocol FileSystemWorkable {
    
}

// Reference after programmatic auth flow
let dropboxClient = DropboxClientsManager.authorizedClient
// Steps to upload a file:
// 1. Get title name from user input and use as file base name.
// 2. Find out existance of same title name content in file system. Check folder
//    and different versions of the file. If no folder exists, create one.
// 3. Find out the version for the file and combine the title wih the version
//    picked as the file name.
// 4. Upload file.





///
extension DropboxWorkable {
    
    
    func makeSureDirAvailable(client: DropboxClient,
                              on queue: DispatchQueue? = nil,
                              for dirPath: String,
                              doneHandler: @escaping (String) -> Void,
                              errorHandler: @escaping (Error) -> Void) {
        let q = queue ?? DispatchQueue.main
        let request = client.files.listFolder(path: dirPath)
        let responsable = AnyDropboxResponsable<
            Files.ListFolderResult,
            Files.ListFolderError,
            RpcRequest<Files.ListFolderResultSerializer, Files.ListFolderErrorSerializer>
            >(dropboxResponsable: request.response)
        let observable = observableDropboxResponse(queue: q, responsable: responsable)
//        observable
//            .subscribe(onNext: { _ in
//                doneHandler(dirPath)
//            },
//                       onError: {
//                        guard let e = $0 as? Files.ListFolderError else {
//                            errorHandler($0)
//                        }
//                        
//                        switch e {
//                        case .path(let pathError):
//                            switch pathError {
//                            case .notFound:
//                                
//                                createFolder(client: client, on: q, with: url.lastPathComponent, under: urlAbove.absoluteString, nameConflictHandler: <#T##() -> Void#>, completionHandler: <#T##(Files.FolderMetadataSerializer.ValueType) -> Void#>, errorHandler: <#T##(Error) -> Void#>)
//                        }
//            })
//                        .addDisposableTo(disposeBag)
//        }
    }
    
    func components(in url: String) -> [String] {
        return URL(fileURLWithPath: url).pathComponents
    }
    
    func dirPathAvailbe(client: DropboxClient,
                        on queue: DispatchQueue? = nil,
                        given dir: String,
                        doneHandler: @escaping (String) -> Void,
                        errorHandler: @escaping (Error) -> Void) {
        let q = queue ?? DispatchQueue.main
//        let request = client.files.listFolder(path: )
    }
    
    
    
   
    
    func afterFolderListing(under dir: String, namesUnder: [String], seperator: String, action: (Int?) -> Void) {
        let maxInt = maxTailingInt(among: namesUnder, seperator: seperator)
        action(maxInt)
    }
    

    
    func makeSureNoNameConflict(client: DropboxClient,
                                on queue: DispatchQueue? = nil,
                                with name: String,
                                under dir: String,
                                nameConflictHandler: @escaping () -> Void,
                                completionHandler: @escaping ([Files.Metadata]) -> Void,
                                errorHandler: @escaping (Error) -> Void) {
        let q = queue ?? DispatchQueue.main
        listFolderAll(client: client, on: q, path: dir, doneHandler: {
            ($0.map { $0.name }).contains(name) ? nameConflictHandler() : completionHandler($0)
        }, errorHandler: errorHandler)
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
}



