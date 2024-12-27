#import <AVKit/AVKit.h>
#import "PIPController.h"
#import "SampleBufferVideoCallView.h"
#import <Masonry/Masonry.h>
@interface PIPController ()

@property(nonatomic, strong) AVPictureInPictureVideoCallViewController *pipCallViewController;
@property(nonatomic, strong) AVPictureInPictureControllerContentSource *contentSource;
@property(nonatomic, strong) AVPictureInPictureController *pipController;
@property(nonnull, nonatomic, strong) SampleBufferVideoCallView *sampleView;

@property(nonnull, nonatomic, strong) UIView *fallbackView;
@property(nonnull, nonatomic, strong) NSDictionary *options;
@property(nonnull, nonatomic, strong) UIView *customView;
@property(nonnull, nonatomic, strong) UITextView *textView;

@property(nonnull, nonatomic, strong) UITextView *tvTitle;
@property(nonnull, nonatomic, strong) UITextView *tvDescription;
@property(nonnull, nonatomic, strong) UITextView *tvContent;


@end

@implementation PIPController

- (instancetype)initWithSourceView:(UIView *)sourceView {

    if (self = [super init]) {
        self.sourceView = sourceView;
        self.customView = [[UIView alloc] init];
        
        self.customView.backgroundColor = [UIColor whiteColor];
        self.customView.autoresizesSubviews = YES;
        self.tvTitle = [[UITextView alloc] init];
        self.tvDescription = [[UITextView alloc] init];
        self.tvContent = [[UITextView alloc] init];
      
        self.tvTitle.textColor = [UIColor blackColor];
        self.tvTitle.font = [UIFont boldSystemFontOfSize:16];
        
        self.tvTitle.textAlignment = NSTextAlignmentCenter;
        self.tvTitle.userInteractionEnabled = NO;
        self.tvTitle.backgroundColor = [UIColor whiteColor];
        
        self.tvDescription.textColor = [UIColor blackColor];
        self.tvDescription.font = [UIFont boldSystemFontOfSize:16];
        self.tvDescription.textAlignment = NSTextAlignmentCenter;
        self.tvDescription.backgroundColor = [UIColor whiteColor];
        
        self.tvContent.textColor = [UIColor blackColor];
        self.tvContent.font = [UIFont boldSystemFontOfSize:16];
        
        self.tvContent.textAlignment = NSTextAlignmentCenter;
        self.tvContent.backgroundColor = [UIColor whiteColor];
        
        _fallbackView = [[UIView alloc] initWithFrame:CGRectZero];
        _fallbackView.translatesAutoresizingMaskIntoConstraints = false;
        
        SampleBufferVideoCallView * subview = [[SampleBufferVideoCallView alloc] initWithFrame:CGRectZero];
        _sampleView = subview;
        _sampleView.translatesAutoresizingMaskIntoConstraints = false;
        _pipCallViewController = [[AVPictureInPictureVideoCallViewController alloc] init];
        _pipCallViewController.view.backgroundColor = [UIColor whiteColor];
        [self addToCallViewController:_fallbackView];
        
        _contentSource = [[AVPictureInPictureControllerContentSource alloc] initWithActiveVideoCallSourceView:sourceView contentViewController:_pipCallViewController];
        
        _pipController = [[AVPictureInPictureController alloc] initWithContentSource:_contentSource];
        _pipController.canStartPictureInPictureAutomaticallyFromInline = YES;
        _pipController.delegate = self;

        [_pipController addObserver:self
                         forKeyPath:@"pictureInPictureActive"
                            options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew
                            context:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
    }
    
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if([keyPath isEqualToString:@"pictureInPictureActive"]) {
        _sampleView.shouldRender = [change[NSKeyValueChangeNewKey] boolValue];
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    if (_stopAutomatically) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self.pipController stopPictureInPicture];
        });
    }
}

- (void)addToCallViewController:(UIView *)view {
    [_pipCallViewController.view addSubview:view];

    NSArray *constraints = @[
        [view.leadingAnchor constraintEqualToAnchor:_pipCallViewController.view.leadingAnchor],
        [view.trailingAnchor constraintEqualToAnchor: _pipCallViewController.view.trailingAnchor],
        [view.topAnchor constraintEqualToAnchor: _pipCallViewController.view.topAnchor],
        [view.bottomAnchor constraintEqualToAnchor: _pipCallViewController.view.bottomAnchor]
    ];
   
    [NSLayoutConstraint activateConstraints:constraints];
    
}

