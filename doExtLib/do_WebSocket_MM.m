//
//  do_WebSocket_MM.m
//  DoExt_MM
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import "do_WebSocket_MM.h"

#import "doScriptEngineHelper.h"
#import "doIScriptEngine.h"
#import "doInvokeResult.h"
#import "SRWebSocket.h"
#import "doJsonHelper.h"
#import "doIOHelper.h"

@interface do_WebSocket_MM()<SRWebSocketDelegate>
{
    SRWebSocket *webSocket;
    NSString *_callbackName;
    id<doIScriptEngine> _scritEngine;
    doInvokeResult *_invokeResult;
}

@end

@implementation do_WebSocket_MM

#pragma mark - 注册属性（--属性定义--）
/*
 [self RegistProperty:[[doProperty alloc]init:@"属性名" :属性类型 :@"默认值" : BOOL:是否支持代码修改属性]];
 */
-(void)OnInit
{
    [super OnInit];
    //注册属性
}

//销毁所有的全局对象
-(void)Dispose
{
    //(self)类销毁时会调用递归调用该方法，在该类中主动生成的非原生的扩展对象需要主动调该方法使其销毁
}
#pragma mark -
#pragma mark - 同步异步方法的实现
//同步
- (void)close:(NSArray *)parms
{
    _invokeResult = [parms objectAtIndex:2];
    //_invokeResult设置返回值
    [webSocket close];
}
//异步
- (void)connect:(NSArray *)parms
{
    //异步耗时操作，但是不需要启动线程，框架会自动加载一个后台线程处理这个函数
    NSDictionary *_dictParas = [parms objectAtIndex:0];
    //参数字典_dictParas
    _scritEngine = [parms objectAtIndex:1];
    //自己的代码实现
    
    _callbackName = [parms objectAtIndex:2];
    NSString *url = [doJsonHelper GetOneText:_dictParas :@"url" :@""];
    
    webSocket = [[SRWebSocket alloc]initWithURL:[NSURL URLWithString:url]];
    webSocket.delegate = self;
    [webSocket open];
    
}
- (void)send:(NSArray *)parms
{
    //异步耗时操作，但是不需要启动线程，框架会自动加载一个后台线程处理这个函数
    NSDictionary *_dictParas = [parms objectAtIndex:0];
    //参数字典_dictParas
    _scritEngine = [parms objectAtIndex:1];
    //自己的代码实现
    
    _callbackName = [parms objectAtIndex:2];
    //回调函数名_callbackName
    
    NSString *type = [doJsonHelper GetOneText:_dictParas :@"type" :@""];
    NSString *content = [doJsonHelper GetOneText:_dictParas :@"content" :@""];
    NSData *contentData;
    //发送文件和发送文本分开
    if ([[type lowercaseString] isEqualToString:@"file"]) {
        NSString *filePath = [doIOHelper GetLocalFileFullPath:_scritEngine.CurrentApp :content];
        contentData  = [NSData dataWithContentsOfFile:filePath];
        [webSocket send:contentData];
    }
    else if ([[type lowercaseString] isEqualToString:@"utf-8"])
    {
        [webSocket sendString:content withEncode:NSUTF8StringEncoding];
    }
    else if([[type lowercaseString] isEqualToString:@"gbk"])
    {
         NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
        [webSocket sendString:content withEncode:enc];
    }
    else if ([[type lowercaseString] isEqualToString:@"hex"])
    {
        contentData = [self convertHexStrToData:content];
        [webSocket send:contentData];
    }
}
- (NSData *)convertHexStrToData:(NSString *)str {
    if (!str || [str length] == 0) {
        return nil;
    }
    
    NSMutableData *hexData = [[NSMutableData alloc] initWithCapacity:8];
    NSRange range;
    if ([str length] % 2 == 0) {
        range = NSMakeRange(0, 2);
    } else {
        range = NSMakeRange(0, 1);
    }
    for (NSInteger i = range.location; i < [str length]; i += 2) {
        unsigned int anInt;
        NSString *hexCharStr = [str substringWithRange:range];
        NSScanner *scanner = [[NSScanner alloc] initWithString:hexCharStr];
        
        [scanner scanHexInt:&anInt];
        NSData *entity = [[NSData alloc] initWithBytes:&anInt length:1];
        [hexData appendData:entity];
        
        range.location += range.length;
        range.length = 2;
    }
    return hexData;
}
//得到二进制字符串
-(NSString *)getHexStr:(NSData *)data
{
    Byte *testByte = (Byte *)[data bytes];
    NSString *hexStr=@"";
    for(int i=0;i<[data length];i++)
    {
        NSString *newHexStr = [NSString stringWithFormat:@"%x",testByte[i]&0xff];///16进制数
        if([newHexStr length]==1)
        {
            hexStr = [NSString stringWithFormat:@"%@0%@",hexStr,newHexStr];
        }
        else
        {
            hexStr = [NSString stringWithFormat:@"%@%@",hexStr,newHexStr];
        }
    }
    NSLog(@"bytes 的16进制数为:%@",hexStr);
    return hexStr;
}
#pragma mark -  代理方法
-(void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    doInvokeResult *invokeResult = [[doInvokeResult alloc] init];
    [invokeResult SetResultBoolean:YES];
    [_scritEngine Callback:_callbackName :invokeResult];
}
- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    doInvokeResult *invokeResult = [[doInvokeResult alloc]init];
    NSMutableDictionary *node = [NSMutableDictionary dictionary];
    [node setObject:error.description forKey:@"msg"];
    [invokeResult SetResultNode:node];
    [self.EventCenter FireEvent:@"error" :invokeResult];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    [_invokeResult SetResultBoolean:YES];
}
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    doInvokeResult *invokeResult = [[doInvokeResult alloc]init];
    if ([message isKindOfClass:[NSString class]]) {
        [invokeResult SetResultValue:[self getHexStr:[message dataUsingEncoding:NSUTF8StringEncoding]]];
    }
    else
    {
        [invokeResult SetResultValue:[self getHexStr:message]];
    }
    [self.EventCenter FireEvent:@"receive" :invokeResult];
}
@end
