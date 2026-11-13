//
//  main.m — GOD 注入器
//  布局照 Phoenix 原生主界面（preview-now.png 右栏）
//  两段式：激活页 → 控制台
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

#pragma mark - 令牌（现版 · 青蓝 + 极光紫）

static UIColor *C_BG(void)     { return [UIColor colorWithRed:0.039 green:0.059 blue:0.078 alpha:1]; } // #0a0f14
static UIColor *C_CARD(void)   { return [UIColor colorWithRed:0.078 green:0.102 blue:0.125 alpha:1]; } // #141a20
static UIColor *C_CARD2(void)  { return [UIColor colorWithRed:0.055 green:0.075 blue:0.098 alpha:1]; } // #0e1319
static UIColor *C_TEXT(void)   { return [UIColor colorWithRed:0.910 green:0.941 blue:0.973 alpha:1]; } // #e8f0f8
static UIColor *C_MUTED(void)  { return [UIColor colorWithRed:0.490 green:0.545 blue:0.600 alpha:1]; } // #7d8b99
static UIColor *C_CYAN(void)   { return [UIColor colorWithRed:0.490 green:0.827 blue:0.988 alpha:1]; } // #7dd3fc
static UIColor *C_VIOLET(void) { return [UIColor colorWithRed:0.655 green:0.545 blue:0.980 alpha:1]; } // #a78bfa
static UIColor *C_GOOD(void)   { return [UIColor colorWithRed:0.239 green:0.863 blue:0.592 alpha:1]; } // #3ddc97
static UIColor *C_WARN(void)   { return [UIColor colorWithRed:1.000 green:0.761 blue:0.294 alpha:1]; } // #ffc24b
static UIColor *C_BAD(void)    { return [UIColor colorWithRed:1.000 green:0.365 blue:0.424 alpha:1]; } // #ff5d6c
static UIColor *C_LINE(void)   { return [[UIColor whiteColor] colorWithAlphaComponent:0.07]; }

static const CGFloat S1 = 4, S2 = 8, S3 = 16, S4 = 24, S5 = 32, S6 = 40;
static const CGFloat ROW_H = 46;
static const CGFloat R_CARD = 16;
static const CGFloat R_BTN = 12;

#pragma mark - 渐变按钮

@interface GODGradButton : UIButton
@end
@implementation GODGradButton { CAGradientLayer *_g; }
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        _g = [CAGradientLayer layer];
        _g.colors = @[(id)C_CYAN().CGColor, (id)C_VIOLET().CGColor];
        _g.startPoint = CGPointMake(0, 0.5);
        _g.endPoint = CGPointMake(1, 0.5);
        _g.cornerRadius = R_BTN;
        [self.layer insertSublayer:_g atIndex:0];
        self.layer.cornerRadius = R_BTN;
        self.clipsToBounds = YES;
        self.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        [self setTitleColor:[UIColor colorWithRed:0.04 green:0.05 blue:0.08 alpha:1] forState:UIControlStateNormal];
        [self setTitleColor:[[UIColor colorWithRed:0.04 green:0.05 blue:0.08 alpha:1] colorWithAlphaComponent:0.45]
                   forState:UIControlStateDisabled];
    }
    return self;
}
- (void)layoutSubviews { [super layoutSubviews]; _g.frame = self.bounds; }
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
        self.layer.borderColor = C_LINE().CGColor;
    }
    return self;
}
- (void)layoutSubviews { [super layoutSubviews]; self.layer.borderColor = C_LINE().CGColor; }
@end

#pragma mark - 状态行（圆点 + 标签 + 值）

@interface GODStatusRow : UIView
@property (nonatomic, strong) UIView *dot;
@property (nonatomic, strong) UILabel *name;
@property (nonatomic, strong) UILabel *value;
@property (nonatomic, strong) UIView *line;
@end