- (void)addCustomViewToWindow {
    [self updateTextViewConstraints];
   
    if(_videoTrack){
        if(self.customView.superview){
            [self.customView removeFromSuperview];
        }
        return;
    }
    UIWindow *firstWindow = [UIApplication sharedApplication].windows.firstObject;
    [firstWindow addSubview:self.customView];
    [self.customView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(firstWindow);
        make.width.equalTo(firstWindow);
    }];
}

- (void)setVideoTrack:(RTCVideoTrack *)videoTrack {
    if (_videoTrack != videoTrack) {
        [_videoTrack removeRenderer:_sampleView];
    }
    
    _videoTrack = videoTrack;
    [videoTrack addRenderer:_sampleView];

    if (_videoTrack) {
        if (!_sampleView.superview) {
            [self addToCallViewController:_sampleView];
        }
        if (_fallbackView.superview) {
            [_fallbackView removeFromSuperview];
        }
        if (self.customView.superview) {
            [self.customView removeFromSuperview];
        }
        return;
    }
        
    if(_options){
        if(self.tvTitle.superview){
            [self.tvTitle removeFromSuperview];
        }
        if(self.tvDescription.superview){
            [self.tvDescription removeFromSuperview];
        }
        if(self.tvContent.superview){
            [self.tvContent removeFromSuperview];
        }
      
        if(self.tvTitle.text){
            [self.customView addSubview:self.tvTitle];
            [self.tvTitle mas_makeConstraints:^(MASConstraintMaker *make) {
                make.top.equalTo(self.customView).offset(4);
                make.left.right.equalTo(self.customView);
            }];
        }
        
        if(self.tvDescription.text){
            [self.customView addSubview:self.tvDescription];
            // Set up tvDescription constraints
            [self.tvDescription mas_makeConstraints:^(MASConstraintMaker *make) {
                make.top.equalTo(self.tvTitle.mas_bottom).offset(4);
                make.left.right.equalTo(self.customView);
            }];
        }
      
        if(self.tvContent.text){
            [self.customView addSubview:self.tvContent];
            // Set up tvContent constraints
            [self.tvContent mas_makeConstraints:^(MASConstraintMaker *make) {
                make.top.equalTo(self.tvDescription.mas_bottom).offset(10);
                make.left.right.equalTo(self.customView);
                make.bottom.lessThanOrEqualTo(self.customView).offset(-10);
            }];
        }
       
        if(self.pipController.isPictureInPictureActive){
            [self addCustomViewToWindow];
        }
        
        if (_sampleView.superview) {
            [_sampleView removeFromSuperview];
        }
        if (self.fallbackView.superview) {
            [self.fallbackView removeFromSuperview];
        }
        return;
    }
    //fallback component
    if (!_fallbackView.superview) {
        [self addToCallViewController:_fallbackView];
    }
    if (_sampleView.superview) {
        [_sampleView removeFromSuperview];
    }
    if (self.customView.superview) {
        [self.customView removeFromSuperview];
    }
}

- (void)insertFallbackView:(UIView *)view {
    [self.fallbackView addSubview:view];
}

- (void)setObjectFit:(RTCVideoViewObjectFit)fit {
    if (fit == RTCVideoViewObjectFitCover) {
        self.sampleView.sampleBufferLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    } else {
        self.sampleView.sampleBufferLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    }
}
- (void)setMirror:(BOOL)mirror {
    if(_sampleView){
        _sampleView.transform = CGAffineTransformMakeScale(-1.0, 1.0);
    }
}

- (CGSize)preferredSize {
    return _pipCallViewController.preferredContentSize;
}

- (void)setPreferredSize:(CGSize)size {
    if (!CGSizeEqualToSize(size, _pipCallViewController.preferredContentSize)) {
        _pipCallViewController.preferredContentSize = size;
        [_sampleView requestScaleRecalculation];
    }
}
- (void)updateTextViewConstraints {
    [self updateHeightOfTextView:self.tvTitle];
    [self updateHeightOfTextView:self.tvDescription];
    [self updateHeightOfTextView:self.tvContent];
}

- (void)updateHeightOfTextView:(UITextView *)textView {
    CGSize sizeThatFits = [textView sizeThatFits:CGSizeMake(textView.frame.size.width, CGFLOAT_MAX)];
    
    [textView mas_updateConstraints:^(MASConstraintMaker *make) {
        if (textView.text.length == 0) {
            make.height.equalTo(@0).priorityHigh();
        } else {
            make.height.equalTo(@(sizeThatFits.height)).priorityHigh();
        }
    }];
    
    [UIView animateWithDuration:0.2 animations:^{
        [self.customView layoutIfNeeded];
    }];
}


