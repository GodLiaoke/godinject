//
//  main.m — GOD 注入器
//  视觉：Phoenix Ember（不死鸟·烈焰红）
//  沙盒访问基于 worse_query（WQAccess），不需要越狱
//

#import <UIKit/UIKit.h>
#import <sys/stat.h>
#import "WQAccess.h"

#pragma mark - 常量

static NSString *const kGameBundleID = @"com.tencent.tmgp.dfm";
static NSString *const kServerBase   = @"https://ios.ouovo.cc";
static NSString *const kDownloadPath = @"/api/god/download";

#pragma mark - 设计令牌（Palette B · Phoenix Ember）

static UIColor *C_BASE(void)   { return [UIColor colorWithRed:0.039 green:0.020 blue:0.031 alpha:1]; } // #0a0508
static UIColor *C_SURFACE(void){ return [UIColor colorWithRed:0.094 green:0.039 blue:0.055 alpha:1]; } // #180a0e
static UIColor *C_SURF2(void)  { return [UIColor colorWithRed:0.063 green:0.024 blue:0.035 alpha:1]; } // #100609
static UIColor *C_TEXT(void)   { return [UIColor colorWithRed:1.000 green:0.945 blue:0.937 alpha:1]; } // #fff1ef
static UIColor *C_MUTED(void)  { return [UIColor colorWithRed:0.722 green:0.604 blue:0.600 alpha:1]; } // #b89a99
static UIColor *C_ACCENT(void) { return [UIColor colorWithRed:1.000 green:0.231 blue:0.188 alpha:1]; } // #ff3b30
static UIColor *C_GOOD(void)   { return [UIColor colorWithRed:0.184 green:0.824 blue:0.541 alpha:1]; } // #2fd28a
static UIColor *C_WARN(void)   { return [UIColor colorWithRed:1.000 green:0.722 blue:0.302 alpha:1]; } // #ffb84d
static UIColor *C_BAD(void)    { return [UIColor colorWithRed:1.000 green:0.420 blue:0.561 alpha:1]; } // #ff6b8f

// 间距档位
static const CGFloat S1 = 4.0;
static const CGFloat S2 = 8.0;
static const CGFloat S3 = 16.0;
static const CGFloat S4 = 24.0;
static const CGFloat S5 = 32.0;
static const CGFloat ROW_H = 52.0;
static const CGFloat RADIUS = 12.0;

// 细分隔线 / 描边
static UIColor *C_LINE(void)  { return [C_MUTED() colorWithAlphaComponent:0.16]; }
static UIColor *C_LINE2(void) { return [C_MUTED() colorWithAlphaComponent:0.28]; }

#pragma mark - 扫描回调

static BOOL GODConfirmScan(NSString *what, int64_t ids, double seconds) {
    (void)what; (void)ids; (void)seconds;
    return YES;
}
static void GODScanProgress(int64_t done, int64_t total, BOOL finished) {
    (void)done; (void)total; (void)finished;
}

#pragma mark - 面板容器

@interface GODPanel : UIView
@end

@implementation GODPanel
- (instancetype)init {
    if ((self = [super init])) {
        self.backgroundColor = C_SURFACE();
        self.layer.cornerRadius = RADIUS;
        self.layer.borderWidth = 1.0 / [UIScreen mainScreen].scale;
        self.layer.borderColor = C_LINE().CGColor;
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.borderColor = C_LINE().CGColor;
}
@end

#pragma mark - 设置行（标签居左，值居右）

@interface GODRow : UIView
@property (nonatomic, strong) UILabel *name;
@property (nonatomic, strong) UILabel *value;
@property (nonatomic, strong) UIView *line;
@end

@implementation GODRow
- (instancetype)init {
    if ((self = [super init])) {
        _name = [[UILabel alloc] init];
        _name.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
        _name.textColor = C_TEXT();
        [self addSubview:_name];

        _value = [[UILabel alloc] init];
        _value.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        _value.textColor = C_MUTED();
        _value.textAlignment = NSTextAlignmentRight;
        [self addSubview:_value];

        _line = [[UIView alloc] init];
        _line.backgroundColor = C_LINE();
        [self addSubview:_line];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    [_value sizeToFit];
    CGFloat vw = MIN(_value.bounds.size.width, w * 0.5);
    _value.frame = CGRectMake(w - S3 - vw, 0, vw, h);
    _name.frame = CGRectMake(S3, 0, w - S3 * 2 - vw - S2, h);
    _line.frame = CGRectMake(S3, h - 0.5, w - S3 * 2, 0.5);
}
@end

#pragma mark - 主界面

@interface GODInjectViewController : UIViewController
@property (nonatomic, strong) UILabel *statusDot;
@property (nonatomic, strong) UILabel *statusText;
@property (nonatomic, strong) GODRow *rowAccess;
@property (nonatomic, strong) GODRow *rowGroup;
@property (nonatomic, strong) GODRow *rowGame;
@property (nonatomic, strong) UITextField *cardField;
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, strong) UIButton *btnSetup;
@property (nonatomic, strong) UIButton *btnStart;
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, copy) NSString *gameContainer;
@end

