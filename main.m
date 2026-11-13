//
//  main.m — GOD 注入器
//  两段式：激活页（卡密验证）→ 控制台
//  视觉与布局沿用 Phoenix（LicenseView / MainConsoleView）的令牌与结构
//  沙盒访问基于 worse_query（WQAccess），不需要越狱
//

#import <UIKit/UIKit.h>
#import <sys/stat.h>
#import "WQAccess.h"

#pragma mark - 常量

static NSString *const kGameBundleID = @"com.tencent.tmgp.dfm";
static NSString *const kServerBase   = @"https://ios.ouovo.cc";
static NSString *const kDownloadPath = @"/api/god/download";
static NSString *const kStoreCard    = @"god.card";
static NSString *const kStoreLicense = @"god.licensed";

#pragma mark - 设计令牌（Phoenix 浅色 + 金色强调）

static UIColor *C_BASE(void)   { return [UIColor colorWithRed:0.937 green:0.949 blue:0.973 alpha:1]; } // #EFF2F8
static UIColor *C_CARD(void)   { return [UIColor whiteColor]; }
static UIColor *C_TEXT(void)   { return [UIColor colorWithRed:0.078 green:0.090 blue:0.145 alpha:1]; } // #141725
static UIColor *C_MUTED(void)  { return [UIColor colorWithRed:0.427 green:0.459 blue:0.529 alpha:1]; } // #6D7587
static UIColor *C_ACCENT(void) { return [UIColor colorWithRed:0.169 green:0.192 blue:0.376 alpha:1]; } // #2B3160
static UIColor *C_WARM(void)   { return [UIColor colorWithRed:0.902 green:0.729 blue:0.361 alpha:1]; } // #E6BA5C
static UIColor *C_GOOD(void)   { return [UIColor colorWithRed:0.078 green:0.639 blue:0.412 alpha:1]; } // #14A369
static UIColor *C_WARN(void)   { return [UIColor colorWithRed:0.847 green:0.549 blue:0.078 alpha:1]; } // #D88C14
static UIColor *C_BAD(void)    { return [UIColor colorWithRed:0.878 green:0.231 blue:0.341 alpha:1]; } // #E03B57
static UIColor *C_HAIR(void)   { return [C_TEXT() colorWithAlphaComponent:0.10]; }

static const CGFloat S1 = 4.0, S2 = 8.0, S3 = 16.0, S4 = 24.0, S5 = 32.0, S6 = 44.0;
static const CGFloat ROW_H = 54.0;
static const CGFloat R_CARD = 22.0;
static const CGFloat R_BTN = 14.0;

#pragma mark - 渐变按钮

@interface GODGradientButton : UIButton
@end

@implementation GODGradientButton {
    CAGradientLayer *_grad;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _grad = [CAGradientLayer layer];
        _grad.colors = @[(id)C_ACCENT().CGColor, (id)C_WARM().CGColor];
        _grad.startPoint = CGPointMake(0, 0.5);
        _grad.endPoint = CGPointMake(1, 0.5);
        _grad.cornerRadius = R_BTN;
        [self.layer insertSublayer:_grad atIndex:0];
        self.layer.cornerRadius = R_BTN;
        self.clipsToBounds = YES;
        self.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self setTitleColor:[[UIColor whiteColor] colorWithAlphaComponent:0.45] forState:UIControlStateDisabled];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    _grad.frame = self.bounds;
}
@end

#pragma mark - 卡片

@interface GODCard : UIView
@end
@implementation GODCard
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = C_CARD();
        self.layer.cornerRadius = R_CARD;
        self.layer.borderWidth = 1;
        self.layer.borderColor = C_HAIR().CGColor;
    }
    return self;
}
- (void)layoutSubviews { [super layoutSubviews]; self.layer.borderColor = C_HAIR().CGColor; }
@end

#pragma mark - 图标

@interface GODMark : UIView
@end
@implementation GODMark
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = C_ACCENT();
        self.layer.cornerRadius = f.size.width * 0.28;
        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectInset(self.bounds, f.size.width * 0.26, f.size.width * 0.26)];
        iv.image = [UIImage systemImageNamed:@"shield.lefthalf.filled"];
        iv.tintColor = C_WARM();
        iv.contentMode = UIViewContentModeScaleAspectFit;
        iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:iv];
    }
    return self;
}
@end

#pragma mark - 网络

@interface GODNet : NSObject
+ (void)verifyCard:(NSString *)card completion:(void (^)(BOOL ok, NSData *file, NSString *err))done;
@end

