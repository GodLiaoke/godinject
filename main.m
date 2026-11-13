//
//  main.m — GOD 注入器
//  沙盒访问基于 worse_query（WQAccess），无需越狱
//
//  流程：
//    初始化 → 检查 App Group / 沙盒访问能力
//    开始   → 找三角洲容器 → 建 LuaDebug 目录 → 下载 EntranceFlow.lua → 写入
//

#import <UIKit/UIKit.h>
#import <sys/stat.h>
#import "WQAccess.h"

static NSString *const kGameBundleID = @"com.tencent.tmgp.dfm";
static NSString *const kRemoteURL =
    @"https://raw.githubusercontent.com/godfix/godinject/main/EntranceFlow.lua";

#pragma mark - 扫描确认回调（wq_enumerate 必须设置才会扫描）

static BOOL GODConfirmScan(NSString *what, int64_t ids, double seconds) {
    return YES;
}

static void GODScanProgress(int64_t done, int64_t total, BOOL finished) {
    (void)done; (void)total; (void)finished;
}

#pragma mark - 主界面

@interface GODInjectViewController : UIViewController
@property (nonatomic, strong) UILabel *noticeLabel;
@property (nonatomic, strong) UIButton *btnInit;
@property (nonatomic, strong) UIButton *startButton;
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, assign) BOOL busy;
@end

@implementation GODInjectViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.07 alpha:1.0];
    self.title = @"GOD 注入器";

    CGFloat W = self.view.bounds.size.width;
    CGFloat y = 100.0;

    // 公告
    self.noticeLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, W - 40, 56)];
    self.noticeLabel.numberOfLines = 0;
    self.noticeLabel.textAlignment = NSTextAlignmentCenter;
    self.noticeLabel.textColor = [UIColor colorWithRed:0.55 green:0.95 blue:0.75 alpha:1.0];
    self.noticeLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.noticeLabel.text = @"公告\n内测版 — 卡密验证开发中";
    [self.view addSubview:self.noticeLabel];
    y += 76;

    // 两个按钮
    CGFloat bw = (W - 60) / 2.0;
    self.btnInit = [self makeButton:@"初始化" frame:CGRectMake(20, y, bw, 50)];
    self.startButton = [self makeButton:@"开始" frame:CGRectMake(40 + bw, y, bw, 50)];
    [self.btnInit addTarget:self action:@selector(onInit) forControlEvents:UIControlEventTouchUpInside];
    [self.startButton addTarget:self action:@selector(onStart) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnInit];
    [self.view addSubview:self.startButton];
    y += 70;

    // 日志
    self.logView = [[UITextView alloc] initWithFrame:CGRectMake(16, y, W - 32,
                                                                self.view.bounds.size.height - y - 40)];
    self.logView.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    self.logView.textColor = [UIColor colorWithWhite:0.92 alpha:1.0];
    self.logView.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    self.logView.editable = NO;
    self.logView.layer.cornerRadius = 8;
    self.logView.text = @"";
    [self.view addSubview:self.logView];

    [self log:@"GOD 注入器已启动"];
    [self log:@"先点「初始化」检查权限，再点「开始」注入"];
}

- (UIButton *)makeButton:(NSString *)title frame:(CGRect)f {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = f;
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    b.backgroundColor = [UIColor colorWithRed:0.15 green:0.55 blue:0.85 alpha:1.0];
    b.layer.cornerRadius = 10;
    return b;
}

#pragma mark - 日志

- (void)log:(NSString *)format, ... {
    va_list ap;
    va_start(ap, format);
    NSString *s = [[NSString alloc] initWithFormat:format arguments:ap];
    va_end(ap);

    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *line = [NSString stringWithFormat:@"[%@] %@\n",
                          [self timestamp], s];
        self.logView.text = [self.logView.text stringByAppendingString:line];
        if (self.logView.text.length > 1) {
            [self.logView scrollRangeToVisible:NSMakeRange(self.logView.text.length - 1, 1)];
        }
    });
}

- (NSString *)timestamp {
    static NSDateFormatter *df = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"HH:mm:ss";
    });
    return [df stringFromDate:[NSDate date]];
}

- (void)setBusy:(BOOL)busy {
    _busy = busy;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.btnInit.enabled = !busy;
        self.startButton.enabled = !busy;
        self.btnInit.alpha = busy ? 0.45 : 1.0;
        self.startButton.alpha = busy ? 0.45 : 1.0;
    });
}

#pragma mark - 初始化

- (void)onInit {
    if (self.busy) return;
    self.busy = YES;
    [self log:@"===== 初始化 ====="];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        // App Group
        NSString *group = wq_app_group();
        [self log:@"App Group: %@", group ?: @"(无 — 签名时没给 App Group)"];

        // iOS 26 兼容
        BOOL legacy = wq_system_areas_reachable() ? NO : YES;
        [self log:@"系统区域可达: %@", wq_system_areas_reachable() ? @"是" : @"否（iOS 26 模式）"];
        (void)legacy;

        // 沙盒访问能力：拿 Application 父目录做试探
        NSString *probe = @"/var/mobile/Containers/Data/Application";
        BOOL granted = wq_grant(probe);
        [self log:@"沙盒访问 %@: %@", probe, granted ? @"OK" : @"被拒绝"];

        // 再验一个真实路径
        NSString *mobile = @"/var/mobile";
        BOOL g2 = wq_grant(mobile);
        [self log:@"/var/mobile 访问: %@", g2 ? @"OK" : @"被拒绝"];

        // 准备枚举回调（第一次扫描会比较久）
        wq_set_full_scan_ui(GODConfirmScan, GODScanProgress);

        [self log:@"初始化完成"];
        self.busy = NO;
    });
}