@implementation GODInjectViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = C_BASE();
    [self.navigationController setNavigationBarHidden:YES animated:NO];

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scroll.alwaysBounceVertical = YES;
    scroll.contentInset = UIEdgeInsetsMake(0, 0, 96, 0);
    [self.view addSubview:scroll];

    CGFloat W = self.view.bounds.size.width;
    CGFloat contentW = W - S3 * 2;
    CGFloat y = 0;

    // ── 顶栏 ──
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, 88)];
    [scroll addSubview:header];

    UIView *mark = [[UIView alloc] initWithFrame:CGRectMake(S3, 44, 28, 28)];
    mark.backgroundColor = C_ACCENT();
    mark.layer.cornerRadius = 7;
    [header addSubview:mark];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(CGRectGetMaxX(mark.frame) + S2, 42, 220, 20)];
    title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    title.textColor = C_TEXT();
    title.text = @"GOD 注入器";
    [header addSubview:title];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(CGRectGetMaxX(mark.frame) + S2, 63, 260, 16)];
    sub.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    sub.textColor = C_MUTED();
    sub.text = @"卡密授权 · 自动注入";
    [header addSubview:sub];

    self.statusDot = [[UILabel alloc] initWithFrame:CGRectMake(W - S3 - 60, 48, 8, 8)];
    self.statusDot.backgroundColor = C_MUTED();
    self.statusDot.layer.cornerRadius = 4;
    self.statusDot.clipsToBounds = YES;
    [header addSubview:self.statusDot];

    self.statusText = [[UILabel alloc] initWithFrame:CGRectMake(W - S3 - 48, 42, 48, 20)];
    self.statusText.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.statusText.textColor = C_MUTED();
    self.statusText.textAlignment = NSTextAlignmentRight;
    self.statusText.text = @"待机";
    [header addSubview:self.statusText];

    UIView *hLine = [[UIView alloc] initWithFrame:CGRectMake(0, 87.5, W, 0.5)];
    hLine.backgroundColor = C_LINE();
    [header addSubview:hLine];

    y = 88 + S4;

    // ── 状态 ──
    [scroll addSubview:[self label:@"状态" frame:CGRectMake(S3, y, contentW, 16)]];
    y += 16 + S2;

    GODPanel *statePanel = [[GODPanel alloc] initWithFrame:CGRectMake(S3, y, contentW, ROW_H * 3)];
    self.rowAccess = [self row:@"沙盒访问" value:@"未检查" panel:statePanel idx:0];
    self.rowGroup  = [self row:@"App Group" value:@"未检查" panel:statePanel idx:1];
    self.rowGame   = [self row:@"游戏容器" value:@"未检查" panel:statePanel idx:2];
    [scroll addSubview:statePanel];
    y += statePanel.bounds.size.height + S4;

    // ── 卡密 ──
    [scroll addSubview:[self label:@"卡密" frame:CGRectMake(S3, y, contentW, 16)]];
    y += 16 + S2;

    GODPanel *cardPanel = [[GODPanel alloc] initWithFrame:CGRectMake(S3, y, contentW, ROW_H)];
    self.cardField = [[UITextField alloc] initWithFrame:CGRectMake(S3, 0, contentW - S3 * 2, ROW_H)];
    self.cardField.font = [UIFont fontWithName:@"Menlo" size:15] ?: [UIFont systemFontOfSize:15];
    self.cardField.textColor = C_TEXT();
    self.cardField.attributedPlaceholder =
        [[NSAttributedString alloc] initWithString:@"XXXX-XXXX-XXXX-XXXX"
                                        attributes:@{ NSForegroundColorAttributeName: [C_MUTED() colorWithAlphaComponent:0.6],
                                                      NSFontAttributeName: [UIFont fontWithName:@"Menlo" size:15] ?: [UIFont systemFontOfSize:15] }];
    self.cardField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.cardField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.cardField.keyboardType = UIKeyboardTypeASCIICapable;
    self.cardField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [cardPanel addSubview:self.cardField];
    [scroll addSubview:cardPanel];
    y += cardPanel.bounds.size.height + S4;

    // ── 日志 ──
    [scroll addSubview:[self label:@"日志" frame:CGRectMake(S3, y, contentW, 16)]];
    y += 16 + S2;

    GODPanel *logPanel = [[GODPanel alloc] initWithFrame:CGRectMake(S3, y, contentW, 240)];
    logPanel.backgroundColor = C_SURF2();
    self.logView = [[UITextView alloc] initWithFrame:CGRectMake(S3, S3, contentW - S3 * 2, 240 - S3 * 2)];
    self.logView.backgroundColor = [UIColor clearColor];
    self.logView.textColor = C_MUTED();
    self.logView.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    self.logView.editable = NO;
    self.logView.textContainerInset = UIEdgeInsetsZero;
    self.logView.textContainer.lineFragmentPadding = 0;
    [logPanel addSubview:self.logView];
    [scroll addSubview:logPanel];
    y += logPanel.bounds.size.height + S5;

    scroll.contentSize = CGSizeMake(W, y);

    // ── 底部操作栏 ──
    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 88,
                                                           W, 88)];
    bar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    bar.backgroundColor = C_BASE();
    UIView *bLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, 0.5)];
    bLine.backgroundColor = C_LINE();
    [bar addSubview:bLine];

    CGFloat bw = (W - S3 * 2 - S2) / 2.0;
    self.btnSetup = [self button:@"初始化" frame:CGRectMake(S3, S3, bw, 44) filled:NO];
    [self.btnSetup addTarget:self action:@selector(onInit) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:self.btnSetup];

    self.btnStart = [self button:@"开始注入" frame:CGRectMake(S3 + bw + S2, S3, bw, 44) filled:YES];
    [self.btnStart addTarget:self action:@selector(onStart) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:self.btnStart];

    [self.view addSubview:bar];

    [self log:@"就绪"];
}