@implementation GODNet
+ (void)verifyCard:(NSString *)card completion:(void (^)(BOOL, NSData *, NSString *))done {
    NSString *enc = [card stringByAddingPercentEncodingWithAllowedCharacters:
                     [NSCharacterSet characterSetWithCharactersInString:
                      @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"]];
    NSString *urlStr = [NSString stringWithFormat:@"%@%@?card=%@", kServerBase, kDownloadPath, enc];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.timeoutInterval = 40;
    [req setValue:@"GODInject/1.0" forHTTPHeaderField:@"User-Agent"];

    [[[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (e) { dispatch_async(dispatch_get_main_queue(), ^{ done(NO, nil, e.localizedDescription); }); return; }
        NSInteger code = [(NSHTTPURLResponse *)r statusCode];
        if (code == 200 && d.length > 100) {
            const unsigned char *h = d.bytes;
            if (h[0] == 0x1b && h[1] == 'L' && h[2] == 'u' && h[3] == 'a') {
                dispatch_async(dispatch_get_main_queue(), ^{ done(YES, d, nil); });
                return;
            }
        }
        NSString *msg = @"验证失败";
        if (d.length < 4096) {
            NSDictionary *j = [NSJSONSerialization JSONObjectWithData:d options:0 error:NULL];
            if ([j isKindOfClass:[NSDictionary class]]) {
                NSString *err = j[@"error"];
                if ([err isEqualToString:@"card_not_found"])      msg = @"卡密不存在";
                else if ([err isEqualToString:@"card_revoked"])   msg = @"卡密已被封禁";
                else if ([err isEqualToString:@"card_expired"])   msg = @"卡密已过期";
                else if ([err isEqualToString:@"card_format"])    msg = @"卡密格式不正确";
                else if (err.length)                              msg = err;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{ done(NO, nil, msg); });
    }] resume];
}
@end

#pragma mark - 激活页

@interface GODLicenseViewController : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *field;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) GODGradientButton *btn;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) BOOL busy;
@end

@implementation GODLicenseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = C_BASE();

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];

    CGFloat W = self.view.bounds.size.width;
    CGFloat y = 44;

    GODMark *mark = [[GODMark alloc] initWithFrame:CGRectMake((W - 96) / 2, y, 96, 96)];
    [scroll addSubview:mark];
    y += 96 + 20;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(S3, y, W - S3 * 2, 34)];
    title.text = @"GOD 注入器";
    title.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
    title.textColor = C_TEXT();
    title.textAlignment = NSTextAlignmentCenter;
    [scroll addSubview:title];
    y += 34 + 6;

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(S3, y, W - S3 * 2, 20)];
    sub.text = @"卡密授权 · 自动注入";
    sub.font = [UIFont systemFontOfSize:14];
    sub.textColor = C_MUTED();
    sub.textAlignment = NSTextAlignmentCenter;
    [scroll addSubview:sub];
    y += 20 + 34;

    // 卡片
    CGFloat cardW = W - 40;
    CGFloat cardH = 300;
    GODCard *card = [[GODCard alloc] initWithFrame:CGRectMake(20, y, cardW, cardH)];
    [scroll addSubview:card];

    CGFloat cx = 20, cw = cardW - 40;
    CGFloat cy = 20;

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(cx, cy, cw, 22)];
    lbl.text = @"输入卡密";
    lbl.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    lbl.textColor = C_TEXT();
    [card addSubview:lbl];
    cy += 22 + 4;

    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(cx, cy, cw, 18)];
    hint.text = @"格式 XXXX-XXXX-XXXX-XXXX";
    hint.font = [UIFont systemFontOfSize:12];
    hint.textColor = C_MUTED();
    [card addSubview:hint];
    cy += 18 + 16;

    // 输入框
    UIView *fieldBox = [[UIView alloc] initWithFrame:CGRectMake(cx, cy, cw, 50)];
    fieldBox.backgroundColor = [C_BASE() colorWithAlphaComponent:0.6];
    fieldBox.layer.cornerRadius = 12;
    fieldBox.layer.borderWidth = 1;
    fieldBox.layer.borderColor = C_HAIR().CGColor;
    [card addSubview:fieldBox];

    UIImageView *keyIcon = [[UIImageView alloc] initWithFrame:CGRectMake(12, 17, 16, 16)];
    keyIcon.image = [UIImage systemImageNamed:@"key.fill"];
    keyIcon.tintColor = C_MUTED();
    [fieldBox addSubview:keyIcon];

    self.countLabel = [[UILabel alloc] initWithFrame:CGRectMake(cw - 66, 16, 54, 18)];
    self.countLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightSemibold];
    self.countLabel.textColor = [C_WARN() colorWithAlphaComponent:0.55];
    self.countLabel.textAlignment = NSTextAlignmentRight;
    self.countLabel.text = @"0/24";
    [fieldBox addSubview:self.countLabel];

    self.field = [[UITextField alloc] initWithFrame:CGRectMake(36, 0, cw - 36 - 72, 50)];
    self.field.font = [UIFont fontWithName:@"Menlo" size:15] ?: [UIFont systemFontOfSize:15];
    self.field.textColor = C_TEXT();
    self.field.attributedPlaceholder =
        [[NSAttributedString alloc] initWithString:@"粘贴或输入卡密"
            attributes:@{ NSForegroundColorAttributeName: C_MUTED(),
                          NSFontAttributeName: self.field.font }];
    self.field.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.field.autocorrectionType = UITextAutocorrectionTypeNo;
    self.field.keyboardType = UIKeyboardTypeASCIICapable;
    self.field.returnKeyType = UIReturnKeyGo;
    self.field.delegate = self;
    [self.field addTarget:self action:@selector(textChanged) forControlEvents:UIControlEventEditingChanged];
    [fieldBox addSubview:self.field];
    cy += 50 + 16;

    // 主按钮
    self.btn = [[GODGradientButton alloc] initWithFrame:CGRectMake(cx, cy, cw, 50)];
    [self.btn setTitle:@"开始验证" forState:UIControlStateNormal];
    [self.btn addTarget:self action:@selector(startVerify) forControlEvents:UIControlEventTouchUpInside];
    self.btn.enabled = NO;
    self.btn.alpha = 0.5;
    [card addSubview:self.btn];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.color = [UIColor whiteColor];
    self.spinner.frame = CGRectMake(cx + 20, cy + 15, 20, 20);
    self.spinner.hidesWhenStopped = YES;
    [card addSubview:self.spinner];
    cy += 50 + 12;

    self.errorLabel = [[UILabel alloc] initWithFrame:CGRectMake(cx, cy, cw, 18)];
    self.errorLabel.font = [UIFont systemFontOfSize:12];
    self.errorLabel.textColor = C_BAD();
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.hidden = YES;
    [card addSubview:self.errorLabel];
    cy += 18 + 14;

    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(cx, cy, cw, 0.5)];
    line.backgroundColor = C_HAIR();
    [card addSubview:line];
    cy += 0.5 + 12;

    UILabel *foot = [[UILabel alloc] initWithFrame:CGRectMake(cx, cy, cw, 32)];
    foot.text = @"授权仅绑定当前设备，换机需重新验证";
    foot.font = [UIFont systemFontOfSize:12];
    foot.textColor = C_MUTED();
    foot.numberOfLines = 0;
    [card addSubview:foot];

    scroll.contentSize = CGSizeMake(W, y + cardH + S6);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.field becomeFirstResponder];
}

