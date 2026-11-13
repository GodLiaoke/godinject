//
//  main.m — GOD 注入器
//  严格照 Phoenix CodeV 的 DESIGN.md 令牌与规则实现
//
//  规则要点：
//   · No-Kicker：标题上方不放小字标签
//   · Accent Is Not a Status：青蓝只给动作，状态只用信号灯三色
//   · Position-Not-Hue：状态同时用形状编码（实心圆/空心环/实心方）
//   · Monospace Means Machine：等宽字体只给机器值（卡密、容器路径）
//   · Wrap Not Truncate：状态文字只换行不省略
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
static NSString *const kBuildLine    = @"GODInject 1.0 · build 1";

#pragma mark - 令牌（DESIGN.md）

// Colors
static UIColor *C_BG(void)      { return [UIColor colorWithRed:0.024 green:0.031 blue:0.071 alpha:1]; } // #060812
static UIColor *C_PANEL(void)   { return [UIColor colorWithRed:0.059 green:0.075 blue:0.129 alpha:1]; } // #0F1321
static UIColor *C_RAISED(void)  { return [UIColor colorWithRed:0.078 green:0.094 blue:0.169 alpha:1]; } // #14182B
static UIColor *C_SECOND(void)  { return [UIColor colorWithRed:0.569 green:0.600 blue:0.690 alpha:1]; } // #9199B0
static UIColor *C_ACCENT(void)  { return [UIColor colorWithRed:0.361 green:0.784 blue:1.000 alpha:1]; } // #5CC8FF
static UIColor *C_GO(void)      { return [UIColor colorWithRed:0.204 green:0.851 blue:0.482 alpha:1]; } // #34D97B
static UIColor *C_WAIT(void)    { return [UIColor colorWithRed:1.000 green:0.702 blue:0.251 alpha:1]; } // #FFB340
static UIColor *C_FAULT(void)   { return [UIColor colorWithRed:1.000 green:0.420 blue:0.502 alpha:1]; } // #FF6B80
static UIColor *C_HAIR(void)    { return [[UIColor whiteColor] colorWithAlphaComponent:0.10]; }
static UIColor *C_TEXT(void)    { return [UIColor labelColor]; }

// Spacing（page-margin 18 / section-gap 14 / row-padding 9 / touch 44）
static const CGFloat M_PAGE = 18;
static const CGFloat M_SECTION = 14;
static const CGFloat M_ROW_PAD = 9;
static const CGFloat M_TOUCH = 44;

// Rounded（sheet 18 continuous / control 16 / pill capsule）
static const CGFloat R_SHEET = 18;
static const CGFloat R_CONTROL = 16;

#pragma mark - 字体（全走系统文字样式，跟随 Dynamic Type）

static UIFont *F_Display(void) { return [UIFont systemFontOfSize:34 weight:UIFontWeightBold]; }
static UIFont *F_Section(void) { return [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]; }
static UIFont *F_Status(void)  { return [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]; }
static UIFont *F_Body(void)    { return [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]; }
static UIFont *F_Caption(void) { return [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1]; }
static UIFont *F_Mono(void) {
    UIFont *b = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    return [UIFont monospacedSystemFontOfSize:b.pointSize weight:UIFontWeightSemibold];
}
static UIFont *F_Counter(void) {
    UIFont *b = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    UIFontDescriptor *d = [b.fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
    return [UIFont fontWithDescriptor:d size:b.pointSize];
}

#pragma mark - 状态灯（形状编码：实心圆 / 空心环 / 实心方）

typedef NS_ENUM(NSInteger, GODLampShape) {
    GODLampShapeDot,     // 实心圆 —— signal-go
    GODLampShapeRing,    // 空心环 —— signal-wait
    GODLampShapeSquare,  // 实心方 —— signal-fault
};

@interface GODLamp : UIView
@property (nonatomic, assign) GODLampShape shape;
@property (nonatomic, strong) UIColor *tint;
@end

@implementation GODLamp
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = [UIColor clearColor];
        self.shape = GODLampShapeRing;
        self.tint = C_SECOND();
    }
    return self;
}
- (void)setShape:(GODLampShape)shape { _shape = shape; [self setNeedsDisplay]; }
- (void)setTint:(UIColor *)tint { _tint = tint; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)r {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat s = CGRectGetWidth(r);
    CGRect box = CGRectMake(0, 0, s, s);
    [self.tint setStroke];
    [self.tint setFill];
    switch (self.shape) {
        case GODLampShapeDot:
            CGContextFillEllipseInRect(c, box);
            break;
        case GODLampShapeRing:
            CGContextSetLineWidth(c, 1.5);
            CGContextStrokeEllipseInRect(c, CGRectInset(box, 0.75, 0.75));
            break;
        case GODLampShapeSquare:
            CGContextFillRect(c, box);
            break;
    }
}
@end