#pragma mark - 组件

- (UILabel *)label:(NSString *)text frame:(CGRect)f {
    UILabel *l = [[UILabel alloc] initWithFrame:f];
    l.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    l.textColor = [C_MUTED() colorWithAlphaComponent:0.85];
    l.text = [text uppercaseString];
    return l;
}

- (GODRow *)row:(NSString *)name value:(NSString *)value panel:(UIView *)p idx:(NSInteger)i {
    GODRow *r = [[GODRow alloc] initWithFrame:CGRectMake(0, ROW_H * i, p.bounds.size.width, ROW_H)];
    r.name.text = name;
    r.value.text = value;
    r.line.hidden = (i == 2);
    [p addSubview:r];
    return r;
}

- (UIButton *)button:(NSString *)title frame:(CGRect)f filled:(BOOL)filled {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = f;
    b.layer.cornerRadius = 10;
    b.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    if (filled) {
        b.backgroundColor = C_ACCENT();
        [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        b.backgroundColor = [UIColor clearColor];
        b.layer.borderWidth = 1;
        b.layer.borderColor = C_LINE2().CGColor;
        [b setTitleColor:C_TEXT() forState:UIControlStateNormal];
    }
    [b setTitle:title forState:UIControlStateNormal];
    return b;
}

#pragma mark - 日志与状态

- (void)log:(NSString *)format, ... {
    va_list ap; va_start(ap, format);
    NSString *s = [[NSString alloc] initWithFormat:format arguments:ap];
    va_end(ap);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"HH:mm:ss";
        NSString *line = [NSString stringWithFormat:@"%@  %@\n", [df stringFromDate:[NSDate date]], s];
        self.logView.text = [self.logView.text stringByAppendingString:line];
        [self.logView scrollRangeToVisible:NSMakeRange(self.logView.text.length, 0)];
    });
}