@implementation GODStatusRow
- (instancetype)init {
    if ((self = [super init])) {
        _dot = [[UIView alloc] initWithFrame:CGRectMake(S3, 0, 6, 6)];
        _dot.layer.cornerRadius = 3;
        _dot.backgroundColor = C_MUTED();
        [self addSubview:_dot];

        _name = [[UILabel alloc] init];
        _name.font = [UIFont systemFontOfSize:14];
        _name.textColor = C_TEXT();
        [self addSubview:_name];

        _value = [[UILabel alloc] init];
        _value.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
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
    _dot.frame = CGRectMake(S3, (h - 6) / 2, 6, 6);
    [_value sizeToFit];
    CGFloat vw = MIN(_value.bounds.size.width, w * 0.5);
    _value.frame = CGRectMake(w - S3 - vw, 0, vw, h);
    _name.frame = CGRectMake(S3 + 6 + 10, 0, w - S3 * 2 - 16 - vw - S2, h);
    _line.frame = CGRectMake(S3, h - 0.5, w - S3 * 2, 0.5);
}
@end

#pragma mark - 胶囊标签

@interface GODPill : UILabel
@end
@implementation GODPill
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        self.textColor = C_MUTED();
        self.textAlignment = NSTextAlignmentCenter;
        self.layer.cornerRadius = 13;
        self.layer.borderWidth = 1;
        self.layer.borderColor = C_LINE().CGColor;
        self.backgroundColor = [UIColor colorWithWhite:1 alpha:0.03];
        self.clipsToBounds = YES;
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
    NSString *u = [NSString stringWithFormat:@"%@%@?card=%@", kServerBase, kDownloadPath, enc];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:u]];
    req.timeoutInterval = 15;
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
        NSString *msg = [NSString stringWithFormat:@"HTTP %ld", (long)code];
        if (d.length > 0 && d.length < 4096) {
            NSDictionary *j = [NSJSONSerialization JSONObjectWithData:d options:0 error:NULL];
            if ([j isKindOfClass:[NSDictionary class]]) {
                NSString *err = j[@"error"];
                if ([err isEqualToString:@"card_not_found"])    msg = @"卡密不存在";
                else if ([err isEqualToString:@"card_revoked"]) msg = @"卡密已被封禁";
                else if ([err isEqualToString:@"card_expired"]) msg = @"卡密已过期";
                else if ([err isEqualToString:@"card_format"])  msg = @"卡密格式不正确";
                else if (err.length)                            msg = err;
                else msg = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] ?: msg;
            } else {
                msg = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] ?: msg;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{ done(NO, nil, msg); });
    }] resume];
}
@end

#pragma mark - 激活页

@interface GODLicenseViewController : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *field;
@property (nonatomic, strong) UILabel *count;
@property (nonatomic, strong) GODGradButton *btn;
@property (nonatomic, strong) UILabel *error;
@property (nonatomic, strong) UIActivityIndicatorView *spin;
@property (nonatomic, assign) BOOL busy;
@end

