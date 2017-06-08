//
//  ViewController.m
//  视频动画测试
//
//  Created by DFD on 2017/5/31.
//  Copyright © 2017年 DFD. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>


#if 1

    #define NSLog(...) NSLog(__VA_ARGS__)
#else

    #define NSLog(...) {}

#endif


@interface ViewController (){
    AVPlayer *player;
}

@property (nonatomic, strong) UILabel                *timerLabel;
@property (nonatomic, strong) UILabel                *animationLabel;


@property (nonatomic, strong) NSTimer                *timer;

@property (nonatomic, strong) NSDate                 *dateForCheck; // 开始播放的时间

@property (nonatomic, strong) NSDate                 *dateForPause; // 开始播放的时间

@property (nonatomic, assign) NSInteger              repairInterval;// 错位的时间  单位 ms

@property (nonatomic, assign) NSTimeInterval         playTime;      // 当前播放的时间   单位 s

@property (nonatomic, assign) BOOL                   isPlaying;      // 当前是否正在播放

/* 字幕标示 */
@property (nonatomic, strong) UIView                 *subtitleView;

@property (nonatomic, copy) NSArray                  *arraySubtitle;  // 字幕数据

@property (nonatomic, assign) int                    animationOffest; // 下一个运行动画的索引行，  需要乘3

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setSubtitleView];
    
    
    self.timerLabel = [[UILabel alloc] initWithFrame:CGRectMake(100, 175, 150, 21)];
    [self.view addSubview:self.timerLabel];
    
    self.animationLabel = [[UILabel alloc] initWithFrame:CGRectMake(100, 150, 150, 21)];
    [self.view addSubview:self.animationLabel];
    
    
    NSData *data = [self getDataFromDocumentOrBundle:@"22.json"];

    NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    
    self.arraySubtitle = array;

    
    //   1 创建要播放的元素
    
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"222.mp4" withExtension:nil];
    //    playerItemWithAsset:通过设备相册里面的内容 创建一个 要播放的对象    我们这里直接选择使用URL读取
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    
    
    //2  创建播放器
    player = [AVPlayer playerWithPlayerItem:item];
    //也可以直接WithURL来获得一个地址的视频文件
    //    externalPlaybackVideoGravity    视频播放的样式
    //AVLayerVideoGravityResizeAspect   普通的
    //    AVLayerVideoGravityResizeAspectFill   充满的
    //    currentItem  获得当前播放的视频元素
    
    //    3  创建视频显示的图层
    AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:player];
    layer.frame = self.view.frame;
    // 显示播放视频的视图层要添加到self.view的视图层上面
    [self.view.layer addSublayer:layer];
}

- (void)setRepairInterval:(NSInteger)repairInterval{
    if (_repairInterval != repairInterval) {
        static BOOL isFirstSetRepairInterval = YES;
        if (isFirstSetRepairInterval) {
            isFirstSetRepairInterval = NO;
        }else {
            _repairInterval = repairInterval;
        }
    }
}




- (IBAction)beginPlay {
    
    
    //最后一步开始播放
    [player play];
    
    
    // 4867
    if (!self.dateForCheck) {
        self.dateForCheck = [NSDate date];
    }
    self.isPlaying = YES;
    
    if (!self.timer) {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(timerRunLoop) userInfo:nil repeats:YES];
    }else{
        // 重新设置 dateForCheck， 把暂停的这段时间减去
        NSTimeInterval interval = [self.dateForPause timeIntervalSinceNow];
        NSLog(@"暂停了 %@ ", @(0 - interval));
        self.dateForCheck = [NSDate dateWithTimeInterval:0 - interval sinceDate:self.dateForCheck];
        [self.timer setFireDate:[NSDate distantPast]];
    }
    
    [self runloopAnimation];
}

- (IBAction)pausePlay {
    
    //最后一步开始播放
    [player pause];
    // 暂停
    [self.timer setFireDate:[NSDate distantFuture]];
    self.isPlaying = NO;
    
    self.dateForPause = [NSDate date];
}


- (void)timerRunLoop {
    self.playTime = 0 - [self.dateForCheck timeIntervalSinceNow];
    self.timerLabel.text = [NSString stringWithFormat:@"%.3f", self.playTime];
}


