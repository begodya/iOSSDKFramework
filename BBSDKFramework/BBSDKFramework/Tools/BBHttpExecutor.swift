//
//  BBHttpExecutor.swift
//  BBSDKFramework
//
//  Created by 饶骏华 on 16/6/23.
//  Copyright © 2016年 Begodya. All rights reserved.
//

import UIKit

enum eHttpMethod {
    case HttpMethodGET
    case HttpMethodPOST
    case HttpMethodPUT
}

enum HTTPRequestState {
    case HTTPRequestStateReady
    case HTTPRequestStateExecuting
    case HTTPRequestStateFinished

}

private let HTTPTimeoutInterval: NSTimeInterval = 30
private let PLATFORM: String = "iOS"
private let VERSION: String = "1.0"

class BBHttpExecutor: NSOperation {
    
    // public
//    var userAgent: String!
    var sendParametersAsJSON: Bool
//    var cachePolicy: NSURLRequestCachePolicy!
    var timeoutInterval: NSTimeInterval
    var operationRequest: NSMutableURLRequest
    var operationURLResponse: NSHTTPURLResponse?
    
    // private
    private var operationData: NSMutableData?
    private var operationFileHandle: NSFileHandle?
    private var operationConnection: NSURLConnection?
    private var operationSavePath: String?
    private var operationRunLoop: CFRunLoop?
    private var state: HTTPRequestState
    private var success: HttpSuccessClosure
    private var failed: HttpFailedClosure
    private var requestPath: String! //  取消任务时使用
    private var operationProgressBlock: ProgressClosure
    
    #if TARGET_OS_IPHONE
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?
    #endif
    
    private var saveDataDispatchQueue: dispatch_queue_t!
    private var saveDataDispatchGroup: dispatch_group_t!
    private var timeoutTimer: NSTimer?
    private var expectedContentLength: Float?
    private var receivedContentLength: Float?
    private var ignoreHTTPSCertification: Bool
    
    // MARK: - --------------------System--------------------
    
    
    
    init(urlString: String,
         method: eHttpMethod,
         parameters: Dictionary<String,String>?,
         saveToPath: String?,
         progress: ProgressClosure,
         success: HttpSuccessClosure,
         failed:HttpFailedClosure,
         postAsJSON: Bool) {

        self.timeoutInterval = HTTPTimeoutInterval  // 超时时间
//        self.cachePolicy = cachePolicy
//        self.userAgent = userAgent
        
        self.success = success
        self.failed = failed
        self.operationProgressBlock = progress
        self.operationSavePath = saveToPath
        
        self.saveDataDispatchGroup = dispatch_group_create()
        self.saveDataDispatchQueue = dispatch_queue_create("com.bb.httpRequest", DISPATCH_QUEUE_SERIAL) // tongue队列
        
        // request
        let fullUrlString = urlString + "?platform=" + PLATFORM + "&version=" + VERSION
        let url = NSURL.init(string: fullUrlString)
        operationRequest = NSMutableURLRequest.init(URL: url!)
        
        // 是否是HTTPS连接
        if url?.scheme == "https" {
            self.ignoreHTTPSCertification = true
        } else {
            self.ignoreHTTPSCertification = false
        }
        
        var path = url?.path
        if ((path?.hasPrefix("/")) != nil) {
            path = path?.substringFromIndex(path!.startIndex.advancedBy(1))
        }
        // 存储用于取消任务的requestPath
        self.requestPath = path
        
        // pipeline all but POST and downloads
        if (method != .HttpMethodPOST) && (saveToPath == nil) {
            self.operationRequest.HTTPShouldUsePipelining = true
        }
        
        if method == .HttpMethodGET {
            self.operationRequest.HTTPMethod = "GET"
        }else if method == .HttpMethodPOST {
            self.operationRequest.HTTPMethod = "POST"
        }else if method == .HttpMethodPUT {
            self.operationRequest.HTTPMethod = "PUT"
        }
        
        self.state = .HTTPRequestStateReady
        self.sendParametersAsJSON = postAsJSON
        
        super.init()
        
        if parameters != nil {
            addParametersToRequest(parameters!)
        }
        DLog(parameters)
    }
    
    private func addParametersToRequest(paramsDict: Dictionary<String,String>) -> Void {
    
    }
    
    func setValue(value: String, HTTPHeaderField: String) -> Void {
        
    }
}
