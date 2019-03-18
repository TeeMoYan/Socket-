//
//  ViewController.m
//  TM_Socket
//
//  Created by 闫振 on 2019/3/18.
//  Copyright © 2019 TeeMo. All rights reserved.
//

#import "ViewController.h"
#import <GCDAsyncSocket.h>

typedef NS_ENUM(NSUInteger, TMCommandType) {
    TMCommandTypeImg     =  1,
    TMCommandTypeText    =  2,
    TMCommandTypeVideo   =  3,
};
@interface ViewController ()<GCDAsyncSocketDelegate>


@property (nonatomic, strong) GCDAsyncSocket *mSocket;
@property (nonatomic, strong) NSMutableData  *mData;
@property (nonatomic, assign) unsigned int mTotalSize;
@property (nonatomic, assign) unsigned int mCurrentCommandId;
@property (nonatomic,assign)TMCommandType mType;
@property (weak, nonatomic) IBOutlet UITextField *mTextField;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}
- (IBAction)connectSocket:(UIButton *)sender {
    
    if (self.mSocket == nil) {
        self.mSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(0, 0)];
    }
    if (!self.mSocket.isConnected) {
        NSError *error;
        [self.mSocket connectToHost:@"127.0.0.1" onPort:8060 withTimeout:-1 error:&error];
        if (error) NSLog(@"%@",error);
    }
    
}
- (IBAction)sendImg:(UIButton *)sender {
    
    UIImage *image = [UIImage imageNamed:@"img.jpg"];
    NSData  *imageData  = UIImagePNGRepresentation(image);
    [self sendData:imageData type:(TMCommandTypeImg)];
}
- (IBAction)scendVideo:(UIButton *)sender {
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"video.mp4" ofType:nil];
    NSData *data  = [NSData dataWithContentsOfFile:path];
    [self sendData:data type:TMCommandTypeVideo];
    
}
- (IBAction)sendText:(UIButton *)sender {
    NSData *data = [_mTextField.text dataUsingEncoding:(NSUTF8StringEncoding)];
    [self sendData:data type:TMCommandTypeText];
}

- (void)sendData:(NSData *)data type:(TMCommandType)type{
    
    NSMutableData *mData = [NSMutableData data];
    // 计算数据总长度 data
    unsigned int dataLength = 4+4+(int)data.length;
    NSData *lengthData = [NSData dataWithBytes:&dataLength length:4];
    [mData appendData:lengthData];
    
    // 数据类型 data
    // 2.拼接指令类型(4~7:指令)
    NSData *typeData = [NSData dataWithBytes:&type length:4];
    [mData appendData:typeData];
    
    // 最后拼接数据
    [mData appendData:data];
    
    NSLog(@"发送数据的总字节大小:%ld",mData.length);
    
    // 发数据
    [self.mSocket writeData:mData withTimeout:-1 tag:10086];
    
}


#pragma mark - GCDAsyncSocketDelegate

//已经连接到服务器
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(nonnull NSString *)host port:(uint16_t)port{
    
    NSLog(@"连接成功 : %@---%d",host,port);
    [self.mSocket readDataWithTimeout:-1 tag:10086];
}

// 连接断开
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err{
    NSLog(@"断开 socket连接 原因:%@",err);
}

//已经接收服务器返回来的数据
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    NSLog(@"接收到tag = %ld : %ld 长度的数据",tag,data.length);
    
    if (data.length == 0) {
        NSLog(@"传输数据长度为: 0");
        return;
    }
    /**
     *  解析服务器返回的数据
     */
    // 1.第一次接收数据
    if(self.mData.length == 0){
        // 获取总的数据包大小
        NSData *totalSizeData = [data subdataWithRange:NSMakeRange(0, 4)];
        unsigned int totalSize = 0;
        //读取前四个字节
        [totalSizeData getBytes:&totalSize length:4];
        NSLog(@"接收总数据的大小 %u",totalSize);
        self.mTotalSize = totalSize;
        
        // 获取指令类型
        NSData *commandIdData = [data subdataWithRange:NSMakeRange(4, 4)];
        unsigned int commandId = 0;
        [commandIdData getBytes:&commandId length:4];
        self.mCurrentCommandId = commandId;
    }
    
    [self.mData appendData:data];
    
    if (self.mData.length == self.mTotalSize) {
        
        NSData *imgData = [self.mData subdataWithRange:NSMakeRange(8, self.mData.length - 8)];
        
        //丢包的现象
        NSLog(@"数据已经接收完成");
        if (self.mCurrentCommandId == TMCommandTypeImg) {
            NSLog(@"接收到图片");
            [self saveImage:imgData];
            
        }else if  (self.mCurrentCommandId == TMCommandTypeVideo){
            NSLog(@"接收到视频");
            self.mData = [NSMutableData data];
            
        }else if  (self.mCurrentCommandId == TMCommandTypeText){
            NSLog(@"接收到文本");
            self.mData = [NSMutableData data];
            
        }
        // 清除数据
        self.mData = [NSMutableData data];
        
    };
    
    [self.mSocket readDataWithTimeout:-1 tag:10086];
    
    
}
-(NSMutableData *)mData{
    if (!_mData) {
        _mData = [NSMutableData data];
    }
    return _mData;
}


-(void)saveImage:(NSData *)imgData{
    
    UIImage *acceptImage = [UIImage imageWithData:imgData];
    UIImageWriteToSavedPhotosAlbum(acceptImage, self, @selector(savedPhotoImage:didFinishSavingWithError:contextInfo:), nil);
    
}

//保存完成后调用的方法
- (void)savedPhotoImage:(UIImage*)image didFinishSavingWithError: (NSError *)error contextInfo: (void *)contextInfo {
    if (error) {
        NSLog(@"保存图片出错%@", error.localizedDescription);
    }else {
        NSLog(@"保存图片成功");
    }
}
//消息发送成功 代理函数 向服务器 发送消息
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag{
    NSLog(@"%ld 的发送数据成功",tag);
    
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