#pragma mark 输入

- (BOOL)textField:(UITextField *)tf shouldChangeCharactersInRange:(NSRange)r replacementString:(NSString *)s {
    NSMutableString *raw = [tf.text mutableCopy] ?: [NSMutableString string];
    [raw replaceCharactersInRange:r withString:s];
    NSString *clean = [[raw uppercaseString] stringByReplacingOccurrencesOfString:@"[^A-Z0-9]" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, raw.length)];
    if (clean.length > 16) clean = [clean substringToIndex:16];
    NSMutableString *fmt = [NSMutableString string];
    for (NSUInteger i = 0; i < clean.length; i++) {
        if (i > 0 && i % 4 == 0) [fmt appendString:@"-"];
        [fmt appendFormat:@"%C", [clean characterAtIndex:i]];
    }
    tf.text = fmt;
    [self textChanged];
    return NO;
}

- (void)textChanged {
    NSUInteger n = [self digitsOnly].length;
    self.countLabel.text = [NSString stringWithFormat:@"%lu/16", (unsigned long)n];
    self.countLabel.textColor = (n == 16) ? C_WARN() : [C_WARN() colorWithAlphaComponent:0.55];
    BOOL ready = (n == 16) && !self.busy;
    self.btn.enabled = ready;
    self.btn.alpha = ready ? 1.0 : 0.5;
}