#pragma mark - 开始注入

- (void)onStart {
    if (self.busy) return;
    self.busy = YES;
    [self log:@"===== 开始注入 ====="];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @try {
            [self doInject];
        } @catch (NSException *e) {
            [self log:@"异常: %@", e.reason];
        }
        self.busy = NO;
    });
}

- (void)doInject {
    // ── 1) 定位三角洲容器 ──
    [self log:@"扫描 App 容器（首次可能要几分钟）..."];
    wq_set_full_scan_ui(GODConfirmScan, GODScanProgress);

    NSString *container = [self findGameContainer];
    if (!container) {
        [self log:@"找不到三角洲容器，请确认游戏已安装并至少运行过一次"];
        return;
    }
    [self log:@"找到容器: %@", container];

    // ── 2) 逐级创建目录 ──
    NSArray<NSString *> *parts = @[@"Documents", @"DeltaForce", @"Saved", @"LuaDebug",
                                   @"LuaSource", @"DFM", @"BusinessEntrance"];
    NSString *cur = container;
    for (NSString *p in parts) {
        cur = [cur stringByAppendingPathComponent:p];
        struct stat st;
        if (wq_stat(cur, &st) && S_ISDIR(st.st_mode)) {
            [self log:@"已存在: %@", p];
            continue;
        }
        NSString *err = nil;
        if (wq_create_dir(cur, &err)) {
            [self log:@"创建: %@", p];
        } else {
            [self log:@"创建失败 %@: %@", p, err ?: @"?"];
            return;
        }
    }

    // ── 3) 下载 ──
    [self log:@"下载: %@", kRemoteURL];
    NSData *data = [self downloadSync:kRemoteURL];
    if (!data || data.length < 1000) {
        [self log:@"下载失败或内容异常（%lu 字节）", (unsigned long)data.length];
        return;
    }
    [self log:@"下载完成: %lu 字节", (unsigned long)data.length];

    // 校验头部（私有容器以 \x1bLuaS 开头）
    const unsigned char *head = data.bytes;
    if (data.length >= 5 && head[0] == 0x1b && head[1] == 'L' && head[2] == 'u' && head[3] == 'a') {
        [self log:@"格式校验: OK (Lua chunk)"];
    } else {
        [self log:@"格式校验: 不像 Lua 字节码，继续写入"];
    }

    // ── 4) 备份旧文件 ──
    NSString *dest = [cur stringByAppendingPathComponent:@"EntranceFlow.lua"];
    struct stat st;
    if (wq_stat(dest, &st)) {
        [self log:@"已存在原文件 %lld 字节，先备份", (long long)st.st_size];
        NSData *old = wq_read(dest, 0, NULL);
        if (old) {
            NSString *bak = [dest stringByAppendingString:@".bak"];
            wq_write(bak, old, NULL);
            [self log:@"备份到: %@", bak.lastPathComponent];
        }
    }

    // ── 5) 写入 ──
    NSString *werr = nil;
    BOOL ok = wq_stat(dest, &st) ? wq_write(dest, data, &werr)
                                 : wq_create_file(dest, data, &werr);
    if (ok) {
        [self log:@"写入成功: EntranceFlow.lua (%lu 字节)", (unsigned long)data.length];
        [self log:@"完成 — 进游戏检查效果"];
    } else {
        [self log:@"写入失败: %@", werr ?: @"?"];
    }
}

#pragma mark - 找游戏容器

- (NSString *)findGameContainer {
    NSString *parent = @"/var/mobile/Containers/Data/Application";

    NSArray<NSString *> *dirs = wq_enumerate(parent, 0, nil, nil);
    [self log:@"枚举到 %lu 个容器", (unsigned long)dirs.count];

    for (NSString *dir in dirs) {
        NSString *label = wq_container_label(dir);
        if (!label) continue;
        if ([label isEqualToString:kGameBundleID]) {
            return dir;
        }
    }

    // 回退：直接读每个容器的 .com.apple.mobile_container_manager.metadata.plist
    if (dirs.count == 0) {
        [self log:@"枚举为空，尝试直接探测常见容器"];
    }
    return nil;
}

#pragma mark - 同步下载

- (NSData *)downloadSync:(NSString *)urlStr {
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) return nil;

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.timeoutInterval = 30;
    [req setValue:@"GODInject/1.0" forHTTPHeaderField:@"User-Agent"];

    __block NSData *result = nil;
    __block NSError *err = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    NSURLSessionDataTask *task =
        [[NSURLSession sharedSession] dataTaskWithRequest:req
                                       completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
            result = d;
            err = e;
            dispatch_semaphore_signal(sem);
        }];
    [task resume];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 45 * NSEC_PER_SEC));

    if (err) [self log:@"下载错误: %@", err.localizedDescription];
    return result;
}

@end

#pragma mark - AppDelegate

@interface GODAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation GODAppDelegate

- (BOOL)application:(UIApplication *)app
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    GODInjectViewController *vc = [[GODInjectViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.navigationBar.barStyle = UIBarStyleBlack;
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