#pragma mark - 主按钮（accent 填充 / pill / 50pt）

@interface GODPrimaryButton : UIButton
@end
@implementation GODPrimaryButton
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = C_ACCENT();
        self.layer.cornerRadius = f.size.height / 2;
        self.titleLabel.font = F_Section();
        [self setTitleColor:C_BG() forState:UIControlStateNormal];
        [self setTitleColor:[C_BG() colorWithAlphaComponent:0.45] forState:UIControlStateDisabled];
    }
    return self;
}
- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    self.alpha = enabled ? 1.0 : 0.45;
}
@end

#pragma mark - 次要按钮（描边）

@interface GODSecondaryButton : UIButton
@end
@implementation GODSecondaryButton
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = [UIColor clearColor];
        self.layer.cornerRadius = f.size.height / 2;
        self.layer.borderWidth = 1;
        self.layer.borderColor = C_ACCENT().CGColor;
        self.titleLabel.font = F_Section();
        [self setTitleColor:C_ACCENT() forState:UIControlStateNormal];
        [self setTitleColor:[C_SECOND() colorWithAlphaComponent:0.5] forState:UIControlStateDisabled];
    }
    return self;
}
- (void)layoutSubviews { [super layoutSubviews]; self.layer.borderColor = C_ACCENT().CGColor; }
- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    self.alpha = enabled ? 1.0 : 0.45;
}
@end

#pragma mark - 分组面板

@interface GODPanel : UIView
@end
@implementation GODPanel
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = C_PANEL();
        self.layer.cornerRadius = R_SHEET;
        self.layer.borderWidth = 1;
        self.layer.borderColor = C_HAIR().CGColor;
    }
    return self;
}
- (void)layoutSubviews { [super layoutSubviews]; self.layer.borderColor = C_HAIR().CGColor; }
@end

#pragma mark - 清单行（灯 + 标签 + 机器值）

@interface GODLampRow : UIView
@property (nonatomic, strong) GODLamp *lamp;
@property (nonatomic, strong) UILabel *name;
@property (nonatomic, strong) UILabel *value;
@property (nonatomic, strong) UIView *line;
@end

@implementation GODLampRow
- (instancetype)init {
    if ((self = [super init])) {
        _lamp = [[GODLamp alloc] initWithFrame:CGRectMake(M_PAGE, 0, 9, 9)];
        [self addSubview:_lamp];

        _name = [[UILabel alloc] init];
        _name.font = F_Body();
        _name.textColor = C_TEXT();
        _name.numberOfLines = 0;
        [self addSubview:_name];

        _value = [[UILabel alloc] init];
        _value.font = F_Mono();
        _value.textColor = C_SECOND();
        _value.textAlignment = NSTextAlignmentRight;
        _value.numberOfLines = 1;
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
    _lamp.frame = CGRectMake(M_PAGE, (h - 9) / 2, 9, 9);
    [_value sizeToFit];
    CGFloat vw = MIN(_value.bounds.size.width, w * 0.52);
    _value.frame = CGRectMake(w - M_PAGE - vw, 0, vw, h);
    _name.frame = CGRectMake(M_PAGE + 9 + 10, 0, w - M_PAGE * 2 - 19 - vw - 8, h);
    _line.frame = CGRectMake(M_PAGE, h - 0.5, w - M_PAGE * 2, 0.5);
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
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{ done(NO, nil, msg); });
    }] resume];
}
@end