- (void)setExtraOptions:(NSDictionary*)options {
    
    _options = options;
    NSString *title = options[@"title"];
    NSString *description = options[@"description"];
    NSString *content = options[@"content"];
    NSString *color = options[@"color"];
    NSLog(@"title %@", title);
    NSLog(@"description %@", description);
    NSLog(@" b %@", content);
    
    if(title){
        self.tvTitle.text = title;
    }
    if(description){
        self.tvDescription.text = description;
    } else {
        self.tvDescription.text = @"";
    }
    if(content){
        self.tvContent.text = content;
        
        if([color  isEqual: @"red"]) {
            self.tvContent.textColor = [UIColor redColor];
        } else {
            self.tvContent.textColor = [UIColor blackColor];
        }
    } else {
        self.tvContent.text = @"";
    }
    [self updateTextViewConstraints];
}

- (BOOL)startAutomatically {
    return _pipController.canStartPictureInPictureAutomaticallyFromInline;
}

- (void)setStartAutomatically:(BOOL)value {
    _pipController.canStartPictureInPictureAutomaticallyFromInline = value;
}

- (void)togglePIP {
    if(_pipController.isPictureInPictureActive) {
        [_pipController stopPictureInPicture];
    } else if(_pipController.isPictureInPicturePossible){
        [_pipController startPictureInPicture];
    }
}

- (void)startPIP {
    if (_pipController.isPictureInPicturePossible) {
        [_pipController startPictureInPicture];
    }
}

- (void)stopPIP {
    if(_pipController.isPictureInPictureActive) {
        [_pipController stopPictureInPicture];
    }
}

- (void)dealloc {
    [_videoTrack removeRenderer:_sampleView];
    [_pipController removeObserver:self forKeyPath:@"pictureInPictureActive"];
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                            name:UIApplicationDidBecomeActiveNotification
                                          object:nil];
}

@end

@implementation PIPController (AVPictureInPictureControllerDelegate)


/*!
    @method        pictureInPictureControllerWillStartPictureInPicture:
    @param        pictureInPictureController
                The Picture in Picture controller.
    @abstract    Delegate can implement this method to be notified when Picture in Picture will start.
 */
- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    NSLog(@"%@", NSStringFromSelector(_cmd)); // Objective-C
    [self addCustomViewToWindow];
}

/*!
    @method        pictureInPictureControllerDidStartPictureInPicture:
    @param        pictureInPictureController
                The Picture in Picture controller.
    @abstract    Delegate can implement this method to be notified when Picture in Picture did start.
 */
- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    
    NSLog(@"%@", NSStringFromSelector(_cmd)); // Objective-C
   
    
    
}

/*!
    @method        pictureInPictureController:failedToStartPictureInPictureWithError:
    @param        pictureInPictureController
                The Picture in Picture controller.
    @param        error
                An error describing why it failed.
    @abstract    Delegate can implement this method to be notified when Picture in Picture failed to start.
 */
- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController failedToStartPictureInPictureWithError:(NSError *)error{
    
    NSLog(@"%@: %@", NSStringFromSelector(_cmd), [error localizedDescription]); // Objective-C
}

/*!
    @method        pictureInPictureControllerWillStopPictureInPicture:
    @param        pictureInPictureController
                The Picture in Picture controller.
    @abstract    Delegate can implement this method to be notified when Picture in Picture will stop.
 */
- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    
    NSLog(@"%@", NSStringFromSelector(_cmd)); // Objective-C
}

/*!
    @method        pictureInPictureControllerDidStopPictureInPicture:
    @param        pictureInPictureController
                The Picture in Picture controller.
    @abstract    Delegate can implement this method to be notified when Picture in Picture did stop.
 */
- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    
    NSLog(@"%@", NSStringFromSelector(_cmd)); // Objective-C
    // Get the PiP window's frame
    if(self.customView.superview){
        [self.customView removeFromSuperview];
    }
}

/*!
    @method        pictureInPictureController:restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:
    @param        pictureInPictureController
                The Picture in Picture controller.
    @param        completionHandler
                The completion handler the delegate needs to call after restore.
    @abstract    Delegate can implement this method to restore the user interface before Picture in Picture stops.
 */
- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
    
    NSLog(@"%@", NSStringFromSelector(_cmd)); // Objective-C
}


@end