@implementation GODLicenseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = C_BG();

    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    sv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:sv];

    CGFloat W = self.view.bounds.size.width;
    CGFloat cw = W - S3 * 2;
    CGFloat y = 56;

    // STEP 标记
    UILabel *step = [[UILabel alloc] initWithFrame:CGRectMake(S3, y, cw, 16)];
    step.text = @"STEP 1 · 激活";
    step.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    step.textColor = C_CYAN();
    [sv addSubview:step];
    y += 16 + S2;

    // 标题
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(S3, y, cw, 34)];
    title.text = @"输入卡密开始";
    title.font = [UIFont systemFontOfSize:26 weight:UIFontWeightBold];
    title.textColor = C_TEXT();
    [sv addSubview:title];
    y += 34 + 6;

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(S3, y, cw, 36)];
    sub.text = @"卡密只在本机校验，注入文件由服务器下发。";
    sub.font = [UIFont systemFontOfSize:13];
    sub.textColor = C_MUTED();
    sub.numberOfLines = 2;
    [sv addSubview:sub];
    y += 36 + 14;

    // 胶囊
    GODPill *p1 = [[GODPill alloc] initWithFrame:CGRectMake(S3, y, 84, 26)];
    p1.text = @"剩余 30 天";
    [sv addSubview:p1];
    GODPill *p2 = [[GODPill alloc] initWithFrame:CGRectMake(S3 + 84 + 8, y, 92, 26)];
    p2.text = @"已绑定本机";
    [sv addSubview:p2];
    y += 26 + S4;

    // 运行状态
    UILabel *st = [[UILabel alloc] initWithFrame:CGRectMake(S3, y, cw, 16)];
    st.text = @"运行状态";
    st.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    st.textColor = C_MUTED();
    [sv addSubview:st];
    y += 16 + S2;

    GODCard *stCard = [[GODCard alloc] initWithFrame:CGRectMake(S3, y, cw, 40 * 3)];
    [sv addSubview:stCard];
    [self statusRow:@"本机引擎" value:@"运行中" dot:C_GOOD() card:stCard idx:0 n:3];
    [self statusRow:@"坐标流" value:@"待连接" dot:C_MUTED() card:stCard idx:1 n:3];
    [self statusRow:@"卡密有效期" value:@"—" dot:C_MUTED() card:stCard idx:2 n:3];
    y += stCard.bounds.size.height + S4;

    // 卡密输入
    UILabel *ct = [[UILabel alloc] initWithFrame:CGRectMake(S3, y, cw, 16)];
    ct.text = @"卡密";
    ct.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    ct.textColor = C_MUTED();
    [sv addSubview:ct];
    y += 16 + S2;

    GODCard *fieldCard = [[GODCard alloc] initWithFrame:CGRectMake(S3, y, cw, 52)];
    fieldCard.layer.cornerRadius = R_BTN;
    self.field = [[UITextField alloc] initWithFrame:CGRectMake(S3, 0, cw - S3 * 2 - 50, 52)];
    self.field.font = [UIFont fontWithName:@"Menlo" size:15] ?: [UIFont systemFontOfSize:15];
    self.field.textColor = C_TEXT();
    self.field.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:@"XXXX-XXXX-XXXX-XXXX"
            attributes:@{ NSForegroundColorAttributeName: [C_MUTED() colorWithAlphaComponent:0.7],
                          NSFontAttributeName: self.field.font }];
    self.field.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.field.autocorrectionType = UITextAutocorrectionTypeNo;
    self.field.keyboardType = UIKeyboardTypeASCIICapable;
    self.field.returnKeyType = UIReturnKeyGo;
    self.field.delegate = self;
    [self.field addTarget:self action:@selector(changed) forControlEvents:UIControlEventEditingChanged];
    [fieldCard addSubview:self.field];

    self.count = [[UILabel alloc] initWithFrame:CGRectMake(cw - 54, 17, 38, 18)];
    self.count.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightMedium];
    self.count.textColor = C_MUTED();
    self.count.textAlignment = NSTextAlignmentRight;
    self.count.text = @"0/16";
    [fieldCard addSubview:self.count];
    [sv addSubview:fieldCard];
    y += 52 + S3;

    // 主按钮
    self.btn = [[GODGradButton alloc] initWithFrame:CGRectMake(S3, y, cw, 50)];
    [self.btn setTitle:@"激活并进入" forState:UIControlStateNormal];
    [self.btn addTarget:self action:@selector(go) forControlEvents:UIControlEventTouchUpInside];
    self.btn.enabled = NO;
    self.btn.alpha = 0.45;
    [sv addSubview:self.btn];
    y += 50 + S2;

    self.spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spin.color = C_TEXT();
    self.spin.frame = CGRectMake(S3 + 16, y - 50 + 13, 22, 22);
    self.spin.hidesWhenStopped = YES;
    [sv addSubview:self.spin];

    self.error = [[UILabel alloc] initWithFrame:CGRectMake(S3, y, cw, 16)];
    self.error.font = [UIFont systemFontOfSize:12];
    self.error.textColor = C_BAD();
    self.error.hidden = YES;
    [sv addSubview:self.error];
    y += 16 + S4;

    // 底部说明卡
    GODCard *tip = [[GODCard alloc] initWithFrame:CGRectMake(S3, y, cw, 74)];
    tip.backgroundColor = C_CARD2();
    UIImageView *ic = [[UIImageView alloc] initWithFrame:CGRectMake(S3, 18, 20, 20)];
    ic.image = [UIImage systemImageNamed:@"lock.shield"];
    ic.tintColor = C_CYAN();
    [tip addSubview:ic];

    UILabel *tt = [[UILabel alloc] initWithFrame:CGRectMake(S3 + 20 + 10, 16, cw - 66, 20)];
    tt.text = @"授权只绑定当前设备";
    tt.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    tt.textColor = C_TEXT();
    [tip addSubview:tt];

    UILabel *td = [[UILabel alloc] initWithFrame:CGRectMake(S3 + 20 + 10, 36, cw - 66, 32)];
    td.text = @"换机需要重新验证，卡密不落盘明文之外的位置";
    td.font = [UIFont systemFontOfSize:12];
    td.textColor = C_MUTED();
    td.numberOfLines = 2;
    [tip addSubview:td];
    [sv addSubview:tip];
    y += 74 + S6;

    sv.contentSize = CGSizeMake(W, y);
}

