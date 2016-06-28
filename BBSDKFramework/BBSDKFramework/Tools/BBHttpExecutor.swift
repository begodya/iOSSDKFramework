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


private var HTTPTaskCount = 0
private var defaultUserAgent = "defaultUserAgent"

class BBHttpExecutor: NSOperation, NSURLConnectionDataDelegate {
    
    // public
    var userAgent: String?
    var sendParametersAsJSON: Bool
    var cachePolicy: NSURLRequestCachePolicy!
    var timeoutInterval: NSTimeInterval
    var operationRequest: NSMutableURLRequest
    var operationURLResponse: NSHTTPURLResponse?
    
    // private
    private var operationData: NSMutableData?
    private var operationFileHandle: NSFileHandle?
    private var operationConnection: NSURLConnection?
    private var operationSavePath: String?
    private var operationRunLoop: CFRunLoop?
    
    private var state: HTTPRequestState {
        get {
            return self.state
        }
        set (newValue) {
            self.willChangeValueForKey("state")
            self.state = newValue
            self.didChangeValueForKey("state")
        }
    }
    
    private var success: HttpSuccessClosure?
    private var failed: HttpFailedClosure?
    private var operationProgressBlock: ProgressClosure?
    private var requestPath: String! //  取消任务时使用
    
    #if TARGET_OS_IPHONE
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?
    #endif
    
    private var saveDataDispatchQueue: dispatch_queue_t!
    private var saveDataDispatchGroup: dispatch_group_t!
    private var timeoutTimer: NSTimer? {
        get {
            return self.timeoutTimer
        }
        set (newTimer) {
            if self.timeoutTimer != nil {
                self.timeoutTimer?.invalidate()
                self.timeoutTimer = nil
            }
            if newTimer != nil {
                self.timeoutTimer = newTimer
            }
        }
    }
    
    private var expectedContentLength: Int64?
    private var receivedContentLength: Int64?
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
        self.cachePolicy = NSURLRequestCachePolicy.init(rawValue: 0)  // 缓存策略 0: UseProtocolCachePolicy
//        self.userAgent 
        
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
        
        // 状态位
        self.sendParametersAsJSON = postAsJSON
        super.init()
        self.state = HTTPRequestState.HTTPRequestStateReady
        