- (void)setStatus:(NSString *)text color:(UIColor *)color {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusText.text = text;
        self.statusText.textColor = color;
        self.statusDot.backgroundColor = color;
    });
}

- (void)setRow:(GODRow *)row ok:(BOOL)ok text:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        row.value.text = text;
        row.value.textColor = ok ? C_GOOD() : C_BAD();
    });
}

- (void)setBusy:(BOOL)busy {
    _busy = busy;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.btnSetup.enabled = !busy;
        self.btnStart.enabled = !busy;
        self.btnSetup.alpha = busy ? 0.45 : 1.0;
        self.btnStart.alpha = busy ? 0.45 : 1.0;
    });
}

#pragma mark - 初始化

- (void)onInit {
    if (self.busy) return;
    self.busy = YES;
    [self setStatus:@"检查中" color:C_WARN()];
    [self log:@"开始检查环境"];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *group = wq_app_group();
        [self setRow:self.rowGroup ok:(group != nil) text:(group ? @"已获取" : @"无")];

        NSString *probe = @"/var/mobile/Containers/Data/Application";
        struct stat st;
        BOOL canStat = wq_stat(probe, &st) && S_ISDIR(st.st_mode);
        NSArray *list = canStat ? wq_enumerate(probe, 0, nil, nil) : nil;
        BOOL ok = (list.count > 0);
        [self setRow:self.rowAccess ok:ok
               text:(ok ? [NSString stringWithFormat:@"%lu 个容器", (unsigned long)list.count] : @"不可用")];
        [self log:ok ? [NSString stringWithFormat:@"沙盒可用，%lu 个容器", (unsigned long)list.count]
                    : @"沙盒不可用，检查签名 entitlement"];

        NSString *found = nil;
        for (NSString *dir in list) {
            NSString *label = wq_container_label(dir);
            if (label && [label isEqualToString:kGameBundleID]) { found = dir; break; }
        }
        self.gameContainer = found;
        [self setRow:self.rowGame ok:(found != nil) text:(found ? @"已定位" : @"未找到")];
        if (found) [self log:[NSString stringWithFormat:@"%@", found]];

        BOOL allOK = ok && found && group;
        [self setStatus:(allOK ? @"就绪" : @"异常") color:(allOK ? C_GOOD() : C_BAD())];
        self.busy = NO;
    });
}

#pragma mark - 注入

- (void)onStart {
    if (self.busy) return;
    NSString *card = [[self.cardField.text uppercaseString]
                      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (card.length == 0) {
        [self log:@"请先填写卡密"];
        [self setStatus:@"缺卡密" color:C_WARN()];
        return;
    }

    self.busy = YES;
    [self.cardField resignFirstResponder];
    [self setStatus:@"下载中" color:C_WARN()];
    [self log:@"开始注入"];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @try { [self doInject:card]; }
        @catch (NSException *e) { [self log:[NSString stringWithFormat:@"异常 %@", e.reason]]; }
        self.busy = NO;
    });
}