- (void)statusRow:(NSString *)n value:(NSString *)v dot:(UIColor *)dc card:(UIView *)c idx:(NSInteger)i n:(NSInteger)total {
    GODStatusRow *r = [[GODStatusRow alloc] initWithFrame:CGRectMake(0, 40 * i, c.bounds.size.width, 40)];
    r.name.text = n;
    r.value.text = v;
    r.dot.backgroundColor = dc;
    r.line.hidden = (i == total - 1);
    [c addSubview:r];
}

- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; [self.field becomeFirstResponder]; }

- (BOOL)textField:(UITextField *)tf shouldChangeCharactersInRange:(NSRange)r replacementString:(NSString *)s {
    NSMutableString *raw = [tf.text mutableCopy] ?: [NSMutableString string];
    [raw replaceCharactersInRange:r withString:s];
    NSString *up = [raw uppercaseString];
    NSMutableString *clean = [NSMutableString string];
    for (NSUInteger i = 0; i < up.length; i++) {
        unichar c = [up characterAtIndex:i];
        if ((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) [clean appendFormat:@"%C", c];
    }
    if (clean.length > 16) clean = [[clean substringToIndex:16] mutableCopy];
    NSMutableString *fmt = [NSMutableString string];
    for (NSUInteger i = 0; i < clean.length; i++) {
        if (i > 0 && i % 4 == 0) [fmt appendString:@"-"];
        [fmt appendFormat:@"%C", [clean characterAtIndex:i]];
    }
    tf.text = fmt;
    [self changed];
    return NO;
}

- (void)changed {
    NSUInteger n = [self alnum].length;
    self.count.text = [NSString stringWithFormat:@"%lu/16", (unsigned long)n];
    self.count.textColor = (n == 16) ? C_CYAN() : C_MUTED();
    BOOL ready = (n == 16) && !self.busy;
    self.btn.enabled = ready;
    self.btn.alpha = ready ? 1.0 : 0.45;
}

- (NSString *)alnum {
    NSMutableString *m = [NSMutableString string];
    NSString *t = [self.field.text uppercaseString];
    for (NSUInteger i = 0; i < t.length; i++) {
        unichar c = [t characterAtIndex:i];
        if ((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) [m appendFormat:@"%C", c];
    }
    return m;
}

- (BOOL)textFieldShouldReturn:(UITextField *)tf { if (self.btn.enabled) [self go]; return YES; }

- (void)go {
    if (self.busy) return;
    NSString *card = self.field.text;
    self.busy = YES;
    self.error.hidden = YES;
    [self.btn setTitle:@"校验中…" forState:UIControlStateNormal];
    self.btn.enabled = NO;
    self.btn.alpha = 0.6;
    [self.spin startAnimating];
    [self.field resignFirstResponder];

    [GODNet verifyCard:card completion:^(BOOL ok, NSData *file, NSString *err) {
        self.busy = NO;
        [self.spin stopAnimating];
        [self.btn setTitle:@"激活并进入" forState:UIControlStateNormal];
        [self changed];
        if (ok) {
            [[NSUserDefaults standardUserDefaults] setObject:card forKey:kStoreCard];
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kStoreLicense];
            [[NSUserDefaults standardUserDefaults] synchronize];
            if (file) [file writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"god.lua"] atomically:YES];
            [self dismissViewControllerAnimated:YES completion:nil];
        } else {
            self.error.text = err ?: @"验证失败";
            self.error.hidden = NO;
        }
    }];
}

@end

#pragma mark - 控制台

