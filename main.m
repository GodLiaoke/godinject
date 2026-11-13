//
//  main.m — GOD 注入器
//  沙盒访问基于 worse_query（WQAccess），不需要越狱
//
//  设计规范：中性色 / 固定间距档位 / 标签居左控件居右 / 分组标题 / 无装饰
//

#import <UIKit/UIKit.h>
#import <sys/stat.h>
#import "WQAccess.h"

// ── 常量 ───────────────────────────────────────────────
static NSString *const kGameBundleID = @"com.tencent.tmgp.dfm";
static NSString *const kServerBase   = @"https://ios.ouovo.cc";
static NSString *const kDownloadPath = @"/api/god/download";   // ?card=XXXX

// ── 设计变量（固定档位，不用魔法数字）───────────────────
static const CGFloat kSpace1 = 4.0;    // 元素内
static const CGFloat kSpace2 = 8.0;    // 元素间
static const CGFloat kSpace3 = 16.0;   // 行内边距
static const CGFloat kSpace4 = 24.0;   // 组间
static const CGFloat kSpace5 = 32.0;
static const CGFloat kRowHeight = 48.0;
static const CGFloat kRadius = 10.0;

static UIColor *C_BG(void)      { return [UIColor colorWithRed:0.949 green:0.949 blue:0.969 alpha:1]; } // F2F2F7
static UIColor *C_CARD(void)    { return [UIColor whiteColor]; }
static UIColor *C_TEXT(void)    { return [UIColor colorWithRed:0.110 green:0.110 blue:0.118 alpha:1]; } // 1C1C1E
static UIColor *C_TEXT2(void)   { return [UIColor colorWithRed:0.557 green:0.557 blue:0.576 alpha:1]; } // 8E8E93
static UIColor *C_LINE(void)    { return [UIColor colorWithRed:0.898 green:0.898 blue:0.918 alpha:1]; } // E5E5EA
static UIColor *C_ACTION(void)  { return [UIColor colorWithRed:0.000 green:0.478 blue:1.000 alpha:1]; } // 007AFF
static UIColor *C_DANGER(void)  { return [UIColor colorWithRed:1.000 green:0.231 blue:0.188 alpha:1]; } // FF3B30

#pragma mark - 扫描回调

static BOOL GODConfirmScan(NSString *what, int64_t ids, double seconds) {
    (void)what; (void)ids; (void)seconds;
    return YES;
}

static void GODScanProgress(int64_t done, int64_t total, BOOL finished) {
    (void)done; (void)total; (void)finished;
}

#pragma mark - 通用行视图

@interface GODRow : UIView
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UILabel *value;
@property (nonatomic, strong) UIView *separator;
@end

@implementation GODRow
- (instancetype)init {
    if ((self = [super init])) {
        _label = [[UILabel alloc] init];
        _label.font = [UIFont systemFontOfSize:17];
        _label.textColor = C_TEXT();
        [self addSubview:_label];

        _value = [[UILabel alloc] init];
        _value.font = [UIFont systemFontOfSize:17];
        _value.textColor = C_TEXT2();
        _value.textAlignment = NSTextAlignmentRight;
        [self addSubview:_value];

        _separator = [[UIView alloc] init];
        _separator.backgroundColor = C_LINE();
        [self addSubview:_separator];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    CGFloat valueMax = w * 0.55;
    [_value sizeToFit];
    CGFloat vw = MIN(_value.bounds.size.width, valueMax);
    _value.frame = CGRectMake(w - kSpace3 - vw, 0, vw, h);
    _label.frame = CGRectMake(kSpace3, 0, w - kSpace3 * 2 - vw - kSpace2, h);
    _separator.frame = CGRectMake(kSpace3, h - 0.5, w - kSpace3, 0.5);
}
@end

#pragma mark - 分组容器

@interface GODGroup : UIView
@end

@implementation GODGroup
- (instancetype)init {
    if ((self = [super init])) {
        self.backgroundColor = C_CARD();
        self.layer.cornerRadius = kRadius;
        // 圆角曲线用默认
    }
    return self;
}
@end

#pragma mark - 主界面

@interface GODInjectViewController : UIViewController
@property (nonatomic, strong) UILabel *noticeText;
@property (nonatomic, strong) GODRow *rowAccess;
@property (nonatomic, strong) GODRow *rowGroup;
@property (nonatomic, strong) GODRow *rowGame;
@property (nonatomic, strong) UIButton *btnSetup;
@property (nonatomic, strong) UIButton *btnStart;
@property (nonatomic, strong) UITextField *cardField;
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, copy) NSString *gameContainer;
@end