- (NSString *)digitsOnly {
    return [[[self.field.text uppercaseString] componentsSeparatedByCharactersInSet:
             [[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@""];
}

- (BOOL)textFieldShouldReturn:(UITextField *)tf {
    if (self.btn.enabled) [self startVerify];
    return YES;
}

#pragma mark 验证

- (void)startVerify {
    if (self.busy) return;
    NSString *card = self.field.text;
    self.busy = YES;
    self.errorLabel.hidden = YES;
    [self.btn setTitle:@"正在验证…" forState:UIControlStateNormal];
    self.btn.enabled = NO;
    self.btn.alpha = 0.6;
    [self.spinner startAnimating];
    [self.field resignFirstResponder];

    [GODNet verifyCard:card completion:^(BOOL ok, NSData *file, NSString *err) {
        self.busy = NO;
        [self.spinner stopAnimating];
        [self.btn setTitle:@"开始验证" forState:UIControlStateNormal];
        [self textChanged];

        if (ok) {
            [[NSUserDefaults standardUserDefaults] setObject:card forKey:kStoreCard];
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kStoreLicense];
            [[NSUserDefaults standardUserDefaults] synchronize];
            if (file) {
                NSString *p = [NSTemporaryDirectory() stringByAppendingPathComponent:@"god.lua"];
                [file writeToFile:p atomically:YES];
            }
            [self dismissViewControllerAnimated:YES completion:nil];
        } else {
            self.errorLabel.text = err ?: @"验证失败";
            self.errorLabel.hidden = NO;
        }
    }];
}

@end

#pragma mark - 控制台

@interface GODRow : UIView
@property (nonatomic, strong) UILabel *name;
@property (nonatomic, strong) UILabel *value;
@property (nonatomic, strong) UIView *line;
@end

@implementation GODRow
- (instancetype)init {
    if ((self = [super init])) {
        _name = [[UILabel alloc] init];
        _name.font = [UIFont systemFontOfSize:15];
        _name.textColor = C_TEXT();
        [self addSubview:_name];

        _value = [[UILabel alloc] init];
        _value.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        _value.textColor = C_MUTED();
        _value.textAlignment = NSTextAlignmentRight;
        [self addSubview:_value];

        _line = [[UIView alloc] init];
        _line.backgroundColor = C_HAIR();
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

@interface GODInjectViewController : UIViewController
@property (nonatomic, strong) UILabel *dot;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) GODRow *rowAccess, *rowGroup, *rowGame, *rowCard;
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, strong) GODGradientButton *btnSetup, *btnStart;
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, copy) NSString *container;
@end

@implementation GODInjectViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = C_BASE();
    [self.navigationController setNavigationBarHidden:YES animated:NO];

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scroll.contentInset = UIEdgeInsetsMake(0, 0, 100, 0);
    [self.view addSubview:scroll];

    CGFloat W = self.view.bounds.size.width;
    CGFloat y = 0;

    // 顶栏
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, 92)];
    [scroll addSubview:header];

    GODMark *mark = [[GODMark alloc] initWithFrame:CGRectMake(S3, 46, 32, 32)];
    [header addSubview:mark];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(S3 + 32 + 10, 44, 220, 20)];
    title.text = @"GOD 注入器";
    title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    title.textColor = C_TEXT();
    [header addSubview:title];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(S3 + 32 + 10, 65, 260, 16)];
    sub.text = @"就绪";
    sub.font = [UIFont systemFontOfSize:12];
    sub.textColor = C_MUTED();
    [header addSubview:sub];

    self.dot = [[UILabel alloc] initWithFrame:CGRectMake(W - S3 - 56, 50, 8, 8)];
    self.dot.backgroundColor = C_MUTED();
    self.dot.layer.cornerRadius = 4;
    self.dot.clipsToBounds = YES;
    [header addSubview:self.dot];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(W - S3 - 44, 44, 44, 20)];
    self.statusLabel.text = @"待机";
    self.statusLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.statusLabel.textColor = C_MUTED();
    self.statusLabel.textAlignment = NSTextAlignmentRight;
    [header addSubview:self.statusLabel];

    UIView *hl = [[UIView alloc] initWithFrame:CGRectMake(0, 91.5, W, 0.5)];
    hl.backgroundColor = C_HAIR();
    [header addSubview:hl];

    y = 92 + S4;
    CGFloat cw = W - S3 * 2;

    // 状态
    [scroll addSubview:[self head:@"状态" y:y w:cw]];
    y += 16 + S2;
    GODCard *stateCard = [[GODCard alloc] initWithFrame:CGRectMake(S3, y, cw, ROW_H * 4)];
    stateCard.layer.cornerRadius = 16;
    self.rowCard   = [self row:@"授权状态" value:@"已验证" card:stateCard idx:0];
    self.rowCard.value.textColor = C_GOOD();
    self.rowAccess = [self row:@"沙盒访问" value:@"未检查" card:stateCard idx:1];
    self.rowGroup  = [self row:@"App Group" value:@"未检查" card:stateCard idx:2];
    self.rowGame   = [self row:@"游戏容器" value:@"未检查" card:stateCard idx:3];
    self.rowGame.line.hidden = YES;
    [scroll addSubview:stateCard];
    y += stateCard.bounds.size.height + S4;

    // 日志
    [scroll addSubview:[self head:@"运行日志" y:y w:cw]];
    y += 16 + S2;
    GODCard *logCard = [[GODCard alloc] initWithFrame:CGRectMake(S3, y, cw, 250)];
    logCard.layer.cornerRadius = 16;
    logCard.backgroundColor = [UIColor colorWithRed:0.976 green:0.984 blue:0.996 alpha:1];
    self.logView = [[UITextView alloc] initWithFrame:CGRectMake(S3, S3, cw - S3 * 2, 250 - S3 * 2)];
    self.logView.backgroundColor = [UIColor clearColor];
    self.logView.textColor = C_MUTED();
    self.logView.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    self.logView.editable = NO;
    self.logView.textContainerInset = UIEdgeInsetsZero;
    self.logView.textContainer.lineFragmentPadding = 0;
    [logCard addSubview:self.logView];
    [scroll addSubview:logCard];
    y += logCard.bounds.size.height + S5;

    scroll.contentSize = CGSizeMake(W, y);

    // 底栏
    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 92, W, 92)];
    bar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    bar.backgroundColor = C_BASE();
    UIView *bl = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, 0.5)];
    bl.backgroundColor = C_HAIR();
    [bar addSubview:bl];

    CGFloat bw = (W - S3 * 2 - S2) / 2;
    self.btnSetup = [[GODGradientButton alloc] initWithFrame:CGRectMake(S3, S3 + 6, bw, 50)];
    [self.btnSetup setTitle:@"初始化" forState:UIControlStateNormal];
    [self.btnSetup addTarget:self action:@selector(onInit) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:self.btnSetup];

    self.btnStart = [[GODGradientButton alloc] initWithFrame:CGRectMake(S3 + bw + S2, S3 + 6, bw, 50)];
    [self.btnStart setTitle:@"开始注入" forState:UIControlStateNormal];
    [self.btnStart addTarget:self action:@selector(onStart) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:self.btnStart];

    [self.view addSubview:bar];
    [self log:@"已授权，点「初始化」检查环境"];
}