@interface GODRow : UIView
@property (nonatomic, strong) UILabel *name, *value;
@property (nonatomic, strong) UIView *line;
@end
@implementation GODRow
- (instancetype)init {
    if ((self = [super init])) {
        _name = [[UILabel alloc] init];
        _name.font = [UIFont systemFontOfSize:14];
        _name.textColor = C_TEXT();
        [self addSubview:_name];
        _value = [[UILabel alloc] init];
        _value.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
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

@interface GODInjectViewController : UIViewController
@property (nonatomic, strong) UILabel *dot, *stLabel;
@property (nonatomic, strong) GODRow *rAuth, *rAccess, *rGroup, *rGame;
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, strong) GODGradButton *bSetup, *bStart;
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, copy) NSString *container;
@end

@implementation GODInjectViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = C_BG();
    [self.navigationController setNavigationBarHidden:YES animated:NO];

    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    sv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    sv.contentInset = UIEdgeInsetsMake(0, 0, 110, 0);
    [self.view addSubview:sv];

    CGFloat W = self.view.bounds.size.width;
    CGFloat cw = W - S3 * 2;
    CGFloat y = 54;

    // 顶栏
    UILabel *kicker = [[UILabel alloc] initWithFrame:CGRectMake(S3, y, cw, 16)];
    kicker.text = @"STEP 2 · 注入";
    kicker.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    kicker.textColor = C_CYAN();
    [sv addSubview:kicker];
    y += 16 + S2;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(S3, y, cw - 80, 34)];
    title.text = @"环境与注入";
    title.font = [UIFont systemFontOfSize:26 weight:UIFontWeightBold];
    title.textColor = C_TEXT();
    [sv addSubview:title];

    self.dot = [[UIView alloc] initWithFrame:CGRectMake(W - S3 - 52, y + 12, 6, 6)];
    self.dot.backgroundColor = C_MUTED();
    self.dot.layer.cornerRadius = 3;
    [sv addSubview:self.dot];

    self.stLabel = [[UILabel alloc] initWithFrame:CGRectMake(W - S3 - 42, y + 6, 42, 18)];
    self.stLabel.text = @"待机";
    self.stLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.stLabel.textColor = C_MUTED();
    self.stLabel.textAlignment = NSTextAlignmentRight;
    [sv addSubview:self.stLabel];
    y += 34 + 6;

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(S3, y, cw, 18)];
    sub.text = @"确认环境后一键写入游戏目录";
    sub.font = [UIFont systemFontOfSize:13];
    sub.textColor = C_MUTED();
    [sv addSubview:sub];
    y += 18 + S4;

    // 环境
    UILabel *envT = [[UILabel alloc] initWithFrame:CGRectMake(S3, y, cw, 16)];
    envT.text = @"运行状态";
    envT.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    envT.textColor = C_MUTED();
    [sv addSubview:envT];
    y += 16 + S2;

    GODCard *envCard = [[GODCard alloc] initWithFrame:CGRectMake(S3, y, cw, 40 * 4)];
    self.rAuth   = [self row:@"授权状态" value:@"已验证" card:envCard idx:0];
    self.rAuth.value.textColor = C_GOOD();
    self.rAccess = [self row:@"沙盒访问" value:@"未检查" card:envCard idx:1];
    self.rGroup  = [self row:@"App Group" value:@"未检查" card:envCard idx:2];
    self.rGame   = [self row:@"游戏容器" value:@"未检查" card:envCard idx:3];
    self.rGame.line.hidden = YES;
    [sv addSubview:envCard];
    y += envCard.bounds.size.height + S4;

    // 日志
    UILabel *logT = [[UILabel alloc] initWithFrame:CGRectMake(S3, y, cw, 16)];
    logT.text = @"运行日志";
    logT.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    logT.textColor = C_MUTED();
    [sv addSubview:logT];
    y += 16 + S2;

    GODCard *logCard = [[GODCard alloc] initWithFrame:CGRectMake(S3, y, cw, 240)];
    logCard.backgroundColor = C_CARD2();
    self.logView = [[UITextView alloc] initWithFrame:CGRectMake(S3, S3, cw - S3 * 2, 240 - S3 * 2)];
    self.logView.backgroundColor = [UIColor clearColor];
    self.logView.textColor = C_MUTED();
    self.logView.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    self.logView.editable = NO;
    self.logView.textContainerInset = UIEdgeInsetsZero;
    self.logView.textContainer.lineFragmentPadding = 0;
    [logCard addSubview:self.logView];
    [sv addSubview:logCard];
    y += logCard.bounds.size.height + S6;

    sv.contentSize = CGSizeMake(W, y);

    // 底栏
    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 96, W, 96)];
    bar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    bar.backgroundColor = C_BG();
    UIView *bl = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, 0.5)];
    bl.backgroundColor = C_LINE();
    [bar addSubview:bl];

    self.bSetup = [[GODGradButton alloc] initWithFrame:CGRectMake(S3, S3 + 4, (W - S3 * 2 - S2) / 2, 48)];
    [self.bSetup setTitle:@"初始化" forState:UIControlStateNormal];
    [self.bSetup addTarget:self action:@selector(onInit) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:self.bSetup];

    self.bStart = [[GODGradButton alloc] initWithFrame:CGRectMake(S3 + (W - S3 * 2 - S2) / 2 + S2, S3 + 4,
                                                                  (W - S3 * 2 - S2) / 2, 48)];
    [self.bStart setTitle:@"开始注入" forState:UIControlStateNormal];
    [self.bStart addTarget:self action:@selector(onStart) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:self.bStart];

    [self.view addSubview:bar];
    [self log:@"已授权，点「初始化」检查环境"];
}