@implementation GODInjectViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = C_BG();
    self.title = @"GOD";
    self.navigationController.navigationBar.prefersLargeTitles = NO;

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scroll.alwaysBounceVertical = YES;
    [self.view addSubview:scroll];

    CGFloat W = self.view.bounds.size.width - kSpace3 * 2;
    CGFloat y = kSpace4;

    // ── 公告 ──
    UILabel *noticeTitle = [self sectionTitle:@"公告"];
    noticeTitle.frame = CGRectMake(kSpace3, y, W, 20);
    [scroll addSubview:noticeTitle];
    y += 20 + kSpace2;

    GODGroup *noticeGroup = [[GODGroup alloc] initWithFrame:CGRectMake(kSpace3, y, W, kRowHeight + 12)];
    self.noticeText = [[UILabel alloc] initWithFrame:CGRectMake(kSpace3, 6, W - kSpace3 * 2, kRowHeight)];
    self.noticeText.font = [UIFont systemFontOfSize:15];
    self.noticeText.textColor = C_TEXT();
    self.noticeText.numberOfLines = 1;
    self.noticeText.text = @"内测版 · 卡密验证开发中";
    [noticeGroup addSubview:self.noticeText];
    [scroll addSubview:noticeGroup];
    y += noticeGroup.bounds.size.height + kSpace4;

    // ── 状态 ──
    UILabel *stateTitle = [self sectionTitle:@"状态"];
    stateTitle.frame = CGRectMake(kSpace3, y, W, 20);
    [scroll addSubview:stateTitle];
    y += 20 + kSpace2;

    GODGroup *stateGroup = [[GODGroup alloc] initWithFrame:CGRectMake(kSpace3, y, W, kRowHeight * 3)];
    self.rowAccess = [self addRow:@"沙盒访问" value:@"未检查" group:stateGroup index:0 total:3];
    self.rowGroup  = [self addRow:@"App Group" value:@"未检查" group:stateGroup index:1 total:3];
    self.rowGame   = [self addRow:@"游戏容器" value:@"未检查" group:stateGroup index:2 total:3];
    [scroll addSubview:stateGroup];
    y += stateGroup.bounds.size.height + kSpace4;

    // ── 卡密 ──
    UILabel *cardTitle = [self sectionTitle:@"卡密"];
    cardTitle.frame = CGRectMake(kSpace3, y, W, 20);
    [scroll addSubview:cardTitle];
    y += 20 + kSpace2;

    GODGroup *cardGroup = [[GODGroup alloc] initWithFrame:CGRectMake(kSpace3, y, W, kRowHeight)];
    self.cardField = [[UITextField alloc] initWithFrame:CGRectMake(kSpace3, 0, W - kSpace3 * 2, kRowHeight)];
    self.cardField.font = [UIFont systemFontOfSize:17];
    self.cardField.textColor = C_TEXT();
    self.cardField.placeholder = @"输入卡密";
    self.cardField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.cardField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.cardField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [cardGroup addSubview:self.cardField];
    [scroll addSubview:cardGroup];
    y += cardGroup.bounds.size.height + kSpace4;

    // ── 操作 ──
    UILabel *actionTitle = [self sectionTitle:@"操作"];
    actionTitle.frame = CGRectMake(kSpace3, y, W, 20);
    [scroll addSubview:actionTitle];
    y += 20 + kSpace2;

    GODGroup *actionGroup = [[GODGroup alloc] initWithFrame:CGRectMake(kSpace3, y, W, kRowHeight * 2)];
    self.btnSetup = [self addAction:@"初始化" group:actionGroup index:0 total:2];
    [self.btnSetup addTarget:self action:@selector(onInit) forControlEvents:UIControlEventTouchUpInside];
    self.btnStart = [self addAction:@"开始注入" group:actionGroup index:1 total:2];
    [self.btnStart addTarget:self action:@selector(onStart) forControlEvents:UIControlEventTouchUpInside];
    [scroll addSubview:actionGroup];
    y += actionGroup.bounds.size.height + kSpace4;

    // ── 日志 ──
    UILabel *logTitle = [self sectionTitle:@"日志"];
    logTitle.frame = CGRectMake(kSpace3, y, W, 20);
    [scroll addSubview:logTitle];
    y += 20 + kSpace2;

    GODGroup *logGroup = [[GODGroup alloc] initWithFrame:CGRectMake(kSpace3, y, W, 280)];
    self.logView = [[UITextView alloc] initWithFrame:CGRectMake(kSpace3, kSpace2, W - kSpace3 * 2, 280 - kSpace2 * 2)];
    self.logView.backgroundColor = [UIColor clearColor];
    self.logView.textColor = C_TEXT2();
    self.logView.font = [UIFont fontWithName:@"Menlo" size:12] ?: [UIFont systemFontOfSize:12];
    self.logView.editable = NO;
    self.logView.textContainerInset = UIEdgeInsetsZero;
    self.logView.textContainer.lineFragmentPadding = 0;
    [logGroup addSubview:self.logView];
    [scroll addSubview:logGroup];
    y += logGroup.bounds.size.height + kSpace5;

    scroll.contentSize = CGSizeMake(self.view.bounds.size.width, y);

    [self log:@"就绪"];
}