#pragma mark - 激活页

@interface GODLicenseViewController : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *field;
@property (nonatomic, strong) UILabel *counter;
@property (nonatomic, strong) GODPrimaryButton *btn;
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
    CGFloat cw = W - M_PAGE * 2;
    CGFloat y = 64;

    // 品牌标记（accent）
    UIView *mark = [[UIView alloc] initWithFrame:CGRectMake((W - 56) / 2, y, 56, 56)];
    mark.backgroundColor = C_ACCENT();
    mark.layer.cornerRadius = 16;
    UIImageView *ic = [[UIImageView alloc] initWithFrame:CGRectInset(mark.bounds, 14, 14)];
    ic.image = [UIImage systemImageNamed:@"shield.lefthalf.filled"];
    ic.tintColor = C_BG();
    ic.contentMode = UIViewContentModeScaleAspectFit;
    [mark addSubview:ic];
    [sv addSubview:mark];
    y += 56 + 20;

    // display：全 App 唯一一处产品名
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(M_PAGE, y, cw, 42)];
    title.text = @"GOD 注入器";
    title.font = F_Display();
    title.textColor = C_TEXT();
    title.textAlignment = NSTextAlignmentCenter;
    [sv addSubview:title];
    y += 42 + 6;

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(M_PAGE, y, cw, 20)];
    sub.text = @"卡密授权 · 自动注入";
    sub.font = F_Body();
    sub.textColor = C_SECOND();
    sub.textAlignment = NSTextAlignmentCenter;
    [sv addSubview:sub];
    y += 20 + 32;

    // 输入面板
    GODPanel *panel = [[GODPanel alloc] initWithFrame:CGRectMake(M_PAGE, y, cw, 236)];
    [sv addSubview:panel];

    CGFloat ix = M_PAGE, iw = cw - M_PAGE * 2, iy = 18;

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(ix, iy, iw, 22)];
    lbl.text = @"输入卡密";
    lbl.font = F_Section();
    lbl.textColor = C_TEXT();
    [panel addSubview:lbl];
    iy += 22 + 4;

    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(ix, iy, iw, 18)];
    hint.text = @"16 位字母数字，大小写不限";
    hint.font = F_Caption();
    hint.textColor = C_SECOND();
    [panel addSubview:hint];
    iy += 18 + 14;

    // 输入框（raised）
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(ix, iy, iw, 50)];
    box.backgroundColor = C_RAISED();
    box.layer.cornerRadius = R_CONTROL;
    box.layer.borderWidth = 1;
    box.layer.borderColor = C_HAIR().CGColor;
    [panel addSubview:box];

    UIImageView *key = [[UIImageView alloc] initWithFrame:CGRectMake(14, 17, 16, 16)];
    key.image = [UIImage systemImageNamed:@"key.fill"];
    key.tintColor = C_SECOND();
    [box addSubview:key];

    self.counter = [[UILabel alloc] initWithFrame:CGRectMake(iw - 66, 16, 52, 18)];
    self.counter.font = F_Mono();
    self.counter.textColor = C_SECOND();
    self.counter.textAlignment = NSTextAlignmentRight;
    self.counter.text = @"0/16";
    [box addSubview:self.counter];

    self.field = [[UITextField alloc] initWithFrame:CGRectMake(14 + 16 + 10, 0, iw - 40 - 68, 50)];
    self.field.font = F_Mono();
    self.field.textColor = C_TEXT();
    self.field.tintColor = C_ACCENT();
    self.field.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:@"粘贴或输入"
            attributes:@{ NSForegroundColorAttributeName: [C_SECOND() colorWithAlphaComponent:0.7],
                          NSFontAttributeName: F_Mono() }];
    self.field.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.field.autocorrectionType = UITextAutocorrectionTypeNo;
    self.field.keyboardType = UIKeyboardTypeASCIICapable;
    self.field.returnKeyType = UIReturnKeyGo;
    self.field.delegate = self;
    [self.field addTarget:self action:@selector(changed) forControlEvents:UIControlEventEditingChanged];
    [box addSubview:self.field];
    iy += 50 + 14;

    // 主按钮
    self.btn = [[GODPrimaryButton alloc] initWithFrame:CGRectMake(ix, iy, iw, 50)];
    [self.btn setTitle:@"激活并进入" forState:UIControlStateNormal];
    [self.btn addTarget:self action:@selector(go) forControlEvents:UIControlEventTouchUpInside];
    self.btn.enabled = NO;
    [panel addSubview:self.btn];
    iy += 50 + 10;

    self.error = [[UILabel alloc] initWithFrame:CGRectMake(ix, iy, iw, 18)];
    self.error.font = F_Caption();
    self.error.textColor = C_FAULT();
    self.error.numberOfLines = 0;   // Wrap Not Truncate
    self.error.hidden = YES;
    [panel addSubview:self.error];

    self.spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spin.color = C_BG();
    self.spin.frame = CGRectMake(ix + 18, iy - 50 + 14, 22, 22);
    self.spin.hidesWhenStopped = YES;
    [panel addSubview:self.spin];

    y += 236 + M_SECTION;

    // 说明（caption + mono 构建标识）
    UILabel *note = [[UILabel alloc] initWithFrame:CGRectMake(M_PAGE, y, cw, 36)];
    note.text = @"授权只绑定当前设备，换机需要重新验证。";
    note.font = F_Caption();
    note.textColor = C_SECOND();
    note.numberOfLines = 0;
    [sv addSubview:note];
    y += 36 + 6;

    UILabel *build = [[UILabel alloc] initWithFrame:CGRectMake(M_PAGE, y, cw, 16)];
    build.text = kBuildLine;
    build.font = F_Mono();
    build.textColor = C_SECOND();
    [sv addSubview:build];
    y += 16 + 40;

    sv.contentSize = CGSizeMake(W, y);
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
    self.counter.text = [NSString stringWithFormat:@"%lu/16", (unsigned long)n];
    self.counter.textColor = (n == 16) ? C_ACCENT() : C_SECOND();
    self.btn.enabled = (n == 16) && !self.busy;
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
    [self.btn setTitle:@"正在验证…" forState:UIControlStateNormal];
    self.btn.enabled = NO;
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