- (void)doInject:(NSString *)card {
    NSString *container = self.gameContainer;
    if (!container) {
        [self log:@"定位游戏容器"];
        NSArray *dirs = wq_enumerate(@"/var/mobile/Containers/Data/Application", 0, nil, nil);
        for (NSString *d in dirs) {
            NSString *label = wq_container_label(d);
            if (label && [label isEqualToString:kGameBundleID]) { container = d; break; }
        }
    }
    if (!container) {
        [self log:@"未找到游戏容器"];
        [self setStatus:@"失败" color:C_BAD()];
        return;
    }
    self.gameContainer = container;

    NSArray<NSString *> *parts = @[@"Documents", @"DeltaForce", @"Saved", @"LuaDebug",
                                   @"LuaSource", @"DFM", @"BusinessEntrance"];
    NSString *cur = container;
    for (NSString *p in parts) {
        cur = [cur stringByAppendingPathComponent:p];
        struct stat st;
        if (wq_stat(cur, &st) && S_ISDIR(st.st_mode)) continue;
        NSString *err = nil;
        if (!wq_create_dir(cur, &err)) {
            [self log:[NSString stringWithFormat:@"建目录失败 %@", p]];
            [self setStatus:@"失败" color:C_BAD()];
            return;
        }
        [self log:[NSString stringWithFormat:@"创建 %@", p]];
    }

    NSString *url = [NSString stringWithFormat:@"%@%@?card=%@", kServerBase, kDownloadPath,
                     [self urlEncode:card]];
    [self log:@"校验卡密"];
    NSData *data = [self downloadSync:url];
    if (!data || data.length < 100) {
        [self log:@"下载失败"];
        [self setStatus:@"失败" color:C_BAD()];
        return;
    }
    if (data.length < 4096 && [self isJSON:data]) {
        NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [self log:[NSString stringWithFormat:@"卡密无效 %@", s]];
        [self setStatus:@"卡密无效" color:C_BAD()];
        return;
    }

    const unsigned char *h = data.bytes;
    if (!(data.length >= 4 && h[0] == 0x1b && h[1] == 'L' && h[2] == 'u' && h[3] == 'a')) {
        [self log:@"文件格式异常"];
        [self setStatus:@"失败" color:C_BAD()];
        return;
    }
    [self log:[NSString stringWithFormat:@"下载完成 %lu KB", (unsigned long)(data.length / 1024)]];

    NSString *dest = [cur stringByAppendingPathComponent:@"EntranceFlow.lua"];
    struct stat st;
    if (wq_stat(dest, &st)) {
        NSData *old = wq_read(dest, 0, NULL);
        if (old) { wq_write([dest stringByAppendingString:@".bak"], old, NULL); }
    }
    NSString *werr = nil;
    BOOL ok = wq_stat(dest, &st) ? wq_write(dest, data, &werr) : wq_create_file(dest, data, &werr);
    if (ok) {
        [self log:@"写入成功，进游戏查看"];
        [self setStatus:@"完成" color:C_GOOD()];
    } else {
        [self log:[NSString stringWithFormat:@"写入失败 %@", werr ?: @""]];
        [self setStatus:@"失败" color:C_BAD()];
    }
}

#pragma mark - 工具

- (NSString *)urlEncode:(NSString *)s {
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
                               @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];
    return [s stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: s;
}

- (BOOL)isJSON:(NSData *)d {
    const unsigned char *b = d.bytes;
    for (NSUInteger i = 0; i < MIN(d.length, (NSUInteger)8); i++) {
        if (b[i] == ' ' || b[i] == '\n' || b[i] == '\r' || b[i] == '\t') continue;
        return (b[i] == '{' || b[i] == '[');
    }
    return NO;
}

- (NSData *)downloadSync:(NSString *)urlStr {
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) return nil;
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.timeoutInterval = 40;
    [req setValue:@"GODInject/1.0" forHTTPHeaderField:@"User-Agent"];

    __block NSData *result = nil;
    __block NSError *err = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [[[NSURLSession sharedSession] dataTaskWithRequest:req
                                    completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        result = d; err = e;
        dispatch_semaphore_signal(sem);
    }] resume];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 45 * NSEC_PER_SEC));
    if (err) [self log:[NSString stringWithFormat:@"网络 %@", err.localizedDescription]];
    return result;
}

@end

#pragma mark - AppDelegate

@interface GODAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation GODAppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    (void)opts;
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    GODInjectViewController *vc = [[GODInjectViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [nav setNavigationBarHidden:YES animated:NO];
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];

    // 深色状态栏
    if (@available(iOS 13.0, *)) {
        self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, @"GODAppDelegate");
    }
}