#pragma mark - UI 构建辅助

- (UILabel *)sectionTitle:(NSString *)text {
    UILabel *l = [[UILabel alloc] init];
    l.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    l.textColor = C_TEXT2();
    l.text = text;
    return l;
}

- (GODRow *)addRow:(NSString *)name value:(NSString *)value group:(UIView *)group index:(NSInteger)i total:(NSInteger)n {
    CGFloat h = kRowHeight;
    GODRow *r = [[GODRow alloc] initWithFrame:CGRectMake(0, h * i, group.bounds.size.width, h)];
    r.label.text = name;
    r.value.text = value;
    r.separator.hidden = (i == n - 1);
    [group addSubview:r];
    return r;
}

- (UIButton *)addAction:(NSString *)title group:(UIView *)group index:(NSInteger)i total:(NSInteger)n {
    CGFloat h = kRowHeight;
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(0, h * i, group.bounds.size.width, h);
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:C_ACTION() forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:17];
    b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    b.contentEdgeInsets = UIEdgeInsetsMake(0, kSpace3, 0, kSpace3);
    if (i != n - 1) {
        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(kSpace3, h - 0.5, group.bounds.size.width - kSpace3, 0.5)];
        line.backgroundColor = C_LINE();
        [b addSubview:line];
    }
    [group addSubview:b];
    return b;
}

#pragma mark - 日志

- (void)log:(NSString *)format, ... {
    va_list ap;
    va_start(ap, format);
    NSString *s = [[NSString alloc] initWithFormat:format arguments:ap];
    va_end(ap);

    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *line = [NSString stringWithFormat:@"%@\n", s];
        self.logView.text = [self.logView.text stringByAppendingString:line];
        [self.logView scrollRangeToVisible:NSMakeRange(self.logView.text.length, 0)];
    });
}

- (void)setBusy:(BOOL)busy {
    _busy = busy;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.btnSetup.enabled = !busy;
        self.btnStart.enabled = !busy;
        self.btnSetup.alpha = busy ? 0.4 : 1.0;
        self.btnStart.alpha = busy ? 0.4 : 1.0;
    });
}

- (void)setRow:(GODRow *)row ok:(BOOL)ok text:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        row.value.text = text;
        row.value.textColor = ok ? C_TEXT2() : C_DANGER();
    });
}

#pragma mark - 初始化（用实际探测，不看 wq_grant）

- (void)onInit {
    if (self.busy) return;
    self.busy = YES;
    [self log:@"初始化…"];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        // App Group：拿到的是签名时注入的组
        NSString *group = wq_app_group();
        [self setRow:self.rowGroup ok:(group != nil)
               text:(group ? @"已获取" : @"无")];

        // 沙盒访问：直接 stat 一个已知存在的子目录，不看 wq_grant 返回值
        NSString *probe = @"/var/mobile/Containers/Data/Application";
        struct stat st;
        BOOL canStat = wq_stat(probe, &st) && S_ISDIR(st.st_mode);

        // 再试枚举前若干个容器，确认真的能读
        NSArray *probeList = canStat ? wq_enumerate(probe, 0, nil, nil) : nil;
        BOOL ok = (probeList.count > 0);
        [self setRow:self.rowAccess ok:ok
               text:(ok ? [NSString stringWithFormat:@"可用 · %lu 容器", (unsigned long)probeList.count]
                        : @"不可用")];
        [self log:ok ? [NSString stringWithFormat:@"沙盒访问正常，可见 %lu 个容器", (unsigned long)probeList.count]
                    : @"沙盒访问失败"];

        // 找游戏
        NSString *found = nil;
        for (NSString *dir in probeList) {
            NSString *label = wq_container_label(dir);
            if (label && [label isEqualToString:kGameBundleID]) { found = dir; break; }
        }
        self.gameContainer = found;
        [self setRow:self.rowGame ok:(found != nil) text:(found ? @"已找到" : @"未找到")];
        if (found) [self log:[NSString stringWithFormat:@"游戏容器：%@", found]];

        self.busy = NO;
    });
}

#pragma mark - 注入