#pragma mark - 主界面

@interface GODConsoleViewController : UIViewController
@property (nonatomic, strong) GODLampRow *rAuth, *rAccess, *rGroup, *rGame;
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, strong) GODPrimaryButton *bSetup;
@property (nonatomic, strong) GODSecondaryButton *bStart;
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, copy) NSString *container;
@end

@implementation GODConsoleViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = C_BG();
    [self.navigationController setNavigationBarHidden:YES animated:NO];

    CGFloat W = self.view.bounds.size.width;
    CGFloat cw = W - M_PAGE * 2;

    // ── 顶栏（品牌 + 构建标识，不滚动）──
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, 68)];
    header.backgroundColor = C_BG();
    [self.view addSubview:header];

    UIView *mark = [[UIView alloc] initWithFrame:CGRectMake(M_PAGE, 28, 28, 28)];
    mark.backgroundColor = C_ACCENT();
    mark.layer.cornerRadius = 8;
    UIImageView *mi = [[UIImageView alloc] initWithFrame:CGRectInset(mark.bounds, 7, 7)];
    mi.image = [UIImage systemImageNamed:@"shield.lefthalf.filled"];
    mi.tintColor = C_BG();
    mi.contentMode = UIViewContentModeScaleAspectFit;
    [mark addSubview:mi];
    [header addSubview:mark];

    UILabel *brand = [[UILabel alloc] initWithFrame:CGRectMake(M_PAGE + 28 + 10, 26, 200, 22)];
    brand.text = @"GOD 注入器";
    brand.font = F_Section();
    brand.textColor = C_TEXT();
    [header addSubview:brand];

    UILabel *build = [[UILabel alloc] initWithFrame:CGRectMake(M_PAGE + 28 + 10, 47, 240, 14)];
    build.text = kBuildLine;
    build.font = F_Mono();
    build.textColor = C_SECOND();
    [header addSubview:build];

    UIView *hl = [[UIView alloc] initWithFrame:CGRectMake(0, 67.5, W, 0.5)];
    hl.backgroundColor = C_HAIR();
    [header addSubview:hl];

    // ── 中间可滚动 ──
    CGFloat bottomBarH = 96;
    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 68, W,
                                                                     self.view.bounds.size.height - 68 - bottomBarH)];
    sv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    sv.alwaysBounceVertical = YES;
    [self.view addSubview:sv];

    CGFloat y = M_SECTION;

    // 运行状态
    GODPanel *st = [[GODPanel alloc] initWithFrame:CGRectMake(M_PAGE, y, cw, M_TOUCH * 4)];
    self.rAuth   = [self lampRow:@"授权状态" value:@"已验证" panel:st idx:0];
    self.rAuth.lamp.tint = C_GO(); self.rAuth.lamp.shape = GODLampShapeDot;
    self.rAccess = [self lampRow:@"沙盒访问" value:@"未检查" panel:st idx:1];
    self.rGroup  = [self lampRow:@"App Group" value:@"未检查" panel:st idx:2];
    self.rGame   = [self lampRow:@"游戏容器" value:@"未检查" panel:st idx:3];
    self.rGame.line.hidden = YES;
    [sv addSubview:st];
    y += st.bounds.size.height + M_SECTION;

    // 日志
    GODPanel *lp = [[GODPanel alloc] initWithFrame:CGRectMake(M_PAGE, y, cw, 240)];
    lp.backgroundColor = C_PANEL();
    self.logView = [[UITextView alloc] initWithFrame:CGRectMake(M_PAGE, 14, cw - M_PAGE * 2, 240 - 28)];
    self.logView.backgroundColor = [UIColor clearColor];
    self.logView.textColor = C_SECOND();
    self.logView.font = F_Mono();
    self.logView.editable = NO;
    self.logView.textContainerInset = UIEdgeInsetsZero;
    self.logView.textContainer.lineFragmentPadding = 0;
    [lp addSubview:self.logView];
    [sv addSubview:lp];
    y += lp.bounds.size.height + M_SECTION;

    sv.contentSize = CGSizeMake(W, y + M_SECTION);

    // ── 底部（不滚动）──
    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - bottomBarH,
                                                          W, bottomBarH)];
    bar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    bar.backgroundColor = C_BG();
    UIView *bl = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, 0.5)];
    bl.backgroundColor = C_HAIR();
    [bar addSubview:bl];

    CGFloat bw = (W - M_PAGE * 2 - 10) / 2;
    self.bSetup = [[GODPrimaryButton alloc] initWithFrame:CGRectMake(M_PAGE, 20, bw, 50)];
    [self.bSetup setTitle:@"初始化" forState:UIControlStateNormal];
    [self.bSetup addTarget:self action:@selector(onInit) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:self.bSetup];

    self.bStart = [[GODSecondaryButton alloc] initWithFrame:CGRectMake(M_PAGE + bw + 10, 20, bw, 50)];
    [self.bStart setTitle:@"开始注入" forState:UIControlStateNormal];
    [self.bStart addTarget:self action:@selector(onStart) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:self.bStart];

    [self.view addSubview:bar];
    [self log:@"已授权，点「初始化」检查环境"];
}

