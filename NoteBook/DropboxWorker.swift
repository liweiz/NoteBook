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

protocol DropboxResponsable {
    associatedtype Right
    associatedtype Err
    associatedtype Req
    func response(queue: DispatchQueue?, completionHandler: @escaping (Right?, CallError<Err>?) -> Void) -> Req
}

struct AnyDropboxResponsable<R, E, Q> : DropboxResponsable {
    typealias RSerial = R
    typealias ESerial = E
    typealias Req = Q
    
    typealias ResponseHandler = (DispatchQueue?, @escaping (R?, CallError<E>?) -> Void) -> Q
    
    let dropboxResponsable: ResponseHandler
    
    @discardableResult
    func response(queue: DispatchQueue?, completionHandler: @escaping (R?, CallError<E>?) -> Void) -> Q {
        return self.dropboxResponsable(queue, completionHandler)
    }
}

func observableDropboxResponse<R, E, Req>(queue: DispatchQueue? = nil, responsable: AnyDropboxResponsable<R, E, Req>) -> Observable<R> {
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










protocol FileSystemWorkable {
    
//    func maxVersion(queue: DispatchQueue, completionHandler: @escaping (Int?, ErrorTypeInFileSystem?) -> Void, under dir: String)
//    func createFolder(queue: DispatchQueue, completionHandler: @escaping (String?, ErrorTypeInFileSystem?) -> Void, at folderFullPath: String)
//    func upload(queue: DispatchQueue, completionHandler: @escaping (String?, ErrorTypeInFileSystem?) -> Void, data: Data, at fileFullPath: String)
    
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

protocol RxWorkable {
    var disposeBag: DisposeBag { get set }
}

protocol DropboxWorkable : FileSystemWorkable, RxWorkable {
//    func continueListing(currentResult: Files.ListFolderResult?, error: ErrorTypeInFileSystem?, previousOnes: [Files.Metadata]?)
//    func listAll(queue: DispatchQueue, completionHandler: @escaping (Files.ListFolderResult?, ErrorTypeInFileSystem?, [Files.Metadata]?) -> Void, under fullPath: String)
//    func list(client: DropboxClient, on queue: DispatchQueue?, under dir: String?, from cursor: String?, existingResults: [Files.Metadata], finalHandler: ([Files.Metadata]) -> Void, errorHandler: (Error) -> Void)
    
}

extension CallError : Error {}

extension DropboxWorkable {
    
    func handle(error: Error) {
        
    }
    
    func handleError(unknown: () -> Void,
                     invalidCursor: () -> Void,
                     malformedPath: () -> Void,
                     notFound: () -> Void,
                     noPermission: () -> Void,
                     needDifferentName: () -> Void,
                     noSpace: ()-> Void,
                     _ err: Error) {
        switch err {
        case let list as Files.ListFolderError:
            switch list {
            case .path(let lookupError):
                /// Get into nested.
                if let e = lookupError as? Error {
                    handleError(unknown: unknown, invalidCursor: invalidCursor, malformedPath: malformedPath, notFound: notFound, noPermission: noPermission, needDifferentName: needDifferentName, noSpace: noSpace, e)
                } else {
                    unknown()
                }
            default:
                /// Unknown.
                unknown()
            }
        case let listC as Files.ListFolderContinueError:
            switch listC {
            case .path(let lookupError):
                /// Get into nested.
                if let e = lookupError as? Error {
                    handleError(unknown: unknown, invalidCursor: invalidCursor, malformedPath: malformedPath, notFound: notFound, noPermission: noPermission, needDifferentName: needDifferentName, noSpace: noSpace, e)
                } else {
                    unknown()
                }
            case .reset:
                /// Cursor not valid any more. Restart new listing needed.
                invalidCursor()
            default:
                /// Unknown.
                unknown()
            }
        case let lookup as Files.LookupError:
            switch lookup {
            case .malformedPath:
                /// Path alert needed.
                malformedPath()
            case .notFound:
                /// File/folder to find not found.
                notFound()
            case .restrictedContent:
                /// Permission alert needed.
                noPermission()
            default:
                /// Unknown.
                unknown()
            }
        case let upload as Files.UploadError:
            switch upload {
            case .path(let uploadWriteFailed):
                /// Get into nested.
                if let e = uploadWriteFailed as? Error {
                    handleError(unknown: unknown, invalidCursor: invalidCursor, malformedPath: malformedPath, notFound: notFound, noPermission: noPermission, needDifferentName: needDifferentName, noSpace: noSpace, e)
                } else {
                    unknown()
                }
            default:
                /// Unknown.
                unknown()
            }
        case let createFolder as Files.CreateFolderError:
            switch createFolder {
            case .path(let writeErr):
                /// Get into nested.
                if let e = writeErr as? Error {
                    handleError(unknown: unknown, invalidCursor: invalidCursor, malformedPath: malformedPath, notFound: notFound, noPermission: noPermission, needDifferentName: needDifferentName, noSpace: noSpace, e)
                } else {
                    unknown()
                }
            default:
                /// Unknown.
                unknown()
            }
        case let write as Files.WriteError:
            switch write {
            case .conflict, .disallowedName:
                /// Name change needed.
                needDifferentName()
            case .noWritePermission:
                /// Permission alert needed.
                noPermission()
            case .insufficientSpace:
                /// Space alert needed.
                noSpace()
            case .malformedPath:
                /// Path alert needed.
                malformedPath()
            default:
                /// Unknown.
                unknown()
            }
        default:
            /// Unknown.
            unknown()
        }
    }
    
    func makeSureDirAvailable(client: DropboxClient,
                              on queue: DispatchQueue? = nil,
                              for dirPath: String,
                              doneHandler: @escaping (String) -> Void,
                              errorHandler: @escaping (Error) -> Void) {
        let q = queue ?? DispatchQueue.main
        let request = client.files.listFolder(path: dirPath)
        let responsable = AnyDropboxResponsable<Files.ListFolderResult, Files.ListFolderError, RpcRequest<Files.ListFolderResultSerializer, Files.ListFolderErrorSerializer>>(dropboxResponsable: request.response)
        let observable = observableDropboxResponse(queue: q, responsable: responsable)
        observable
            .subscribe(onNext: { _ in
                doneHandler(dirPath)
            },
                       onError: {
                        guard let e = $0 as? Files.ListFolderError else {
                            errorHandler($0)
                        }
                        
                        switch e {
                        case .path(let pathError):
                            switch pathError {
                            case .notFound:
                                guard let url = URL(string: dirPath) else {
                                    errorHandler($0)
                                }
                                let urlAbove = url.deletingLastPathComponent()
                                createFolder(client: client, on: q, with: url.lastPathComponent, under: urlAbove.absoluteString, nameConflictHandler: <#T##() -> Void#>, completionHandler: <#T##(Files.FolderMetadataSerializer.ValueType) -> Void#>, errorHandler: <#T##(Error) -> Void#>)
                        }
            })
            .addDisposableTo(disposeBag)
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
        let request = client.files.listFolder(path: <#T##String#>)
    }
    
    func continueListing(client: DropboxClient,
                         on queue: DispatchQueue? = nil,
                         from cursor: String,
                         previousResults: [Files.Metadata],
                         doneHandler: @escaping ([Files.Metadata]) -> Void,
                         errorHandler: @escaping (Error) -> Void) {
        let q = queue ?? DispatchQueue.main
        let request = client.files.listFolderContinue(cursor: cursor)
        let responsable = AnyDropboxResponsable<Files.ListFolderResult, Files.ListFolderContinueError, RpcRequest<Files.ListFolderResultSerializer, Files.ListFolderContinueErrorSerializer>>(dropboxResponsable: request.response)
        let observable = observableDropboxResponse(queue: q, responsable: responsable)
        observable
            .subscribe(onNext: { result in
            if result.hasMore {
                self.continueListing(client: client,
                                     on: queue,
                                     from: result.cursor,
                                     previousResults: previousResults + result.entries,
                                     doneHandler: doneHandler,
                                     errorHandler: errorHandler)
            } else {
                doneHandler(previousResults + result.entries)
            }
                
        },
                             onError: { errorHandler($0) },
                             onCompleted:  { print("continueListing completed.") })
            .addDisposableTo(disposeBag)
    }
    
    func listFolderAll(client: DropboxClient,
                       on queue: DispatchQueue? = nil,
                       path: String,
                       doneHandler: @escaping ([Files.Metadata]) -> Void,
                       errorHandler: @escaping (Error) -> Void) {
        let q = queue ?? DispatchQueue.main
        let request = client.files.listFolder(path: path)
        let responsable = AnyDropboxResponsable<Files.ListFolderResult, Files.ListFolderError, RpcRequest<Files.ListFolderResultSerializer, Files.ListFolderErrorSerializer>>(dropboxResponsable: request.response)
        let observable = observableDropboxResponse(queue: q, responsable: responsable)
        observable
            .subscribe(onNext: {
                if $0.hasMore {
                    self.continueListing(client: client, on: q, from: $0.cursor, previousResults: $0.entries, doneHandler: doneHandler, errorHandler: errorHandler)
                } else {
                    doneHandler($0.entries)
                }
            },
                       onError: errorHandler,
                       onCompleted: { print("initialListing completed.") })
            .addDisposableTo(disposeBag)
        
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

    
    func createFolder(client: DropboxClient,
                      on queue: DispatchQueue? = nil,
                      with name: String,
                      under dir: String,
                      nameConflictHandler: @escaping () -> Void,
                      completionHandler: @escaping (Files.FolderMetadataSerializer.ValueType) -> Void,
                      errorHandler: @escaping (Error) -> Void) {
        let q = queue ?? DispatchQueue.main
        let request = client.files.createFolder(path: dir + "/" + name)
        let responsable = AnyDropboxResponsable<
            Files.FolderMetadata,
            Files.CreateFolderError,
            RpcRequest<Files.FolderMetadataSerializer, Files.CreateFolderErrorSerializer>
            >(dropboxResponsable: request.response)
        let observable = observableDropboxResponse(queue: q, responsable: responsable)
        observable
            .subscribe(onNext: { completionHandler($0) },
                       onError: {
                        if let e = $0 as? Files.CreateFolderError {
                            switch e {
                            case .path(_):
                                
                            }
                        }
                        errorHandler($0)
            },
                       onCompleted: { print("folderCreation completed.") })
            .addDisposableTo(disposeBag)
    }
    
    func upload(client: DropboxClient,
                on queue: DispatchQueue? = nil,
                fileData: Data,
                with name: String,
                under dir: String,
                nameConflictHandler: @escaping () -> Void,
                completionHandler: @escaping (Files.FileMetadata) -> Void,
                errorHandler: @escaping (Error) -> Void) {
        let q = queue ?? DispatchQueue.main
        let request = client.files.upload(path: dir, input: fileData)
        let responsable = AnyDropboxResponsable<Files.FileMetadata, Files.UploadError, UploadRequest<Files.FileMetadataSerializer, Files.UploadErrorSerializer>>(dropboxResponsable: request.response)
        let observable = observableDropboxResponse(queue: q, responsable: responsable)
        observable
            .subscribe(onNext: { completionHandler($0) },
                       onError: { errorHandler($0) },
                       onCompleted: { print("upload completed.") })
            .addDisposableTo(disposeBag)
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