- (void)onStart {
    if (self.busy) return;

    NSString *card = [self.cardField.text stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (card.length == 0) {
        [self log:@"先输入卡密"];
        return;
    }

    self.busy = YES;
    [self.cardField resignFirstResponder];
    [self log:@"开始注入…"];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @try { [self doInject:card]; }
        @catch (NSException *e) { [self log:[NSString stringWithFormat:@"异常：%@", e.reason]]; }
        self.busy = NO;
    });
}

- (void)doInject:(NSString *)card {
    // 容器：没找到就现找
    NSString *container = self.gameContainer;
    if (!container) {
        [self log:@"查找游戏容器…"];
        NSArray *dirs = wq_enumerate(@"/var/mobile/Containers/Data/Application", 0, nil, nil);
        for (NSString *dir in dirs) {
            NSString *label = wq_container_label(dir);
            if (label && [label isEqualToString:kGameBundleID]) { container = dir; break; }
        }
    }
    if (!container) {
        [self log:@"未找到游戏容器"];
        [self setRow:self.rowGame ok:NO text:@"未找到"];
        return;
    }
    self.gameContainer = container;
    [self log:[NSString stringWithFormat:@"容器：%@", container]];

    // 目录
    NSArray<NSString *> *parts = @[@"Documents", @"DeltaForce", @"Saved", @"LuaDebug",
                                   @"LuaSource", @"DFM", @"BusinessEntrance"];
    NSString *cur = container;
    for (NSString *p in parts) {
        cur = [cur stringByAppendingPathComponent:p];
        struct stat st;
        if (wq_stat(cur, &st) && S_ISDIR(st.st_mode)) continue;
        NSString *err = nil;
        if (!wq_create_dir(cur, &err)) {
            [self log:[NSString stringWithFormat:@"建目录失败 %@：%@", p, err ?: @"?"]];
            return;
        }
        [self log:[NSString stringWithFormat:@"创建 %@", p]];
    }

    // 下载（带卡密）
    NSString *url = [NSString stringWithFormat:@"%@%@?card=%@", kServerBase, kDownloadPath,
                     [self urlEncode:card]];
    [self log:@"校验卡密并下载…"];
    NSData *data = [self downloadSync:url];
    if (!data || data.length < 100) {
        [self log:[NSString stringWithFormat:@"下载失败（%lu 字节）", (unsigned long)data.length]];
        return;
    }

    // 服务端可能返回 JSON 错误
    if (data.length < 4096 && [self looksLikeJSON:data]) {
        NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [self log:[NSString stringWithFormat:@"服务端返回：%@", s]];
        return;
    }

    const unsigned char *h = data.bytes;
    BOOL isLua = (data.length >= 4 && h[0] == 0x1b && h[1] == 'L' && h[2] == 'u' && h[3] == 'a');
    [self log:[NSString stringWithFormat:@"下载 %lu 字节，格式%@", (unsigned long)data.length,
               isLua ? @"正确" : @"异常"]];
    if (!isLua) {
        [self log:@"不是 Lua 字节码，已中止"];
        return;
    }

    // 备份 + 写入
    NSString *dest = [cur stringByAppendingPathComponent:@"EntranceFlow.lua"];
    struct stat st;
    if (wq_stat(dest, &st)) {
        NSData *old = wq_read(dest, 0, NULL);
        if (old) {
            wq_write([dest stringByAppendingString:@".bak"], old, NULL);
            [self log:@"已备份原文件"];
        }
    }

    NSString *werr = nil;
    BOOL ok = wq_stat(dest, &st) ? wq_write(dest, data, &werr)
                                 : wq_create_file(dest, data, &werr);
    if (ok) {
        [self log:[NSString stringWithFormat:@"写入成功（%lu 字节）", (unsigned long)data.length]];
        [self log:@"完成，进游戏查看"];
    } else {
        [self log:[NSString stringWithFormat:@"写入失败：%@", werr ?: @"?"]];
    }
}

#pragma mark - 工具

- (NSString *)urlEncode:(NSString *)s {
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
                               @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];
    return [s stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: s;
}

- (BOOL)looksLikeJSON:(NSData *)d {
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
    if (err) [self log:[NSString stringWithFormat:@"网络错误：%@", err.localizedDescription]];
    return result;
}

@end

#pragma mark - AppDelegate

@interface GODAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation GODAppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    GODInjectViewController *vc = [[GODInjectViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.navigationBar.translucent = NO;
    nav.navigationBar.barTintColor = C_BG();
    nav.navigationBar.titleTextAttributes = @{ NSForegroundColorAttributeName: C_TEXT() };
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, @"GODAppDelegate");
    }
}