        if parameters != nil {
            addParametersToRequest(parameters!)
        }
        DLog(parameters)
    }
    
    // MARK: NSOperation methods
    // MARK: Begins the execution of the operation.
    override func start() {
        // 开始请求连接
        autoreleasepool {
            if self.cancelled {
            finish()
            return
            }
        
            #if TARGET_OS_IPHONE
                // && !__has_feature(attribute_availability_app_extension)
                self.backgroundTaskIdentifier = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler{
                    if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
                    UIApplication.sharedApplication().endBackgroundTask = self.backgroundTaskIdentifier
                    self.backgroundTaskIdentifier = UIBackgroundTaskInvalid
                    }
                }
            #endif
            
            dispatch_async(dispatch_get_main_queue(), {
                self.increasePIRHTTPTaskCount()
            })
            
            // User-Agent
            if self.userAgent != nil {
                self.operationRequest.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")
            }else {
                self.operationRequest.setValue(defaultUserAgent, forHTTPHeaderField: "User-Agent")
            }
            
            // KVO 通知线程，任务执行
            self.willChangeValueForKey("isExecuting")
            self.state = .HTTPRequestStateExecuting
            self.didChangeValueForKey("isExecuting")
            
            if self.operationSavePath != nil {
                NSFileManager.defaultManager().createFileAtPath(self.operationSavePath!, contents: nil, attributes: nil)
                self.operationFileHandle = NSFileHandle.init(forWritingAtPath: self.operationSavePath!)
            }else {
                self.operationData = NSMutableData.init()
                self.timeoutTimer = NSTimer.scheduledTimerWithTimeInterval(self.timeoutInterval, target: self, selector: #selector(requestTimeout), userInfo: nil, repeats: false)
                self.operationRequest.timeoutInterval = self.timeoutInterval
            }
            
            self.operationRequest.cachePolicy = self.cachePolicy!
            self.operationConnection = NSURLConnection.init(request: self.operationRequest, delegate: self, startImmediately: false)
            
            // Runloop
            let currentQueue = NSOperationQueue.currentQueue()
            // 如果当前的队列不为空，并且不是主线程队列
            let inBackgroundAndInOperationQueue: Bool = (currentQueue != nil && currentQueue != NSOperationQueue.mainQueue())
            let targetRunloop = inBackgroundAndInOperationQueue ? NSRunLoop.currentRunLoop() : NSRunLoop.mainRunLoop()
            
            if self.operationSavePath != nil {
                self.operationConnection?.scheduleInRunLoop(targetRunloop, forMode: NSRunLoopCommonModes)
            } else {
                self.operationConnection?.scheduleInRunLoop(targetRunloop, forMode: NSDefaultRunLoopMode)
            }
            
            self.operationConnection?.start()
            DLog(self.operationRequest.allHTTPHeaderFields)
            DLog("\n" + "[" + self.operationRequest.HTTPMethod + "]" + "\n" + (self.operationRequest.URL?.absoluteString)!)
            
            if inBackgroundAndInOperationQueue {
                // 启动Runloop
                self.operationRunLoop = CFRunLoopGetCurrent()
                CFRunLoopRun()
            }
        }
    }
    
    @objc private func requestTimeout() -> Void {
//        NSURL *failingURL = self.operationRequest.URL;
//        
//        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
//        @"The operation timed out.", NSLocalizedDescriptionKey,
//        failingURL, NSURLErrorFailingURLErrorKey,
//        failingURL.absoluteString, NSURLErrorFailingURLStringErrorKey, nil];
//        
//        NSError *timeoutError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:userInfo];
//        [self connection:nil didFailWithError:timeoutError];

    }
    
    // MARK: A Boolean value indicating whether the operation is currently executing.
    override var executing: Bool {
        get {
            return self.state == HTTPRequestState.HTTPRequestStateExecuting
        }
    }
    
    //MARK: A Boolean value indicating whether the operation executes its task asynchronously.
    override var concurrent: Bool {
        get {
        return true
        }
    }
    
    // MARK: A Boolean value indicating whether the operation has finished executing its task.
    override var finished: Bool {
        get {
            return self.state == HTTPRequestState.HTTPRequestStateFinished
        }
    }
    
    
    // MARK: Private method, not part of NSOperation
    private func finish() -> Void {
        self.operationConnection?.cancel()
        self.operationConnection = nil
        decreasePIRHTTPTaskCount()
        
        #if TARGET_OS_IPHONE
            // && !__has_feature(attribute_availability_app_extension)
            if self.backgroundTaskIdentifier != UIBackgroundTaskInvalid {
                UIApplication.sharedApplication().endBackgroundTask(self.backgroundTaskIdentifier)
                self.backgroundTaskIdentifier = UIBackgroundTaskInvalid
            }
        #endif
        
        // KVO通知线程，任务状态改变
        self.willChangeValueForKey("isExecuting")
        self.willChangeValueForKey("isFinished")
        state = .HTTPRequestStateFinished
        self.didChangeValueForKey("isExcuting")
        self.didChangeValueForKey("isFinished")
    }
    
    // MARK: Advises the operation object that it should stop executing its task.
    override func cancel() {
        if !self.executing {
            return
        }
        super.cancel()
        self.timeoutTimer = nil
        self.finish()
    }
    
    // MARK: 是否开启状态栏网络连接状态
    private func increasePIRHTTPTaskCount() -> Void {
        HTTPTaskCount += 1
        toggleNetworkActivityIndicator()
    }
    
    private func decreasePIRHTTPTaskCount() -> Void {
        HTTPTaskCount =  HTTPTaskCount - 1 > 0 ? HTTPTaskCount - 1 : 0
        toggleNetworkActivityIndicator()
    }
    
    private func toggleNetworkActivityIndicator() -> Void {
        dispatch_async(dispatch_get_main_queue()) { 
            UIApplication.sharedApplication().networkActivityIndicatorVisible = HTTPTaskCount > 0
        }
    }
    
    // MARK: - --------------------功能函数--------------------
    // MARK: 初始化
    
    private func callCompletionClosureWith(response: AnyObject?, error: NSError?, isSuccess: Bool) -> Void {
        self.timeoutTimer = nil
//        var __success = isSuccess
        if self.operationRunLoop != nil {
            CFRunLoopStop(self.operationRunLoop)
        }
        
        dispatch_async(dispatch_get_main_queue()) { 
            var serviceError = error
            if serviceError != nil {
                if self.operationURLResponse?.statusCode == 500 {
//                    __success = false
                } else if self.operationURLResponse?.statusCode > 299 {
//                    __success = false
                }
            }
            
            if !isSuccess {
                if self.failed != nil && !self.cancelled {
                    DLog(response)
                    var message: String? = response?.objectForKey("message") as? String
                    let code: String? = response?.objectForKey("code") as? String
                    if message == nil || message?.characters.count == 0 {
                        message = "Unknown error!"
                    }
                    
                    var codeInt: Int?
                    if code == nil || code?.characters.count == 0 {
                        codeInt = -1
                    }else {
                        codeInt = Int(code!)
                    }
                    
                    serviceError = NSError.init(domain: message!, code:codeInt! , userInfo: response! as? [NSObject : AnyObject])
                    DLog(serviceError)
                    self.failed!(urlResponse: self.operationURLResponse!, error: serviceError!)
                }
            } else {
                if self.success != nil && !self.cancelled {
                    DLog(self.operationURLResponse)
                    self.success!(response: response!, urlResponse: self.operationURLResponse!)
                }
            }
            
            self.finish()
        }
        
    }
    
    // MARK: 添加参数到Request
    private func addParametersToRequest(paramsDict: Dictionary<String,String>) -> Void {
        let method = self.operationRequest.HTTPMethod
        
        if method == "POST" || method == "PUT" {
            if self.sendParametersAsJSON {
                // HTTP Header
                self.operationRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                do {
                    let jsonData = try NSJSONSerialization.dataWithJSONObject(paramsDict, options: NSJSONWritingOptions.init(rawValue: 0))
                    self.operationRequest.HTTPBody = jsonData
                } catch {
                    DLog("POST and PUT parameters must be provided as NSDictionary or NSArray when sendParametersAsJSON is set to YES.")
                }
            }else {
                var char = parameterStringFor(paramsDict).cStringUsingEncoding(NSUTF8StringEncoding)
                let strLen = String.fromCString(char!)?.characters.count
                let data = NSMutableData.init(bytes: &char, length: strLen!)
                self.operationRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                self.operationRequest.HTTPBody = data
            }
        } else {
            // GET
            var host = self.operationRequest.URL?.absoluteString
            if paramsDict.count > 0 {
                host = host! + "?" + parameterStringFor(paramsDict)
                self.operationRequest.URL = NSURL.init(string: host!)
            }
        }
    }
    
    private func parameterStringFor(parameters: Dictionary<String,String>) -> String {
        var array: Array<String> = []
        for (key,value) in parameters {
            array.append(key + "=" + value.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!)
        }
        if array.count > 0 {
            return array.joinWithSeparator("&")
        } else {
            return ""
        }
        
    }

    
    // MARK: - --------------------代理方法--------------------
    // MARK: - NSURLConnectionDataDelegate
    // MARK: 代理函数注释
    func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        self.expectedContentLength = response.expectedContentLength
        self.receivedContentLength = 0
        self.operationURLResponse = response as? NSHTTPURLResponse
    }
    
    func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        dispatch_group_async(self.saveDataDispatchGroup, self.saveDataDispatchQueue) {
            if self.operationSavePath != nil {
//                do {
                    self.operationFileHandle?.writeData(data)
//                } catch let exception as NSException {
//                    self.operationConnection?.cancel()
//                    let error = NSError.init(domain: "HTTPWriteError", code: 0, userInfo: exception.userInfo)
//                    self.callCompletionClosureWith(nil, error: error, success: false)
//                }
            } else {
                self.operationData?.appendData(data)
            }
        }
        
        if self.operationProgressBlock != nil {
            //If its -1 that means the header does not have the content size value
            if self.expectedContentLength != -1 {
                self.receivedContentLength = self.receivedContentLength! + data.length
//                self.operationProgressBlock(progress: self.receivedContentLength/self.expectedContentLength)
                self.operationProgressBlock?(progress: Float(self.receivedContentLength!)/Float(self.expectedContentLength!))
            } else {
                self.operationProgressBlock?(progress: -1)
            }
        }
    }
    
    func connection(connection: NSURLConnection, didSendBodyData bytesWritten: Int, totalBytesWritten: Int, totalBytesExpectedToWrite: Int) {
        // 上传进度
        if self.operationProgressBlock != nil && self.operationRequest.HTTPMethod == "POST" {
            self.operationProgressBlock!(progress: Float(totalBytesWritten)/Float(totalBytesExpectedToWrite))
        }
    }
    
    func connectionDidFinishLoading(connection: NSURLConnection) {
        dispatch_group_notify(self.saveDataDispatchGroup, self.saveDataDispatchQueue) {
            
            var responseData: NSData?
            var response: AnyObject?
            var error: NSError?
            
            if let data = self.operationData {
                responseData = NSData.init(data: data)
            }
            
            if self.operationURLResponse?.MIMEType == "application/json" {
                if self.operationData != nil && self.operationData?.length > 0 {
                    do {
                        let dic = try NSJSONSerialization.JSONObjectWithData(responseData!, options: NSJSONReadingOptions.init(rawValue: 2)) as? NSDictionary
                        
                        if dic != nil {
                            response = dic
                        }
                    } catch let er as NSError {
                          error = er
                    }
                }
            } else if self.operationURLResponse?.MIMEType == "text/xml" {
                // 暂未完成
            }
            
            self.callCompletionClosureWith(response, error: error, isSuccess: true)
        }
    }
    
    func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        self.callCompletionClosureWith(nil, error: error, isSuccess: false)
    }
    
    // MARK: NSURLConnection for https 服务器端单项HTTPS验证
    func connection(connection: NSURLConnection, canAuthenticateAgainstProtectionSpace protectionSpace: NSURLProtectionSpace) -> Bool {
        if self.ignoreHTTPSCertification {
            return protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust;
        }else {
            return false
        }
    }
    
    func connection(connection: NSURLConnection, didReceiveAuthenticationChallenge challenge: NSURLAuthenticationChallenge) {
        if  self.ignoreHTTPSCertification {
            if challenge.previousFailureCount == 0 {
             let credential = NSURLCredential.init(trust: challenge.protectionSpace.serverTrust!)
                challenge.sender?.useCredential(credential, forAuthenticationChallenge: challenge)
            } else {
                challenge.sender?.cancelAuthenticationChallenge(challenge)
            }
        }
    }
    
    // MARK: - --------------------接口API--------------------
    // MARK: 设置HTTP Header Fields
    func setValue(value: String, HTTPHeaderField: String) -> Void {
        
    }
}