- (GODRow *)row:(NSString *)n value:(NSString *)v card:(UIView *)c idx:(NSInteger)i {
    GODRow *r = [[GODRow alloc] initWithFrame:CGRectMake(0, 40 * i, c.bounds.size.width, 40)];
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
        self.stLabel.text = t;
        self.stLabel.textColor = c;
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
        self.bSetup.enabled = !b;
        self.bStart.enabled = !b;
        self.bSetup.alpha = b ? 0.5 : 1;
        self.bStart.alpha = b ? 0.5 : 1;
    });
}

- (void)onInit {
    if (self.busy) return;
    self.busy = YES;
    [self setStatus:@"检查中" color:C_WARN()];
    [self log:@"检查环境…"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *g = wq_app_group();
        [self setRow:self.rGroup ok:(g != nil) text:(g ? @"已获取" : @"无")];
        struct stat st;
        BOOL canStat = wq_stat(@"/var/mobile/Containers/Data/Application", &st) && S_ISDIR(st.st_mode);
        NSArray *list = canStat ? wq_enumerate(@"/var/mobile/Containers/Data/Application", 0, nil, nil) : nil;
        BOOL ok = list.count > 0;
        [self setRow:self.rAccess ok:ok text:(ok ? [NSString stringWithFormat:@"%lu 容器", (unsigned long)list.count] : @"不可用")];
        NSString *found = nil;
        for (NSString *d in list) {
            NSString *l = wq_container_label(d);
            if (l && [l isEqualToString:kGameBundleID]) { found = d; break; }
        }
        self.container = found;
        [self setRow:self.rGame ok:(found != nil) text:(found ? @"已定位" : @"未找到")];
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
            if (!wq_create_dir(c, NULL)) { [self log:[NSString stringWithFormat:@"建目录失败 %@", p]]; [self setStatus:@"失败" color:C_BAD()]; self.busy = NO; return; }
        }
        [GODNet verifyCard:card completion:^(BOOL ok, NSData *file, NSString *err) {
            if (!ok) { [self log:[NSString stringWithFormat:@"下载失败：%@", err ?: @""]]; [self setStatus:@"失败" color:C_BAD()]; self.busy = NO; return; }
            NSString *dest = [c stringByAppendingPathComponent:@"EntranceFlow.lua"];
            struct stat st;
            if (wq_stat(dest, &st)) {
                NSData *old = wq_read(dest, 0, NULL);
                if (old) wq_write([dest stringByAppendingString:@".bak"], old, NULL);
            }
            BOOL w = wq_stat(dest, &st) ? wq_write(dest, file, NULL) : wq_create_file(dest, file, NULL);
            [self log:w ? [NSString stringWithFormat:@"写入成功 %lu KB", (unsigned long)(file.length / 1024)] : @"写入失败"];
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
    if (@available(iOS 13.0, *)) self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;

    BOOL licensed = [[NSUserDefaults standardUserDefaults] boolForKey:kStoreLicense];
    UINavigationController *nav = [[UINavigationController alloc]
        initWithRootViewController:[[GODInjectViewController alloc] init]];
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