- (void)runloopAnimation{
    
    if (!self.isPlaying) {
        return;
    }
    
    if (self.animationOffest * 3 >= self.arraySubtitle.count) {
        return;
    }
    
    
    NSArray *array = [self.arraySubtitle subarrayWithRange:NSMakeRange(self.animationOffest * 3, 3)];
    
    int begin;  // 第一条指令的开始时间
    int end;    // 第一条指令的结束时间
    int duration;   // 第一条指令持续时间
    int direction;  // 第一条指令的方向    0:伸  1：缩
    
    begin = [array[0] intValue];
    end = [array[1] intValue];
    duration = end - begin;
    direction = [array[2] intValue];
    
    // 先执行动作，然后在 延迟直到下次播放
    void  (^animationAndHandleSet)() = ^{
        self.animationLabel.text = [NSString stringWithFormat:@"%.3f - %.3f", begin / 1000.0, end / 1000.0];
        
        // 动画
        [self beginAnimation:begin end:end isAll:direction];
        
        if (self.animationOffest * 3 + 4 < self.arraySubtitle.count) {
            int nextBegin = [self.arraySubtitle[self.animationOffest * 3 + 3] intValue];
            int interval = nextBegin - begin - (int)self.repairInterval;
            NSLog(@"这次运动开始时间:%d, 下次运动开始时间:%d  间隔:%d 毫秒", begin, nextBegin, interval);
            interval = interval < 0 ? 0 : interval;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, interval / 1000.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self runloopAnimation];
            });
        }
        
        self.animationOffest++;
    };
    
    self.repairInterval = (0 - [self.dateForCheck timeIntervalSinceNow]) * 1000 - begin;
    
    // 播放时间与动作开始时间的间隔
    NSTimeInterval interval = begin / 1000.0 - self.playTime;
    NSLog(@"与视频的播放进度的间隔是:%@ 秒", @(interval));
    if (interval > 0) {
        if (interval > 1) {     // 这里主要是针对第一个动作
            interval -= 0.5;
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(interval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            animationAndHandleSet();
        });
    }else{
        animationAndHandleSet();
    }
}



- (void)setSubtitleView{
    
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(100, 100, 150, 10)];
    view.backgroundColor = [UIColor blueColor];
    [self.view addSubview:view];
    self.subtitleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 10)];
    self.subtitleView.backgroundColor = [UIColor redColor];
    [view addSubview:self.subtitleView];
}

- (void)beginAnimation:(int)begin end:(int)end isAll:(BOOL)isAll{
    
    double time = (end - begin) / 1000.0;
    
    NSLog(@"开始动画时间:%d,结束动画时间:%d, 动画时长:%d, 动画方向:%@, 当前时间 %.0f, 已经错位了 %@ 毫秒", begin, end, (end - begin), @(isAll), (0 - [self.dateForCheck timeIntervalSinceNow]) * 1000, @(self.repairInterval));
    
    
    self.repairInterval = (0 - [self.dateForCheck timeIntervalSinceNow]) * 1000 - begin;
    
    CABasicAnimation *boundsAnim = [CABasicAnimation animationWithKeyPath:@"bounds"];
    
    CGRect emptyRect = CGRectMake(0, 0, 0, 10);
    CGRect allRect = CGRectMake(0, 0, 150, 10);
    
    if(isAll){
        boundsAnim.fromValue = [NSValue valueWithCGRect:emptyRect];
        boundsAnim.toValue = [NSValue valueWithCGRect:allRect];
    }else {
        boundsAnim.fromValue = [NSValue valueWithCGRect:allRect];
        boundsAnim.toValue = [NSValue valueWithCGRect:emptyRect];
    }
    
    boundsAnim.duration = time;
    
    boundsAnim.removedOnCompletion = NO;
    boundsAnim.fillMode = kCAFillModeForwards;
    [self.subtitleView.layer addAnimation:boundsAnim forKey:nil];
    
    CABasicAnimation *positionAnim = [CABasicAnimation animationWithKeyPath:@"anchorPoint"];
    
    CGPoint emptyPositon = CGPointMake(0, 1);
    CGPoint allPositon = CGPointMake(0, 1);
    
    positionAnim.fromValue = [NSValue valueWithCGPoint:emptyPositon];
    positionAnim.toValue = [NSValue valueWithCGPoint:allPositon];
    positionAnim.duration = (double)time;
    
    positionAnim.removedOnCompletion = NO;
    positionAnim.fillMode = kCAFillModeForwards;
    [self.subtitleView.layer addAnimation:positionAnim forKey:nil]; 
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


/// 从document 中获取文件，如果没有，从工程中获取，如果没有返回nil
- (NSData *)getDataFromDocumentOrBundle:(NSString *)str{
    
    NSString *dir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
    NSString *path = [NSString stringWithFormat:@"%@/%@", dir, str];
    NSURL *URL = [NSURL fileURLWithPath:path];
    NSData *data = [NSData dataWithContentsOfURL:URL];
    if (data == nil) {
        path = [[NSBundle mainBundle] pathForResource:str ofType:nil];
        URL = [NSURL fileURLWithPath:path];
        data = [NSData dataWithContentsOfURL:URL];
    }
    return  data;
}

@end