- (UILabel *)head:(NSString *)t y:(CGFloat)y w:(CGFloat)w {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(S3, y, w, 16)];
    l.text = t;
    l.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    l.textColor = C_MUTED();
    return l;
}

- (GODRow *)row:(NSString *)n value:(NSString *)v card:(UIView *)c idx:(NSInteger)i {
    GODRow *r = [[GODRow alloc] initWithFrame:CGRectMake(0, ROW_H * i, c.bounds.size.width, ROW_H)];
    r.name.text = n;
    r.value.text = v;
    r.line.hidden = (i == 3);
    [c addSubview:r];
    return r;
}

- (void)log:(NSString *)fmt, ... {
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"HH:mm:ss";
        self.logView.text = [self.logView.text stringByAppendingFormat:@"%@  %@\n",
                             [df stringFromDate:[NSDate date]], s];
        [self.logView scrollRangeToVisible:NSMakeRange(self.logView.text.length, 0)];
    });
}

- (void)setStatus:(NSString *)t color:(UIColor *)c {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = t;
        self.statusLabel.textColor = c;
        self.dot.backgroundColor = c;
    });
}

- (void)setRow:(GODRow *)r ok:(BOOL)ok text:(NSString *)t {
    dispatch_async(dispatch_get_main_queue(), ^{
        r.value.text = t;
        r.value.textColor = ok ? C_GOOD() : C_BAD();
    });
}

- (void)setBusy:(BOOL)b {
    _busy = b;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.btnSetup.enabled = !b;
        self.btnStart.enabled = !b;
        self.btnSetup.alpha = b ? 0.5 : 1;
        self.btnStart.alpha = b ? 0.5 : 1;
    });
}

