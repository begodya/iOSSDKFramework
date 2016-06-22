//
//  BBConfig.swift
//  BBSDKFramework
//
//  Created by 饶骏华 on 16/6/22.
//  Copyright © 2016年 Begodya. All rights reserved.
//

import Foundation

// 调试输出语句，默认debug模式下自动打开，release模式下默认关闭
func DLog<T>(message: T, fileName: String = #file, methodName: String =  #function, lineNumber: Int = #line)
{
    #if DEBUG
        let str : String = (fileName as NSString).pathComponents.last!.stringByReplacingOccurrencesOfString("swift", withString: "")
        print("\(str)\(methodName)[\(lineNumber)]:\(message)")
    #endif
}