- (GODLampRow *)lampRow:(NSString *)n value:(NSString *)v panel:(UIView *)p idx:(NSInteger)i {
    GODLampRow *r = [[GODLampRow alloc] initWithFrame:CGRectMake(0, M_TOUCH * i, p.bounds.size.width, M_TOUCH)];
    r.name.text = n;
    r.value.text = v;
    r.line.hidden = (i == 3);
    [p addSubview:r];
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

- (void)setRow:(GODLampRow *)r
         lamp:(GODLampShape)shape
         tint:(UIColor *)tint
         text:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        r.lamp.shape = shape;
        r.lamp.tint = tint;
        r.value.text = text;
        r.value.textColor = C_SECOND();
    });
}

- (void)setBusy:(BOOL)b {
    _busy = b;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.bSetup.enabled = !b;
        self.bStart.enabled = !b;
    });
}

- (void)onInit {
    if (self.busy) return;
    self.busy = YES;
    [self log:@"检查环境…"];
    [self setRow:self.rAccess lamp:GODLampShapeRing tint:C_WAIT() text:@"检查中"];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *g = wq_app_group();
        [self setRow:self.rGroup
                lamp:(g ? GODLampShapeDot : GODLampShapeSquare)
                tint:(g ? C_GO() : C_FAULT())
                text:(g ? @"已获取" : @"缺失")];

        struct stat st;
        BOOL canStat = wq_stat(@"/var/mobile/Containers/Data/Application", &st) && S_ISDIR(st.st_mode);
        NSArray *list = canStat ? wq_enumerate(@"/var/mobile/Containers/Data/Application", 0, nil, nil) : nil;
        BOOL ok = list.count > 0;
        [self setRow:self.rAccess
                lamp:(ok ? GODLampShapeDot : GODLampShapeSquare)
                tint:(ok ? C_GO() : C_FAULT())
                text:(ok ? [NSString stringWithFormat:@"%lu 项", (unsigned long)list.count] : @"不可用")];

        NSString *found = nil;
        for (NSString *d in list) {
            NSString *l = wq_container_label(d);
            if (l && [l isEqualToString:kGameBundleID]) { found = d; break; }
        }
        self.container = found;
        [self setRow:self.rGame
                lamp:(found ? GODLampShapeDot : GODLampShapeWait)
                tint:(found ? C_GO() : C_WAIT())
                text:(found ? @"已定位" : @"未找到")];
        [self log:ok ? [NSString stringWithFormat:@"沙盒可用（%lu 项）", (unsigned long)list.count] : @"沙盒不可用"];
        self.busy = NO;
    });
}

