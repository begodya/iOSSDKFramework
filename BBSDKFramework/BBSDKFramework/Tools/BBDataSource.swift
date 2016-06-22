//
//  BBDataSource.swift
//  BBSDKFramework
//
//  Created by 饶骏华 on 16/6/22.
//  Copyright © 2016年 Begodya. All rights reserved.
//

import Foundation

class BBDataSource: NSObject {
    var version: String?
    var platform: String?
    var deviceToken: String?
    
    // MARK: - --------------------System--------------------
    
    // MARK: Singleton(结构体方法初始化)
//    class var shareInstance : BBDataSource {
//        struct Static {
//            static let instance = BBDataSource()
//        }
//        return Static.instance
//    }
    
    // MARK: Singleton
    static let shareInstance = BBDataSource()

    private override init() {
        
    }
  
    // 初始化
    class func initDataSource() {
        self.shareInstance.version = "1.0"
        self.shareInstance.platform = ""
    }
    
    // MARK: - --------------------功能函数--------------------
    // MARK: 初始化
    
    // MARK: - --------------------手势事件--------------------
    // MARK: 各种手势处理函数注释
    
    // MARK: - --------------------按钮事件--------------------
    // MARK: 按钮点击函数注释
    
    // MARK: - --------------------代理方法--------------------
    // MARK: - 代理种类注释
    // MARK: 代理函数注释
    
    // MARK: - --------------------属性相关--------------------
    // MARK: 属性操作函数注释
    
    // MARK: - --------------------接口API--------------------
    // MARK: 分块内接口函数注释
}