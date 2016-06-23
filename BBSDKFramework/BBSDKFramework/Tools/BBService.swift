//
//  BBService.swift
//  BBSDKFramework
//
//  Created by 饶骏华 on 16/6/22.
//  Copyright © 2016年 Begodya. All rights reserved.
//

import UIKit

typealias SuccessClosure = (response: AnyObject) -> Void
typealias FailedClosure =  (error: NSError) -> Void

/*
 * API TYPE
 */
public enum eAPI_TYPE {
    case eAPI_TYPE_GET_URL
    case eAPI_TYPE_POST_URL
}

/* 
 * HTTP METHOD
 */
private let HTTP_METHOD_POST = "POST"              // POST
private let HTTP_METHOD_POST_JSON = "POST_JSON"    // POST_JSON
private let HTTP_METHOD_PUT = "PUT"                 // PUT
private let HTTP_METHOD_GET = "GET"                 // GET


/* 
 * API URL
 */
private let getUrl: String = "/common_api_cn/v1/query/all_provinces"
private let postUrl: String = "/user_api_cn/v1/user/user_info"

/*
 * KEY FOR DIC
 */
private let HTTP_HOST = "host"
private let HTTP_PATH = "path"
private let HTTP_METHOD = "method"
private let RESULT_MODEL = "resultModel"


class BBService: NSObject {

    // MARK: - --------------------接口API--------------------
    
    /*
     * 调用服务统一接口
     * eAPI_TYPE为对应节点
     * BBRequestModel为请求数据模型
     * SuccessClosure请求成功回调
     * FailedClosure请求失败回调
     * attribute --> key(show_alert,show_loading) : value(0:show 1:not default:0)
     */
    class func serviceSendWithApiType(apiType: eAPI_TYPE!,
                                      requestModel: BBRequestModel?,
                                      succsee: SuccessClosure,
                                      failed: FailedClosure,
                                      attribute: Dictionary<String,String>?) -> Void {
        // UI
        if attribute != nil {
            if (attribute!["show_loading"] == "1") ? false : true {
                dispatch_async(dispatch_get_main_queue(), { 
                    let showMessage = attribute!["show_message"]
                    if showMessage != nil && showMessage?.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0 {
                        // loding
                    }else {
                    
                    }
                })
            }
        }
        
        // 子线程发送服务
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            var param: Dictionary<String,String>? = BBRequestModel.getDictionaryByObject(requestModel)
            setRequestHeader(&param)
            let pathAndMethod: Dictionary<String,String>! = getPathAndMethodByType(apiType, requestModel: requestModel)
            let hostType: Int! = Int(pathAndMethod[HTTP_HOST]!)   
            let type: eHTTP_CLIENT! = eHTTP_CLIENT(rawValue: hostType)
            let path: String! = pathAndMethod[HTTP_PATH]
            let method: String! = pathAndMethod[HTTP_METHOD]
            switch method {
            case HTTP_METHOD_POST:
                BBHttpClient.sharedInstanceWithClientType(type)
                break
            case HTTP_METHOD_POST_JSON:
                
                break
            case HTTP_METHOD_GET:
                
                break
            case HTTP_METHOD_PUT:
                
                break
            default:
                break
            }
        }
    }
    
     // MARK: - --------------------功能函数--------------------
    
    private class func setRequestHeader(inout param: Dictionary<String,String>?) {
        param?.updateValue(BBDataSource.shareInstance.version!, forKey: "version")
        param?.updateValue(BBDataSource.shareInstance.platform!, forKey: "platform")
    }
    
    private class func getPathAndMethodByType(apiType: eAPI_TYPE, requestModel: BBRequestModel?) -> Dictionary<String,String>!  {
        var result: Dictionary<String,String>! = Dictionary<String,String>()
        switch apiType {
        case eAPI_TYPE.eAPI_TYPE_GET_URL:
            result = ["1":HTTP_HOST,
                      postUrl:HTTP_PATH,
                      HTTP_METHOD_POST_JSON:HTTP_METHOD,
                      "":RESULT_MODEL]
            break
        case eAPI_TYPE.eAPI_TYPE_POST_URL:
            result = ["1":HTTP_HOST,
                      getUrl:HTTP_PATH,
                      HTTP_METHOD_GET:HTTP_METHOD,
                      "":RESULT_MODEL]
            break
        }
        return result
    }
}
