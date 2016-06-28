//
//  BBHttpClient.swift
//  BBSDKFramework
//
//  Created by 饶骏华 on 16/6/22.
//  Copyright © 2016年 Begodya. All rights reserved.
//

import UIKit

typealias HttpSuccessClosure = (response: AnyObject, urlResponse: NSHTTPURLResponse) -> Void
typealias HttpFailedClosure = (urlResponse: NSHTTPURLResponse, error: NSError) -> Void
typealias ProgressClosure = (progress: Float) -> Void

/*
 * HOST TYPE
 */
enum eHTTP_CLIENT: Int {
   case eHttpClientType_User = 1
}

/*
 * HOST
 */
private let HttpClientUserHost = "https://api.pierup.cn";


class BBHttpClient: NSObject {
    
    var basicPath: String!
    var operationQueue: NSOperationQueue!
    let baseParameters: Dictionary<String,String>!
    var HTTPHeaderFields: Dictionary<String,String>!
    
    // MARK: - --------------------System-------------------- 
    // 存储多个Client用于复用
    private static var __instanceMap: Dictionary<Int,BBHttpClient> = Dictionary<Int,BBHttpClient>()
    
    class func sharedInstanceWithClientType(type: eHTTP_CLIENT) -> BBHttpClient {
        let __sharedInstance = __instanceMap[type.rawValue]
        if __sharedInstance == nil {
            let lockQueue = dispatch_queue_create("com.lock.LockQueue", nil)
            dispatch_sync(lockQueue) {
               let __sharedInstance = BBHttpClient()
                __sharedInstance.basicPath = getHostByType(type)
                __instanceMap.updateValue(__sharedInstance, forKey: type.rawValue)
            }
        }
        return __sharedInstance! 
    }
    
    override init() {
        basicPath = ""
        operationQueue = NSOperationQueue.init()
        // 基础参数，暂时没有
        baseParameters = Dictionary<String,String>()
        HTTPHeaderFields = Dictionary<String,String>()
    }
    
    
    private class func getHostByType(type: eHTTP_CLIENT) -> String {
        switch type {
        case .eHttpClientType_User:
            return HttpClientUserHost
        }
    }
    
    // MARK: - --------------------接口API--------------------
    // METHOD GET
    func GET(path: String,
             saveToPath: String,
             parameters: Dictionary<String,String>,
             progress: ProgressClosure,
             success: HttpSuccessClosure,
             failed: HttpFailedClosure) -> BBHttpExecutor {
        return queueRequest(path,
                            method: eHttpMethod.HttpMethodPOST,
                            saveToPath: saveToPath,
                            parameters: parameters,
                            progress: progress,
                            success: success,
                            failed: failed,
                            postAsJSON: false)
    }
    
    // METHOD POST
    func POST(path: String,
              parameters: Dictionary<String,String>,
              progress: ProgressClosure,
              success: HttpSuccessClosure,
              failed: HttpFailedClosure) -> BBHttpExecutor {
        return queueRequest(path,
                            method: eHttpMethod.HttpMethodPOST,
                            saveToPath: nil,
                            parameters: parameters,
                            progress: progress,
                            success: success,
                            failed: failed,
                            postAsJSON: false)
    }
    
    func JSONPOST(path: String,
                  parameters: Dictionary<String,String>,
                  progress: ProgressClosure,
                  success: HttpSuccessClosure,
                  failed: HttpFailedClosure) -> BBHttpExecutor {
        return queueRequest(path,
                            method: eHttpMethod.HttpMethodPOST,
                            saveToPath: nil,
                            parameters: parameters,
                            progress: progress,
                            success: success,
                            failed: failed,
                            postAsJSON: true)
    }
    
    func UploadImage(path: String,
                     parameters: Dictionary<String,String>,
                     progress: ProgressClosure,
                     success: HttpSuccessClosure,
                     failed: HttpFailedClosure) -> BBHttpExecutor {
        return queueRequest(path,
                            method: eHttpMethod.HttpMethodPOST,
                            saveToPath: nil,
                            parameters: parameters,
                            progress: progress,
                            success: success,
                            failed: failed,
                            postAsJSON: false)
    }
    
    func PUT(path: String,
             parameters: Dictionary<String,String>,
             progress: ProgressClosure,
             success: HttpSuccessClosure,
             failed: HttpFailedClosure) -> BBHttpExecutor {
        return queueRequest(path,
                            method: eHttpMethod.HttpMethodPUT,
                            saveToPath: nil,
                            parameters: parameters,
                            progress: progress,
                            success: success,
                            failed: failed,
                            postAsJSON: false)
    }
    
    func JSONPUT(path: String,
                 parameters: Dictionary<String,String>,
                 progress: ProgressClosure,
                 success: HttpSuccessClosure,
                 failed: HttpFailedClosure) -> BBHttpExecutor {
        return queueRequest(path,
                            method: eHttpMethod.HttpMethodPUT,
                            saveToPath: nil,
                            parameters: parameters,
                            progress: progress,
                            success: success,
                            failed: failed,
                            postAsJSON: true)
    }
    
    // 取消所有任务
    func cancelAllRequests() -> Void {
        self.operationQueue.cancelAllOperations()
    }
    
    // 取消指定任务
    func cancelRequestWithPath(path: String) -> Void {
        for operation in self.operationQueue.operations {
            let requestPath: String? = operation.valueForKey("requestPath") as? String
            if requestPath == path {
                operation.cancel()
            }
        }
    }
    // MARK: - --------------------功能函数--------------------
    // HTTP Request
    private func queueRequest(path: String,
                      method: eHttpMethod,
                      saveToPath: String?,
                      parameters: Dictionary<String,String>,
                      progress: ProgressClosure,
                      success: HttpSuccessClosure,
                      failed: HttpFailedClosure,
                      postAsJSON: Bool) -> BBHttpExecutor {
        let completeURLString = self.basicPath + path
        var mergedParameters: AnyObject
        
        if method == eHttpMethod.HttpMethodPOST && !(parameters is Dictionary<String,String>) {
            mergedParameters = parameters
        } else {
            mergedParameters = Dictionary<String,String>()
            mergedParameters.addEntriesFromDictionary(parameters)
            mergedParameters.addEntriesFromDictionary(baseParameters)
        }
        
        let requestOperation = BBHttpExecutor.init(urlString: completeURLString,
                                                   method: method,
                                                   parameters: parameters,
                                                   saveToPath: saveToPath,
                                                   progress: progress,
                                                   success: success,
                                                   failed: failed,
                                                   postAsJSON: postAsJSON)
       return queueRequest(requestOperation)
    }
    
    // HTTP Operations
    private func queueRequest(requestOperation: BBHttpExecutor) -> BBHttpExecutor {
        // 添加 HTTP Header Fileds
        for (key,value) in HTTPHeaderFields {
            requestOperation.setValue(value, HTTPHeaderField: key)
        }
        // 添加至线程队列
        self.operationQueue.addOperation(requestOperation)
        return requestOperation
    }
    
    
}