- (void)onStart {
    if (self.busy) return;
    NSString *card = [[NSUserDefaults standardUserDefaults] stringForKey:kStoreCard];
    if (card.length == 0) { [self log:@"无卡密记录"]; return; }
    self.busy = YES;
    [self log:@"开始注入…"];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *c = self.container;
        if (!c) {
            for (NSString *d in wq_enumerate(@"/var/mobile/Containers/Data/Application", 0, nil, nil)) {
                NSString *l = wq_container_label(d);
                if (l && [l isEqualToString:kGameBundleID]) { c = d; break; }
            }
        }
        if (!c) {
            [self log:@"未找到容器"];
            [self setRow:self.rGame lamp:GODLampShapeSquare tint:C_FAULT() text:@"未找到"];
            self.busy = NO;
            return;
        }
        self.container = c;
        for (NSString *p in @[@"Documents", @"DeltaForce", @"Saved", @"LuaDebug", @"LuaSource", @"DFM", @"BusinessEntrance"]) {
            c = [c stringByAppendingPathComponent:p];
            struct stat st;
            if (wq_stat(c, &st) && S_ISDIR(st.st_mode)) continue;
            if (!wq_create_dir(c, NULL)) {
                [self log:[NSString stringWithFormat:@"建目录失败 %@", p]];
                self.busy = NO;
                return;
            }
        }
        [GODNet verifyCard:card completion:^(BOOL ok, NSData *file, NSString *err) {
            if (!ok) {
                [self log:[NSString stringWithFormat:@"下载失败：%@", err ?: @""]];
                self.busy = NO;
                return;
            }
            NSString *dest = [c stringByAppendingPathComponent:@"EntranceFlow.lua"];
            struct stat st;
            if (wq_stat(dest, &st)) {
                NSData *old = wq_read(dest, 0, NULL);
                if (old) wq_write([dest stringByAppendingString:@".bak"], old, NULL);
            }
            BOOL w = wq_stat(dest, &st) ? wq_write(dest, file, NULL) : wq_create_file(dest, file, NULL);
            [self log:w ? [NSString stringWithFormat:@"写入成功 %lu KB", (unsigned long)(file.length / 1024)] : @"写入失败"];
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
        initWithRootViewController:[[GODConsoleViewController alloc] init]];
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