- (void)onInit {
    if (self.busy) return;
    self.busy = YES;
    [self setStatus:@"检查中" color:C_WARN()];
    [self log:@"检查环境…"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *g = wq_app_group();
        [self setRow:self.rowGroup ok:(g != nil) text:(g ? @"已获取" : @"无")];

        struct stat st;
        BOOL canStat = wq_stat(@"/var/mobile/Containers/Data/Application", &st) && S_ISDIR(st.st_mode);
        NSArray *list = canStat ? wq_enumerate(@"/var/mobile/Containers/Data/Application", 0, nil, nil) : nil;
        BOOL ok = list.count > 0;
        [self setRow:self.rowAccess ok:ok text:(ok ? [NSString stringWithFormat:@"%lu 容器", (unsigned long)list.count] : @"不可用")];

        NSString *found = nil;
        for (NSString *d in list) {
            NSString *l = wq_container_label(d);
            if (l && [l isEqualToString:kGameBundleID]) { found = d; break; }
        }
        self.container = found;
        [self setRow:self.rowGame ok:(found != nil) text:(found ? @"已定位" : @"未找到")];
        [self log:ok ? [NSString stringWithFormat:@"沙盒可用（%lu 容器）", (unsigned long)list.count] : @"沙盒不可用"];
        if (found) [self log:found];

        BOOL all = ok && found && g;
        [self setStatus:all ? @"就绪" : @"异常" color:all ? C_GOOD() : C_BAD()];
        self.busy = NO;
    });
}

- (void)onStart {
    if (self.busy) return;
    NSString *card = [[NSUserDefaults standardUserDefaults] stringForKey:kStoreCard];
    if (card.length == 0) { [self log:@"无卡密记录"]; return; }
    self.busy = YES;
    [self setStatus:@"下载中" color:C_WARN()];
    [self log:@"开始注入…"];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *c = self.container;
        if (!c) {
            for (NSString *d in wq_enumerate(@"/var/mobile/Containers/Data/Application", 0, nil, nil)) {
                NSString *l = wq_container_label(d);
                if (l && [l isEqualToString:kGameBundleID]) { c = d; break; }
            }
        }
        if (!c) { [self log:@"未找到容器"]; [self setStatus:@"失败" color:C_BAD()]; self.busy = NO; return; }
        self.container = c;

        for (NSString *p in @[@"Documents", @"DeltaForce", @"Saved", @"LuaDebug", @"LuaSource", @"DFM", @"BusinessEntrance"]) {
            c = [c stringByAppendingPathComponent:p];
            struct stat st;
            if (wq_stat(c, &st) && S_ISDIR(st.st_mode)) continue;
            NSString *err = nil;
            if (!wq_create_dir(c, &err)) { [self log:[NSString stringWithFormat:@"建目录失败 %@", p]]; [self setStatus:@"失败" color:C_BAD()]; self.busy = NO; return; }
        }

        [GODNet verifyCard:card completion:^(BOOL ok, NSData *file, NSString *err) {
            if (!ok) { [self log:[NSString stringWithFormat:@"下载失败：%@", err ?: @""]]; [self setStatus:@"失败" color:C_BAD()]; self.busy = NO; return; }
            NSString *dest = [c stringByAppendingPathComponent:@"EntranceFlow.lua"];
            struct stat st;
            if (wq_stat(dest, &st)) {
                NSData *old = wq_read(dest, 0, NULL);
                if (old) wq_write([dest stringByAppendingString:@".bak"], old, NULL);
            }
            NSString *werr = nil;
            BOOL w = wq_stat(dest, &st) ? wq_write(dest, file, &werr) : wq_create_file(dest, file, &werr);
            [self log:w ? [NSString stringWithFormat:@"写入成功 %lu KB", (unsigned long)(file.length / 1024)] : [NSString stringWithFormat:@"写入失败 %@", werr ?: @""]];
            [self setStatus:w ? @"完成" : @"失败" color:w ? C_GOOD() : C_BAD()];
            self.busy = NO;
        }];
    });
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
    if (@available(iOS 13.0, *)) self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;

    BOOL licensed = [[NSUserDefaults standardUserDefaults] boolForKey:kStoreLicense];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[[GODInjectViewController alloc] init]];
    [nav setNavigationBarHidden:YES animated:NO];
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];

    if (!licensed) {
        GODLicenseViewController *lic = [[GODLicenseViewController alloc] init];
        lic.modalPresentationStyle = UIModalPresentationFullScreen;
        [nav presentViewController:lic animated:NO completion:nil];
    }
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, @"GODAppDelegate");
    }
}