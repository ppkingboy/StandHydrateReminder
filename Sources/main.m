#import <Cocoa/Cocoa.h>
#import <ServiceManagement/ServiceManagement.h>

typedef NS_ENUM(NSInteger, ReminderKind) { ReminderKindStand, ReminderKindWater };
typedef NS_ENUM(NSInteger, ActionType) { ActionTypeStandNow, ActionTypeAlreadyDrank, ActionTypeNextTime, ActionTypeSnoozed, ActionTypeDismissed };
typedef NS_ENUM(NSInteger, StatsPeriod) { StatsPeriodDay, StatsPeriodWeek, StatsPeriodMonth, StatsPeriodYear };

@interface ReminderWindow : NSWindow @end
@implementation ReminderWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return YES; }
@end

@interface RoundedActionButton : NSButton
@property(nonatomic,strong) NSColor *fillColor;
@property(nonatomic,strong) NSColor *titleColor;
@property(nonatomic) CGFloat cornerRadius;
@end
@implementation RoundedActionButton
- (instancetype)initWithFrame:(NSRect)frameRect {
    self=[super initWithFrame:frameRect];
    if(self){self.bordered=NO;self.wantsLayer=YES;self.cornerRadius=18;self.focusRingType=NSFocusRingTypeExterior;}
    return self;
}
- (void)setHighlighted:(BOOL)highlighted {[super setHighlighted:highlighted];[self setNeedsDisplay:YES];}
- (void)drawRect:(NSRect)dirtyRect {
    NSRect r=NSInsetRect(self.bounds, 0.5, 0.5);
    NSColor *base=self.fillColor?:NSColor.controlAccentColor;
    NSColor *fill=self.isHighlighted?[base blendedColorWithFraction:0.14 ofColor:NSColor.blackColor]:base;
    [fill setFill];
    [[NSBezierPath bezierPathWithRoundedRect:r xRadius:self.cornerRadius yRadius:self.cornerRadius] fill];
    NSMutableParagraphStyle *p=[[NSMutableParagraphStyle alloc] init];p.alignment=NSTextAlignmentCenter;p.lineBreakMode=NSLineBreakByTruncatingTail;
    NSColor *tc=self.titleColor?:NSColor.whiteColor;
    NSDictionary *a=@{NSFontAttributeName:self.font?:[NSFont systemFontOfSize:[NSFont systemFontSize] weight:NSFontWeightSemibold],NSForegroundColorAttributeName:tc,NSParagraphStyleAttributeName:p};
    NSSize sz=[self.title sizeWithAttributes:a];
    NSRect tr=NSMakeRect(NSMinX(r)+12,NSMidY(r)-sz.height/2,MAX(0,NSWidth(r)-24),sz.height);
    [self.title drawInRect:tr withAttributes:a];
}
@end

@interface BarChartView : NSView @property (nonatomic, strong) NSArray<NSDictionary *> *items; @property (nonatomic, strong) NSString *axisUnit; @end
@interface PieChartView : NSView @property (nonatomic, strong) NSArray<NSDictionary *> *items; @end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic,strong) NSStatusItem *statusItem;
@property(nonatomic,strong) NSMutableArray<NSWindow*> *reminderWindows;
@property(nonatomic,strong) NSTimer *standTimer,*waterTimer;
@property(nonatomic,strong) NSWindow *statsWindow,*basicW,*bgW,*fontW,*txtW,*anaW;
@property(nonatomic,strong) NSTextField *standMinutesField,*waterMinutesField,*snoozeMinutesField,*popupPercentField;
@property(nonatomic,strong) NSButton *launchAtLoginButton,*quietHoursButton;
@property(nonatomic,strong) NSTextField *quietStartField,*quietEndField;
@property(nonatomic,strong) NSTextField *actionText1Field,*actionText2Field,*actionText3Field;
@property(nonatomic,strong) NSTextField *dailyPromptField,*weeklyPromptField,*monthlyPromptField,*yearlyPromptField;
@property(nonatomic,strong) NSColorWell *bgColorWell;
@property(nonatomic,strong) NSSlider *bgOpacitySlider;
@property(nonatomic,strong) NSTextField *bgOpacityLabel;
@property(nonatomic,strong) NSPopUpButton *fontSelector;
@property(nonatomic,strong) NSColorWell *fontBgColorWell;
@property(nonatomic,strong) NSColorWell *fontColorWell;
@property(nonatomic,strong) NSColorWell *buttonColorWell;
@property(nonatomic,strong) NSColorWell *buttonTextColorWell;
@property(nonatomic,strong) NSSlider *fontOpacitySlider;
@property(nonatomic,strong) NSTextField *fontOpacityLabel;
@property(nonatomic,strong) NSSlider *buttonScaleSlider;
@property(nonatomic,strong) NSTextField *buttonScaleLabel;
@property(nonatomic,strong) NSSlider *reminderContentScaleSlider;
@property(nonatomic,strong) NSTextField *reminderContentScaleLabel;
@property(nonatomic,strong) NSPopUpButton *buttonStyleSelector;
@property(nonatomic,strong) NSTextField *praiseHighField,*praiseGoodField,*praiseMediumField,*praiseLowField;
@property(nonatomic,strong) NSTextField *settingsStatusLabel; @property(nonatomic,strong) NSTextField *loginStatusField;
@property(nonatomic,strong) NSSegmentedControl *periodSelector;
@property(nonatomic,strong) BarChartView *barChart;
@property(nonatomic,strong) PieChartView *pieChart;
@property(nonatomic,strong) NSTextField *analysisResultLabel;
@property(nonatomic,strong) NSMutableSet<NSNumber *> *testReminderKinds;
@property(nonatomic,strong) NSTextField *dismissSecondsField;
@property(nonatomic,strong) NSTimer *dismissTimer;
@property(nonatomic) NSInteger dismissRemainingSeconds;
@property(nonatomic,strong) NSWindow *currentReminderWindow;
@property(nonatomic) ReminderKind currentReminderKind;
@property(nonatomic,strong) NSTextField *countdownLabel;
@end

@implementation AppDelegate

static NSString * const StandMinutesKey = @"StandMinutes";
static NSString * const WaterMinutesKey = @"WaterMinutes";
static NSString * const SnoozeMinutesKey = @"SnoozeMinutes";
static NSString * const PopupPercentKey = @"PopupPercent";
static NSString * const LaunchAtLoginKey = @"LaunchAtLogin";
static NSString * const QuietHoursEnabledKey = @"QuietHoursEnabled";
static NSString * const QuietStartKey = @"QuietStart";
static NSString * const QuietEndKey = @"QuietEnd";
static NSString * const ActionText1Key = @"ActionText1";
static NSString * const ActionText2Key = @"ActionText2";
static NSString * const ActionText3Key = @"ActionText3";
static NSString * const DailyPromptKey = @"DailyPrompt";
static NSString * const WeeklyPromptKey = @"WeeklyPrompt";
static NSString * const MonthlyPromptKey = @"MonthlyPrompt";
static NSString * const YearlyPromptKey = @"YearlyPrompt";
static NSString * const BgColorKey = @"BgColor";
static NSString * const BgOpacityKey = @"BgOpacity";
static NSString * const FontNameKey = @"FontName";
static NSString * const FontBgColorKey = @"FontBgColor";
static NSString * const FontColorKey = @"FontColor";
static NSString * const FontOpacityKey = @"FontOpacity";
static NSString * const ButtonStyleKey = @"ButtonStyle";
static NSString * const ButtonColorKey = @"ButtonColor";
static NSString * const ButtonTextColorKey = @"ButtonTextColor";
static NSString * const ButtonScaleKey = @"ButtonScale";
static NSString * const ReminderContentScaleKey = @"ReminderContentScale";
static NSString * const PraiseHighKey = @"PraiseHigh";
static NSString * const PraiseGoodKey = @"PraiseGood";
static NSString * const PraiseMediumKey = @"PraiseMedium";
static NSString * const PraiseLowKey = @"PraiseLow";
static NSString * const RecordsKey = @"ActionRecords";
static NSString * const DismissSecondsKey = @"DismissSeconds";


- (NSView *)makeContainerView {
    NSBox *box = [[NSBox alloc] initWithFrame:NSZeroRect];
    box.boxType = NSBoxCustom;
    box.cornerRadius = 10;
    box.borderWidth = 1;
    box.borderColor = [NSColor.separatorColor colorWithAlphaComponent:0.3];
    box.fillColor = [NSColor.controlBackgroundColor colorWithAlphaComponent:0.55];
    box.contentViewMargins = NSMakeSize(0, 0);
    box.translatesAutoresizingMaskIntoConstraints = NO;
    return box;
}

- (NSTextField *)sectionTitle:(NSString *)title {
    NSTextField *l = [NSTextField labelWithString:title];
    l.font = [NSFont systemFontOfSize:15 weight:NSFontWeightBold];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    return l;
}

- (NSView *)sectionBasicSettings {
    NSView *v = [self makeContainerView];
    NSTextField *tl = [self sectionTitle:@"基本设置"];
    [v addSubview:tl];
    self.standMinutesField = [self numberField]; self.waterMinutesField = [self numberField];
    self.snoozeMinutesField = [self numberField]; self.popupPercentField = [self numberField];
    self.quietStartField = [self textField]; self.quietEndField = [self textField];
    
    self.dismissSecondsField = [self numberField];
    NSGridView *grid = [NSGridView gridViewWithViews:@[
        @[[self settingsLabel:@"站立间隔(分钟)"], self.standMinutesField],
        @[[self settingsLabel:@"喝水间隔(分钟)"], self.waterMinutesField],
        @[[self settingsLabel:@"稍后提醒(分钟)"], self.snoozeMinutesField],
        @[[self settingsLabel:@"弹窗宽度(50-95%)"], self.popupPercentField],
        @[[self settingsLabel:@"自动关闭(秒)"], self.dismissSecondsField],
        @[[self settingsLabel:@"免提醒开始(HH:mm)"], self.quietStartField],
        @[[self settingsLabel:@"免提醒结束(HH:mm)"], self.quietEndField]
    ]];
    grid.translatesAutoresizingMaskIntoConstraints = NO; grid.rowSpacing = 8; grid.columnSpacing = 20;
    [grid columnAtIndex:0].xPlacement = NSGridCellPlacementTrailing;
    [grid setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
    
    self.launchAtLoginButton = [NSButton checkboxWithTitle:@"开机自启" target:nil action:nil];
    self.launchAtLoginButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.loginStatusField = [NSTextField labelWithString:@""];
    self.loginStatusField.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    self.loginStatusField.textColor = NSColor.secondaryLabelColor;
    self.loginStatusField.translatesAutoresizingMaskIntoConstraints = NO;
    NSButton *loginBtn = [self smallButton:@"登录项设置..." action:@selector(openLoginItemsSettings:)];
    self.quietHoursButton = [NSButton checkboxWithTitle:@"启用免提醒时段" target:nil action:nil];
    self.quietHoursButton.translatesAutoresizingMaskIntoConstraints = NO;
    NSTextField *hint = [NSTextField labelWithString:@"应用在后台常驻菜单栏，到点弹出提醒。"];
    hint.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
    hint.textColor = [NSColor.secondaryLabelColor colorWithAlphaComponent:0.8]; hint.translatesAutoresizingMaskIntoConstraints = NO;
    NSButton *svBtn = [self smallButton:@"保存并重启" action:@selector(saveBasicSettings:)];
    
    [v addSubview:grid];
    [v addSubview:self.launchAtLoginButton]; [v addSubview:self.loginStatusField];
    [v addSubview:loginBtn]; [v addSubview:self.quietHoursButton]; [v addSubview:hint]; [v addSubview:svBtn];
    [NSLayoutConstraint activateConstraints:@[
        [tl.topAnchor constraintEqualToAnchor:v.topAnchor constant:14],
        [tl.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [tl.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-14],
        [grid.topAnchor constraintEqualToAnchor:tl.bottomAnchor constant:12],
        [grid.centerXAnchor constraintEqualToAnchor:v.centerXAnchor],
        [self.launchAtLoginButton.topAnchor constraintEqualToAnchor:grid.bottomAnchor constant:8],
        [self.launchAtLoginButton.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [self.loginStatusField.centerYAnchor constraintEqualToAnchor:self.launchAtLoginButton.centerYAnchor],
        [self.loginStatusField.leadingAnchor constraintEqualToAnchor:self.launchAtLoginButton.trailingAnchor constant:10],
        [loginBtn.centerYAnchor constraintEqualToAnchor:self.launchAtLoginButton.centerYAnchor],
        [loginBtn.leadingAnchor constraintEqualToAnchor:self.loginStatusField.trailingAnchor constant:8],
        [self.quietHoursButton.topAnchor constraintEqualToAnchor:self.launchAtLoginButton.bottomAnchor constant:8],
        [self.quietHoursButton.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [hint.topAnchor constraintEqualToAnchor:self.quietHoursButton.bottomAnchor constant:8],
        [hint.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [hint.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-14],
        [svBtn.topAnchor constraintEqualToAnchor:hint.bottomAnchor constant:8],
        [svBtn.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-14],
        [svBtn.bottomAnchor constraintEqualToAnchor:v.bottomAnchor constant:-14],
    ]];
    return v;
}
- (NSView *)sectionBackgroundSettings {
    NSView *v = [self makeContainerView];
    NSTextField *tl = [self sectionTitle:@"背景设置"];
    
    NSButton *bgSvBtn = [self smallButton:@"保存背景" action:@selector(saveBackgroundSettings:)];NSButton *bgResetBtn = [self smallButton:@"还原默认" action:@selector(resetBackgroundSettings:)];[v addSubview:tl];
    NSTextField *cl = [self settingsLabel:@"背景颜色"];
    self.bgColorWell = [[NSColorWell alloc] initWithFrame:NSMakeRect(0,0,44,28)];
    self.bgColorWell.translatesAutoresizingMaskIntoConstraints = NO;
    [self.bgColorWell.widthAnchor constraintEqualToConstant:44].active = YES;
    NSTextField *opl = [self settingsLabel:@"透明度"];
    self.bgOpacitySlider = [[NSSlider alloc] initWithFrame:NSZeroRect];
    self.bgOpacitySlider.minValue = 0; self.bgOpacitySlider.maxValue = 100;
    self.bgOpacitySlider.integerValue = 15; self.bgOpacitySlider.target = self;
    self.bgOpacitySlider.action = @selector(bgOpacityChanged:);
    self.bgOpacitySlider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.bgOpacitySlider.widthAnchor constraintEqualToConstant:200].active = YES;
    self.bgOpacityLabel = [NSTextField labelWithString:@"15%"];
    self.bgOpacityLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
    self.bgOpacityLabel.textColor = NSColor.secondaryLabelColor;
    self.bgOpacityLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:cl]; [v addSubview:self.bgColorWell];
    [v addSubview:opl]; [v addSubview:self.bgOpacitySlider]; [v addSubview:self.bgOpacityLabel];
    [v addSubview:bgSvBtn]; [v addSubview:bgResetBtn];
    [NSLayoutConstraint activateConstraints:@[
        [tl.topAnchor constraintEqualToAnchor:v.topAnchor constant:14],
        [tl.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [tl.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-14],
        [cl.topAnchor constraintEqualToAnchor:tl.bottomAnchor constant:12],
        [cl.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [self.bgColorWell.centerYAnchor constraintEqualToAnchor:cl.centerYAnchor],
        [self.bgColorWell.leadingAnchor constraintEqualToAnchor:cl.trailingAnchor constant:10],
        [opl.topAnchor constraintEqualToAnchor:cl.bottomAnchor constant:12],
        [opl.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [self.bgOpacitySlider.centerYAnchor constraintEqualToAnchor:opl.centerYAnchor],
        [self.bgOpacitySlider.leadingAnchor constraintEqualToAnchor:opl.trailingAnchor constant:10],
        [self.bgOpacityLabel.centerYAnchor constraintEqualToAnchor:opl.centerYAnchor],
        [self.bgOpacityLabel.leadingAnchor constraintEqualToAnchor:self.bgOpacitySlider.trailingAnchor constant:8],
        [self.bgOpacityLabel.bottomAnchor constraintEqualToAnchor:bgResetBtn.topAnchor constant:-12],
        [bgResetBtn.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [bgResetBtn.bottomAnchor constraintEqualToAnchor:v.bottomAnchor constant:-14],
        [bgSvBtn.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-14],
        [bgSvBtn.centerYAnchor constraintEqualToAnchor:bgResetBtn.centerYAnchor],
    ]];
    return v;
}

- (NSView *)sectionFontAndButton {
    NSView *v = [self makeContainerView];
    NSTextField *tl = [self sectionTitle:@"字体与按钮"];
    
    NSButton *fontSvBtn = [self smallButton:@"保存字体" action:@selector(saveFontButtonSettings:)];NSButton *fontResetBtn = [self smallButton:@"还原默认" action:@selector(resetFontButtonSettings:)];[v addSubview:tl];
    NSTextField *fl = [self settingsLabel:@"字体"];
    self.fontSelector = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    self.fontSelector.target = self; self.fontSelector.action = @selector(fontChanged:);
    self.fontSelector.translatesAutoresizingMaskIntoConstraints = NO;
    [self.fontSelector.widthAnchor constraintEqualToConstant:220].active = YES;
    NSTextField *fbl = [self settingsLabel:@"文字背景"];
    self.fontBgColorWell = [[NSColorWell alloc] initWithFrame:NSMakeRect(0, 0, 28, 22)];
    self.fontBgColorWell.translatesAutoresizingMaskIntoConstraints = NO;
    [self.fontBgColorWell.widthAnchor constraintEqualToConstant:28].active = YES;
    NSTextField *fcl = [self settingsLabel:@"字体颜色"];
    self.fontColorWell = [[NSColorWell alloc] initWithFrame:NSMakeRect(0, 0, 44, 28)];
    self.fontColorWell.translatesAutoresizingMaskIntoConstraints = NO;
    [self.fontColorWell.widthAnchor constraintEqualToConstant:44].active = YES;
    NSTextField *fol = [self settingsLabel:@"透明度"];
    self.fontOpacitySlider = [[NSSlider alloc] initWithFrame:NSZeroRect];
    self.fontOpacitySlider.minValue = 0; self.fontOpacitySlider.maxValue = 100;
    self.fontOpacitySlider.doubleValue = 100; self.fontOpacitySlider.target = self;
    self.fontOpacitySlider.action = @selector(fontOpacityChanged:);
    self.fontOpacitySlider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.fontOpacitySlider.widthAnchor constraintEqualToConstant:220].active = YES;
    self.fontOpacityLabel = [NSTextField labelWithString:@"100%"];
    self.fontOpacityLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
    self.fontOpacityLabel.textColor = NSColor.secondaryLabelColor;
    self.fontOpacityLabel.translatesAutoresizingMaskIntoConstraints = NO;
    NSTextField *bsl = [self settingsLabel:@"按钮大小"];
    self.buttonScaleSlider = [[NSSlider alloc] initWithFrame:NSZeroRect];
    self.buttonScaleSlider.minValue = 60; self.buttonScaleSlider.maxValue = 160;
    self.buttonScaleSlider.doubleValue = 100; self.buttonScaleSlider.target = self;
    self.buttonScaleSlider.action = @selector(buttonScaleChanged:);
    self.buttonScaleSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.buttonScaleSlider.widthAnchor constraintEqualToConstant:220].active = YES;
    self.buttonScaleLabel = [NSTextField labelWithString:@"100%"];
    self.buttonScaleLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
    self.buttonScaleLabel.textColor = NSColor.secondaryLabelColor;
    self.buttonScaleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    NSTextField *rsl = [self settingsLabel:@"内容大小"];
    self.reminderContentScaleSlider = [[NSSlider alloc] initWithFrame:NSZeroRect];
    self.reminderContentScaleSlider.minValue = 60; self.reminderContentScaleSlider.maxValue = 160;
    self.reminderContentScaleSlider.doubleValue = 100; self.reminderContentScaleSlider.target = self;
    self.reminderContentScaleSlider.action = @selector(reminderContentScaleChanged:);
    self.reminderContentScaleSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.reminderContentScaleSlider.widthAnchor constraintEqualToConstant:220].active = YES;
    self.reminderContentScaleLabel = [NSTextField labelWithString:@"100%"];
    self.reminderContentScaleLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
    self.reminderContentScaleLabel.textColor = NSColor.secondaryLabelColor;
    self.reminderContentScaleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    NSTextField *stl = [self settingsLabel:@"按钮风格"];
    self.buttonStyleSelector = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    self.buttonStyleSelector.translatesAutoresizingMaskIntoConstraints = NO;
    [self.buttonStyleSelector.widthAnchor constraintEqualToConstant:220].active = YES;
    NSTextField *bcl = [self settingsLabel:@"按钮颜色"];
    self.buttonColorWell = [[NSColorWell alloc] initWithFrame:NSMakeRect(0, 0, 44, 28)];
    self.buttonColorWell.translatesAutoresizingMaskIntoConstraints = NO;
    [self.buttonColorWell.widthAnchor constraintEqualToConstant:44].active = YES;
    NSTextField *btcl = [self settingsLabel:@"按钮文字"];
    self.buttonTextColorWell = [[NSColorWell alloc] initWithFrame:NSMakeRect(0, 0, 44, 28)];
    self.buttonTextColorWell.translatesAutoresizingMaskIntoConstraints = NO;
    [self.buttonTextColorWell.widthAnchor constraintEqualToConstant:44].active = YES;
    [v addSubview:fl]; [v addSubview:self.fontSelector];
    [v addSubview:fbl]; [v addSubview:self.fontBgColorWell];
    [v addSubview:fcl]; [v addSubview:self.fontColorWell];
    [v addSubview:fol]; [v addSubview:self.fontOpacitySlider]; [v addSubview:self.fontOpacityLabel];
    [v addSubview:bsl]; [v addSubview:self.buttonScaleSlider]; [v addSubview:self.buttonScaleLabel];
    [v addSubview:rsl]; [v addSubview:self.reminderContentScaleSlider]; [v addSubview:self.reminderContentScaleLabel];
    [v addSubview:stl]; [v addSubview:self.buttonStyleSelector];
    [v addSubview:bcl]; [v addSubview:self.buttonColorWell];
    [v addSubview:btcl]; [v addSubview:self.buttonTextColorWell];
    [v addSubview:fontSvBtn]; [v addSubview:fontResetBtn];
    [NSLayoutConstraint activateConstraints:@[
        [tl.topAnchor constraintEqualToAnchor:v.topAnchor constant:14],
        [tl.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [tl.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-14],
        [fl.topAnchor constraintEqualToAnchor:tl.bottomAnchor constant:12],
        [fl.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [self.fontSelector.centerYAnchor constraintEqualToAnchor:fl.centerYAnchor],
        [self.fontSelector.leadingAnchor constraintEqualToAnchor:fl.trailingAnchor constant:10],
        [fbl.topAnchor constraintEqualToAnchor:fl.bottomAnchor constant:12],
        [fbl.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [self.fontBgColorWell.centerYAnchor constraintEqualToAnchor:fbl.centerYAnchor],
        [self.fontBgColorWell.leadingAnchor constraintEqualToAnchor:fbl.trailingAnchor constant:10],
        [fcl.topAnchor constraintEqualToAnchor:fbl.bottomAnchor constant:12],
        [fcl.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [self.fontColorWell.centerYAnchor constraintEqualToAnchor:fcl.centerYAnchor],
        [self.fontColorWell.leadingAnchor constraintEqualToAnchor:fcl.trailingAnchor constant:10],
        [fol.topAnchor constraintEqualToAnchor:fcl.bottomAnchor constant:12],
        [fol.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [self.fontOpacitySlider.centerYAnchor constraintEqualToAnchor:fol.centerYAnchor],
        [self.fontOpacitySlider.leadingAnchor constraintEqualToAnchor:fol.trailingAnchor constant:10],
        [self.fontOpacityLabel.centerYAnchor constraintEqualToAnchor:fol.centerYAnchor],
        [self.fontOpacityLabel.leadingAnchor constraintEqualToAnchor:self.fontOpacitySlider.trailingAnchor constant:8],
        [bsl.topAnchor constraintEqualToAnchor:fol.bottomAnchor constant:12],
        [bsl.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [self.buttonScaleSlider.centerYAnchor constraintEqualToAnchor:bsl.centerYAnchor],
        [self.buttonScaleSlider.leadingAnchor constraintEqualToAnchor:bsl.trailingAnchor constant:10],
        [self.buttonScaleLabel.centerYAnchor constraintEqualToAnchor:bsl.centerYAnchor],
        [self.buttonScaleLabel.leadingAnchor constraintEqualToAnchor:self.buttonScaleSlider.trailingAnchor constant:8],
        [rsl.topAnchor constraintEqualToAnchor:bsl.bottomAnchor constant:12],
        [rsl.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [self.reminderContentScaleSlider.centerYAnchor constraintEqualToAnchor:rsl.centerYAnchor],
        [self.reminderContentScaleSlider.leadingAnchor constraintEqualToAnchor:rsl.trailingAnchor constant:10],
        [self.reminderContentScaleLabel.centerYAnchor constraintEqualToAnchor:rsl.centerYAnchor],
        [self.reminderContentScaleLabel.leadingAnchor constraintEqualToAnchor:self.reminderContentScaleSlider.trailingAnchor constant:8],
        [stl.topAnchor constraintEqualToAnchor:rsl.bottomAnchor constant:12],
        [stl.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [self.buttonStyleSelector.centerYAnchor constraintEqualToAnchor:stl.centerYAnchor],
        [self.buttonStyleSelector.leadingAnchor constraintEqualToAnchor:stl.trailingAnchor constant:10],
        [bcl.topAnchor constraintEqualToAnchor:stl.bottomAnchor constant:12],
        [bcl.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [self.buttonColorWell.centerYAnchor constraintEqualToAnchor:bcl.centerYAnchor],
        [self.buttonColorWell.leadingAnchor constraintEqualToAnchor:bcl.trailingAnchor constant:10],
        [btcl.topAnchor constraintEqualToAnchor:bcl.bottomAnchor constant:12],
        [btcl.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [self.buttonTextColorWell.centerYAnchor constraintEqualToAnchor:btcl.centerYAnchor],
        [self.buttonTextColorWell.leadingAnchor constraintEqualToAnchor:btcl.trailingAnchor constant:10],
        [btcl.bottomAnchor constraintEqualToAnchor:fontResetBtn.topAnchor constant:-12],
        [fontResetBtn.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [fontResetBtn.bottomAnchor constraintEqualToAnchor:v.bottomAnchor constant:-14],
        [fontSvBtn.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-14],
        [fontSvBtn.centerYAnchor constraintEqualToAnchor:fontResetBtn.centerYAnchor],
    ]];
    return v;
}

- (NSView *)sectionCustomText {
    NSView *v = [self makeContainerView];
    NSTextField *tl = [self sectionTitle:@"自定义动作"];
    [v addSubview:tl];
    
    self.actionText1Field = [self textField]; self.actionText2Field = [self textField]; self.actionText3Field = [self textField];
    NSGridView *ag = [NSGridView gridViewWithViews:@[
        @[[self settingsLabel:@"站立积极"], self.actionText1Field],
        @[[self settingsLabel:@"喝水积极"], self.actionText2Field],
        @[[self settingsLabel:@"跳过"], self.actionText3Field],
    ]];
    ag.translatesAutoresizingMaskIntoConstraints = NO; ag.rowSpacing = 8; ag.columnSpacing = 20;
    [ag columnAtIndex:0].xPlacement = NSGridCellPlacementTrailing;
    [ag setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
    NSButton *txtSvBtn = [self smallButton:@"保存文本" action:@selector(saveCustomTextSettings:)];
    
    [v addSubview:ag]; [v addSubview:txtSvBtn];
    [NSLayoutConstraint activateConstraints:@[
        [tl.topAnchor constraintEqualToAnchor:v.topAnchor constant:14],
        [tl.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [tl.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-14],
        [ag.topAnchor constraintEqualToAnchor:tl.bottomAnchor constant:12],
        [ag.centerXAnchor constraintEqualToAnchor:v.centerXAnchor],
        [txtSvBtn.topAnchor constraintEqualToAnchor:ag.bottomAnchor constant:12],
        [txtSvBtn.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-14],
        [txtSvBtn.bottomAnchor constraintEqualToAnchor:v.bottomAnchor constant:-14],
    ]];
    return v;
}

- (NSView *)sectionAnalysisAndFeedback {
    NSView *v = [self makeContainerView];
    NSTextField *tl = [self sectionTitle:@"统计设置"];
    [v addSubview:tl];
    
    NSTextField *h2 = [NSTextField labelWithString:@"{rate}会被替换为达成率，{praise}会被替换为表扬语"];
    h2.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    h2.textColor = NSColor.secondaryLabelColor; h2.translatesAutoresizingMaskIntoConstraints = NO;
    self.dailyPromptField = [self textField]; self.weeklyPromptField = [self textField];
    self.monthlyPromptField = [self textField]; self.yearlyPromptField = [self textField];
    self.praiseHighField = [self textField]; self.praiseGoodField = [self textField];
    self.praiseMediumField = [self textField]; self.praiseLowField = [self textField];
    NSGridView *pg = [NSGridView gridViewWithViews:@[
        @[[self settingsLabel:@"日分析"], self.dailyPromptField],
        @[[self settingsLabel:@"周分析"], self.weeklyPromptField],
        @[[self settingsLabel:@"月分析"], self.monthlyPromptField],
        @[[self settingsLabel:@"年分析"], self.yearlyPromptField],
    ]];
    pg.translatesAutoresizingMaskIntoConstraints = NO; pg.rowSpacing = 8; pg.columnSpacing = 20;
    [pg columnAtIndex:0].xPlacement = NSGridCellPlacementTrailing;
    [pg setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
    NSGridView *prg = [NSGridView gridViewWithViews:@[
        @[[self settingsLabel:@"≥90%"], self.praiseHighField],
        @[[self settingsLabel:@"≥70%"], self.praiseGoodField],
        @[[self settingsLabel:@"≥50%"], self.praiseMediumField],
        @[[self settingsLabel:@"<50%"], self.praiseLowField],
    ]];
    prg.translatesAutoresizingMaskIntoConstraints = NO; prg.rowSpacing = 8; prg.columnSpacing = 20;
    [prg columnAtIndex:0].xPlacement = NSGridCellPlacementTrailing;
    [prg setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
    NSButton *anaSvBtn = [self smallButton:@"保存分析" action:@selector(saveAnalysisSettings:)];NSButton *anaResetBtn = [self smallButton:@"还原默认" action:@selector(resetAnalysisSettings:)];

    [v addSubview:h2]; [v addSubview:pg]; [v addSubview:prg]; [v addSubview:anaSvBtn]; [v addSubview:anaResetBtn];
    [NSLayoutConstraint activateConstraints:@[
        [tl.topAnchor constraintEqualToAnchor:v.topAnchor constant:14],
        [tl.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [tl.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-14],
        [h2.topAnchor constraintEqualToAnchor:tl.bottomAnchor constant:12],
        [h2.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [h2.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-14],
        [pg.topAnchor constraintEqualToAnchor:h2.bottomAnchor constant:12],
        [pg.centerXAnchor constraintEqualToAnchor:v.centerXAnchor],
        [prg.topAnchor constraintEqualToAnchor:pg.bottomAnchor constant:12],
        [prg.centerXAnchor constraintEqualToAnchor:v.centerXAnchor],
        [anaSvBtn.topAnchor constraintEqualToAnchor:prg.bottomAnchor constant:12],
        [anaResetBtn.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:14],
        [anaResetBtn.bottomAnchor constraintEqualToAnchor:v.bottomAnchor constant:-14],
        [anaSvBtn.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-14],
        [anaSvBtn.centerYAnchor constraintEqualToAnchor:anaResetBtn.centerYAnchor],
    ]];
    return v;
}





- (NSWindow *)wrapSection:(NSView *)v title:(NSString *)t w:(CGFloat)w h:(CGFloat)h {
    v.translatesAutoresizingMaskIntoConstraints = NO;
    NSWindow *win = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,w,h) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
    win.title = t; win.releasedWhenClosed = NO;
    NSView *cv = win.contentView;
    [cv addSubview:v];
    [NSLayoutConstraint activateConstraints:@[
        [v.topAnchor constraintEqualToAnchor:cv.topAnchor constant:2],
        [v.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:2],
        [v.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-2],
        [v.bottomAnchor constraintEqualToAnchor:cv.bottomAnchor constant:-2],
    ]];
    [win center]; return win;
}

- (void)openBasicSettings:(id)s {
    if(!self.basicW) self.basicW=[self wrapSection:[self sectionBasicSettings] title:@"\xe5\x9f\xba\xe6\x9c\xac\xe8\xae\xbe\xe7\xbd\xae" w:460 h:420];
    [self populateSettingsFields];[NSApp activateIgnoringOtherApps:YES];[self.basicW makeKeyAndOrderFront:nil];
}
- (void)openBackgroundSettings:(id)s {
    if(!self.bgW) self.bgW=[self wrapSection:[self sectionBackgroundSettings] title:@"\xe8\x83\x8c\xe6\x99\xaf\xe8\xae\xbe\xe7\xbd\xae" w:380 h:320];
    [self populateSettingsFields];[NSApp activateIgnoringOtherApps:YES];[self.bgW makeKeyAndOrderFront:nil];
}
- (void)openFontButtonSettings:(id)s {
    if(!self.fontW) self.fontW=[self wrapSection:[self sectionFontAndButton] title:@"\xe5\xad\x97\xe4\xbd\x93\xe4\xb8\x8e\xe6\x8c\x89\xe9\x92\xae" w:460 h:470];
    [self populateSettingsFields];[NSApp activateIgnoringOtherApps:YES];[self.fontW makeKeyAndOrderFront:nil];
}
- (void)openCustomTextSettings:(id)s {
    if(!self.txtW) self.txtW=[self wrapSection:[self sectionCustomText] title:@"\xe8\x87\xaa\xe5\xae\x9a\xe4\xb9\x89\xe6\x96\x87\xe6\x9c\xac" w:400 h:220];
    [self populateSettingsFields];[NSApp activateIgnoringOtherApps:YES];[self.txtW makeKeyAndOrderFront:nil];
}
- (void)openAnalysisSettings:(id)s {
    if(!self.anaW) self.anaW=[self wrapSection:[self sectionAnalysisAndFeedback] title:@"\xe7\xbb\x9f\xe8\xae\xa1\xe8\xae\xbe\xe7\xbd\xae" w:460 h:420];
    [self populateSettingsFields];[NSApp activateIgnoringOtherApps:YES];[self.anaW makeKeyAndOrderFront:nil];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.reminderWindows = [NSMutableArray array];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [self registerDefaults]; [self setupStatusMenu]; [self scheduleTimers];
    [self showReminderIfAllowed:ReminderKindStand];
}

- (void)registerDefaults {
    NSData *bgcDflt=[NSKeyedArchiver archivedDataWithRootObject:[NSColor colorWithCalibratedRed:0.9 green:0.9 blue:0.95 alpha:1] requiringSecureCoding:YES error:nil];
    NSData *fontcDflt=[NSKeyedArchiver archivedDataWithRootObject:[NSColor colorWithCalibratedRed:0.2 green:0.5 blue:0.8 alpha:1] requiringSecureCoding:YES error:nil];
    NSData *btncDflt=[NSKeyedArchiver archivedDataWithRootObject:[NSColor colorWithCalibratedRed:0.10 green:0.44 blue:0.78 alpha:1] requiringSecureCoding:YES error:nil];
    NSData *btntcDflt=[NSKeyedArchiver archivedDataWithRootObject:NSColor.whiteColor requiringSecureCoding:YES error:nil];
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        StandMinutesKey:@45,WaterMinutesKey:@30,SnoozeMinutesKey:@10,PopupPercentKey:@50,
        DismissSecondsKey:@120,
        LaunchAtLoginKey:@NO,QuietHoursEnabledKey:@NO,QuietStartKey:@"22:00",QuietEndKey:@"08:00",
        ActionText1Key:@"\xe7\x8e\xb0\xe5\x9c\xa8\xe7\xab\x99",ActionText2Key:@"\xe5\xb7\xb2\xe5\x96\x9d",ActionText3Key:@"\xe4\xb8\x8b\xe6\xac\xa1\xe5\x90\xa7",
        DailyPromptKey:@"\xe4\xbb\x8a\xe6\x97\xa5\xe8\xbe\xbe\xe6\x88\x90\xe7\x8e\x87\xe4\xb8\xba{rate}%\xe3\x80\x82",WeeklyPromptKey:@"\xe6\x9c\xac\xe5\x91\xa8\xe8\xbe\xbe\xe6\x88\x90\xe7\x8e\x87\xe4\xb8\xba{rate}%\xe3\x80\x82",
        MonthlyPromptKey:@"\xe6\x9c\xac\xe6\x9c\x88\xe8\xbe\xbe\xe6\x88\x90\xe7\x8e\x87\xe4\xb8\xba{rate}%\xe3\x80\x82",YearlyPromptKey:@"\xe6\x9c\xac\xe5\xb9\xb4\xe8\xbe\xbe\xe6\x88\x90\xe7\x8e\x87\xe4\xb8\xba{rate}%\xe3\x80\x82",
        BgColorKey:bgcDflt?:[NSData data],BgOpacityKey:@0.15,FontNameKey:@"PingFang SC",FontColorKey:fontcDflt?:[NSData data],FontOpacityKey:@1.0,ButtonStyleKey:@0,ButtonColorKey:btncDflt?:[NSData data],ButtonTextColorKey:btntcDflt?:[NSData data],ButtonScaleKey:@1.0,ReminderContentScaleKey:@1.0,
        PraiseHighKey:@"\xe6\x82\xa8\xe6\x98\xaf\xe5\xa4\xa9\xe4\xb8\x8b\xe6\x9c\x80\xe5\xa5\xbd\xe7\x9a\x84\xe5\xae\x9d\xe5\xae\x9d\xef\xbd\x9e",PraiseGoodKey:@"\xe5\xbe\x88\xe6\xa3\x92\xef\xbc\x8c\xe7\xbb\xa7\xe7\xbb\xad\xe5\x8a\xa0\xe6\xb2\xb9\xef\xbc\x81",
        PraiseMediumKey:@"\xe8\xbf\x98\xe4\xb8\x8d\xe9\x94\x99\xef\xbc\x8c\xe5\x86\x8d\xe5\x8a\xa0\xe6\x8a\x8a\xe5\x8a\xb2\xef\xbc\x81",PraiseLowKey:@"\xe8\xa6\x81\xe5\xa4\x9a\xe6\xb3\xa8\xe6\x84\x8f\xe7\xab\x99\xe7\xab\x8b\xe5\x92\x8c\xe5\x96\x9d\xe6\xb0\xb4\xe5\x93\xa6\xef\xbc\x81",
    }];
}

- (void)setupStatusMenu {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.title = @"\xe7\xab\x99\xe6\xb0\xb4";
    self.statusItem.button.toolTip = @"\xe7\xab\x99\xe7\xab\x8b\xe5\x96\x9d\xe6\xb0\xb4\xe6\x8f\x90\xe9\x86\x92";
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"\xe7\xab\x99\xe7\xab\x8b\xe5\x96\x9d\xe6\xb0\xb4\xe6\x8f\x90\xe9\x86\x92"];
    [menu addItem:[self menuItem:@"\xe6\xb5\x8b\xe8\xaf\x95\xe7\xab\x99\xe7\xab\x8b\xe6\x8f\x90\xe9\x86\x92" action:@selector(testStand:) key:@"1"]];
    [menu addItem:[self menuItem:@"\xe6\xb5\x8b\xe8\xaf\x95\xe5\x96\x9d\xe6\xb0\xb4\xe6\x8f\x90\xe9\x86\x92" action:@selector(testWater:) key:@"2"]];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItem:[self menuItem:@"\xe7\xbb\x9f\xe8\xae\xa1..." action:@selector(openStats:) key:@"t"]];
    NSMenu *ss = [[NSMenu alloc] initWithTitle:@""];
    [ss addItem:[self menuItem:@"\xe5\x9f\xba\xe6\x9c\xac\xe8\xae\xbe\xe7\xbd\xae" action:@selector(openBasicSettings:) key:@""]];
    [ss addItem:[self menuItem:@"\xe8\x83\x8c\xe6\x99\xaf\xe8\xae\xbe\xe7\xbd\xae" action:@selector(openBackgroundSettings:) key:@""]];
    [ss addItem:[self menuItem:@"\xe5\xad\x97\xe4\xbd\x93\xe4\xb8\x8e\xe6\x8c\x89\xe9\x92\xae" action:@selector(openFontButtonSettings:) key:@""]];
    [ss addItem:[self menuItem:@"\xe8\x87\xaa\xe5\xae\x9a\xe4\xb9\x89\xe6\x96\x87\xe6\x9c\xac" action:@selector(openCustomTextSettings:) key:@""]];
    [ss addItem:[self menuItem:@"\xe7\xbb\x9f\xe8\xae\xa1\xe8\xae\xbe\xe7\xbd\xae" action:@selector(openAnalysisSettings:) key:@""]];
    NSMenuItem *si = [[NSMenuItem alloc] initWithTitle:@"\xe8\xae\xbe\xe7\xbd\xae" action:nil keyEquivalent:@""];
    [si setSubmenu:ss]; [menu addItem:si];
    
    
    [menu addItem:[self menuItem:@"\xe9\x80\x80\xe5\x87\xba" action:@selector(quit:) key:@"q"]];
    self.statusItem.menu = menu;
}

- (NSMenuItem *)menuItem:(NSString *)title action:(SEL)action key:(NSString *)key {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:key];
    item.target = self; return item;
}

- (void)scheduleTimers {
    [self.standTimer invalidate];[self.waterTimer invalidate];
    self.standTimer=[NSTimer scheduledTimerWithTimeInterval:[self intervalForKey:StandMinutesKey] target:self selector:@selector(standTimerFired:) userInfo:nil repeats:YES];
    self.waterTimer=[NSTimer scheduledTimerWithTimeInterval:[self intervalForKey:WaterMinutesKey] target:self selector:@selector(waterTimerFired:) userInfo:nil repeats:YES];
}
- (NSTimeInterval)intervalForKey:(NSString *)key {
    return MAX(1,[[NSUserDefaults standardUserDefaults] integerForKey:key])*60;
}

- (void)showReminderIfAllowed:(ReminderKind)kind {
    if([self isInQuietHours]) return;
    [self showReminder:kind];
}
- (NSColor *)loadBackgroundColor {
    NSData *d=[[NSUserDefaults standardUserDefaults] dataForKey:BgColorKey];
    return d?[NSKeyedUnarchiver unarchivedObjectOfClass:[NSColor class] fromData:d error:nil]:nil;
}
- (void)showReminder:(ReminderKind)kind {
    [self closeAllReminders];
    NSScreen *s=NSScreen.mainScreen?:NSScreen.screens.firstObject;
    NSRect sf=s?s.visibleFrame:NSMakeRect(0,0,1440,900);
    CGFloat pct=[self clampedIntegerForKey:PopupPercentKey min:50 max:95]/100.0;
    CGFloat w=MAX(620,sf.size.width*pct);
    NSRect f=NSMakeRect(NSMidX(sf)-w/2,NSMinY(sf),w,sf.size.height);
    ReminderWindow *win=[[ReminderWindow alloc] initWithContentRect:f styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    win.level=NSScreenSaverWindowLevel;
    win.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary|NSWindowCollectionBehaviorStationary;
    win.releasedWhenClosed=NO;win.canHide=NO;win.opaque=NO;win.hasShadow=YES;
    win.backgroundColor=NSColor.clearColor;
    CGFloat fontScale=MAX(0.4, MIN(0.9, w/1670.0));
    win.contentView=[self reminderViewForKind:kind fontScale:fontScale];
    self.currentReminderWindow=win;self.currentReminderKind=kind;
        [self.reminderWindows addObject:win];[NSApp activateIgnoringOtherApps:YES];[win makeKeyAndOrderFront:nil];
    NSInteger ds=[self clampedIntegerForKey:DismissSecondsKey min:0 max:600];
    self.dismissRemainingSeconds=ds;
    if(ds>0){
        self.countdownLabel.stringValue=[NSString stringWithFormat:@"\xe5\x89\xa9\xe4\xbd\x99 %ld\xe7\xa7\x92",(long)ds];[self.countdownLabel invalidateIntrinsicContentSize];
        __weak typeof(self) ws=self;
        self.dismissTimer=[NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t){
            __strong typeof(ws) ss=ws;if(!ss)return;
            ss.dismissRemainingSeconds--;
            if(ss.dismissRemainingSeconds>0){ss.countdownLabel.stringValue=[NSString stringWithFormat:@"\xe5\x89\xa9\xe4\xbd\x99 %ld\xe7\xa7\x92",(long)ss.dismissRemainingSeconds];[ss.countdownLabel invalidateIntrinsicContentSize];}
            else{[t invalidate];ss.dismissTimer=nil;[ss recordActionWithKind:ss.currentReminderKind action:ActionTypeDismissed];[ss closeAllReminders];}
        }];
    }
}

- (NSString *)actionTextForKey:(NSString *)key {
    return [[NSUserDefaults standardUserDefaults] stringForKey:key];
}
- (NSFont *)customFontWithSize:(CGFloat)sz weight:(NSFontWeight)w {
    NSString *fn=[[NSUserDefaults standardUserDefaults] stringForKey:FontNameKey]?:@"PingFang SC";
    return [NSFont fontWithName:fn size:sz]?:[NSFont systemFontOfSize:sz weight:w];
}
- (NSColor *)customFontBgColor {
    NSData *d=[[NSUserDefaults standardUserDefaults] dataForKey:FontBgColorKey];
    return d?[NSKeyedUnarchiver unarchivedObjectOfClass:[NSColor class] fromData:d error:nil]:nil;
}
- (CGFloat)customFontOpacity {
    return MIN(1,MAX(0,[[NSUserDefaults standardUserDefaults] doubleForKey:FontOpacityKey]));
}
- (NSColor *)customFontColor {
    NSData *d=[[NSUserDefaults standardUserDefaults] dataForKey:FontColorKey];
    return d?[NSKeyedUnarchiver unarchivedObjectOfClass:[NSColor class] fromData:d error:nil]:nil;
}
- (NSColor *)customButtonColor {
    NSData *d=[[NSUserDefaults standardUserDefaults] dataForKey:ButtonColorKey];
    return d?[NSKeyedUnarchiver unarchivedObjectOfClass:[NSColor class] fromData:d error:nil]:nil;
}
- (NSColor *)customButtonTextColor {
    NSData *d=[[NSUserDefaults standardUserDefaults] dataForKey:ButtonTextColorKey];
    return d?[NSKeyedUnarchiver unarchivedObjectOfClass:[NSColor class] fromData:d error:nil]:nil;
}
- (CGFloat)customScaleForKey:(NSString *)key {
    CGFloat v=[[NSUserDefaults standardUserDefaults] doubleForKey:key];
    if(v<=0)v=1.0;
    return MIN(1.6,MAX(0.6,v));
}

- (NSView *)reminderViewForKind:(ReminderKind)kind fontScale:(CGFloat)fontScale {
    NSString *mrk=kind==ReminderKindStand?@"\xe2\x86\x9f":@"\xe2\x97\x8c";
    NSString *ttl=kind==ReminderKindStand?@"\xe8\xaf\xa5\xe7\xab\x99\xe8\xb5\xb7\xe6\x9d\xa5\xe4\xba\x86":@"\xe8\xaf\xa5\xe5\x96\x9d\xe6\xb0\xb4\xe4\xba\x86";
    NSString *sub=kind==ReminderKindStand?@"\xe8\xb5\xb7\xe8\xba\xab\xe6\xb4\xbb\xe5\x8a\xa8\xe4\xb8\x80\xe4\xb8\x8b\xef\xbc\x8c\xe4\xbc\xb8\xe5\xb1\x95\xe8\x82\xa9\xe9\xa2\x88\xe5\x92\x8c\xe8\x85\xb0\xe8\x83\x8c\xe3\x80\x82":@"\xe8\xa1\xa5\xe4\xb8\x80\xe6\x9d\xaf\xe6\xb0\xb4\xef\xbc\x8c\xe8\xae\xa9\xe8\xba\xab\xe4\xbd\x93\xe7\xbc\x93\xe4\xb8\x80\xe5\x8f\xa3\xe6\xb0\x94\xe3\x80\x82";
    NSColor *ac=kind==ReminderKindStand?[NSColor colorWithCalibratedRed:0.06 green:0.55 blue:0.42 alpha:1]:[NSColor colorWithCalibratedRed:0.10 green:0.44 blue:0.78 alpha:1];
    NSString *pa=kind==ReminderKindStand?[self actionTextForKey:ActionText1Key]:[self actionTextForKey:ActionText2Key];
    NSString *po=[self actionTextForKey:ActionText3Key];
    NSView *v=[[NSView alloc] initWithFrame:NSZeroRect];
    v.wantsLayer=YES;
    NSColor *bgc=[self loadBackgroundColor];
    CGFloat bo=MIN(1,MAX(0,[[NSUserDefaults standardUserDefaults] doubleForKey:BgOpacityKey]));
    v.layer.backgroundColor=bgc?[bgc colorWithAlphaComponent:bo].CGColor:[[NSColor.windowBackgroundColor colorWithAlphaComponent:0.98] CGColor];
    NSStackView *os=[[NSStackView alloc] initWithFrame:NSZeroRect];
    os.orientation=NSUserInterfaceLayoutOrientationVertical;os.alignment=NSLayoutAttributeCenterX;os.spacing=20;os.translatesAutoresizingMaskIntoConstraints=NO;
    CGFloat contentScale=fontScale*[self customScaleForKey:ReminderContentScaleKey];
    CGFloat buttonScale=fontScale*[self customScaleForKey:ButtonScaleKey];
    NSTextField *ml=[self label:mrk font:[self customFontWithSize:170*contentScale weight:NSFontWeightBlack] color:ac];
    NSTextField *tl=[self label:ttl font:[self customFontWithSize:76*contentScale weight:NSFontWeightHeavy] color:NSColor.labelColor];
    NSTextField *sl=[self label:sub font:[self customFontWithSize:28*contentScale weight:NSFontWeightMedium] color:NSColor.secondaryLabelColor];
    CGFloat bw=240*buttonScale,bh=87*buttonScale;
    NSButton *pb=[self styledButton:pa tag:kind fontSize:23*buttonScale weight:NSFontWeightBold width:bw height:bh cornerRadius:0 color:ac];
    pb.action=@selector(primaryActionPressed:);
    NSButton *pb2=[self styledButton:po tag:kind fontSize:23*buttonScale weight:NSFontWeightBold width:bw height:bh cornerRadius:0 color:[NSColor colorWithCalibratedRed:0.65 green:0.65 blue:0.68 alpha:1]];
    pb2.action=@selector(postponeActionPressed:);
    NSStackView *ar=[[NSStackView alloc] initWithFrame:NSZeroRect];
    ar.orientation=NSUserInterfaceLayoutOrientationHorizontal;ar.spacing=18;ar.alignment=NSLayoutAttributeCenterY;ar.translatesAutoresizingMaskIntoConstraints=NO;
    [ar addArrangedSubview:pb];[ar addArrangedSubview:pb2];
    NSString *st=[NSString stringWithFormat:@"%ld \xe5\x88\x86\xe9\x92\x9f\xe5\x90\x8e",(long)[self clampedIntegerForKey:SnoozeMinutesKey min:1 max:180]];
    NSButton *sn=[self styledButton:st tag:kind fontSize:25*buttonScale weight:NSFontWeightSemibold width:bw height:bh cornerRadius:0 color:[NSColor colorWithCalibratedRed:0.5 green:0.5 blue:0.52 alpha:1]];
    sn.action=@selector(snooze:);
    self.countdownLabel=[NSTextField labelWithString:@""];self.countdownLabel.font=[self customFontWithSize:14*contentScale weight:NSFontWeightRegular];self.countdownLabel.textColor=NSColor.secondaryLabelColor;self.countdownLabel.alignment=NSTextAlignmentCenter;[self.countdownLabel.widthAnchor constraintEqualToConstant:90*contentScale].active=YES;[ar addArrangedSubview:self.countdownLabel];
    NSStackView *dr=[[NSStackView alloc] initWithFrame:NSZeroRect];
    dr.orientation=NSUserInterfaceLayoutOrientationHorizontal;dr.spacing=18;dr.alignment=NSLayoutAttributeCenterY;dr.translatesAutoresizingMaskIntoConstraints=NO;
    [dr addArrangedSubview:sn];
    [os addArrangedSubview:ml];[os addArrangedSubview:tl];[os addArrangedSubview:sl];[os addArrangedSubview:ar];[os addArrangedSubview:dr];
    [v addSubview:os];
    [NSLayoutConstraint activateConstraints:@[[os.centerXAnchor constraintEqualToAnchor:v.centerXAnchor],[os.centerYAnchor constraintEqualToAnchor:v.centerYAnchor],[os.leadingAnchor constraintGreaterThanOrEqualToAnchor:v.leadingAnchor constant:48],[os.trailingAnchor constraintLessThanOrEqualToAnchor:v.trailingAnchor constant:-48]]];
    // Apply custom font settings
    NSColor *fc=[self customFontColor]; NSColor *fbc=[self customFontBgColor]; CGFloat fo=[self customFontOpacity];
    for(NSTextField *lbl in @[ml,tl,sl,self.countdownLabel]){if(fc)lbl.textColor=fc;if(fbc){lbl.drawsBackground=YES;lbl.backgroundColor=fbc;}lbl.alphaValue=fo;}
    return v;
}

- (NSTextField *)label:(NSString *)text font:(NSFont *)font color:(NSColor *)color {
    NSTextField *l=[NSTextField labelWithString:text];l.font=font;l.textColor=color;l.alignment=NSTextAlignmentCenter;l.maximumNumberOfLines=2;return l;
}

- (NSButton *)styledButton:(NSString *)title tag:(ReminderKind)tag fontSize:(CGFloat)fs weight:(NSFontWeight)w width:(CGFloat)wid height:(CGFloat)hei cornerRadius:(CGFloat)cr color:(NSColor *)color {
    RoundedActionButton *b=[[RoundedActionButton alloc] initWithFrame:NSZeroRect];
    b.title=title; b.tag=tag; b.target=self; b.font=[NSFont systemFontOfSize:fs weight:w];
    [b setButtonType:NSButtonTypeMomentaryChange];[b setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSInteger st=[[NSUserDefaults standardUserDefaults] integerForKey:ButtonStyleKey];
    NSColor *bc=[self customButtonColor]?:color;
    NSColor *tc=[self customButtonTextColor]?:NSColor.whiteColor;
    switch(st){
        case 1: b.fillColor=[bc colorWithAlphaComponent:0.88];b.titleColor=tc;b.cornerRadius=hei/2;break;
        case 2: b.fillColor=[[bc blendedColorWithFraction:0.78 ofColor:NSColor.whiteColor] colorWithAlphaComponent:0.96];b.titleColor=tc;b.cornerRadius=14;break;
        case 3: b.fillColor=[bc colorWithAlphaComponent:0.30];b.titleColor=tc;b.cornerRadius=hei/2;break;
        default: b.fillColor=[bc colorWithAlphaComponent:0.88];b.titleColor=tc;b.cornerRadius=hei/2;break;
    }
    b.cell.wraps=NO;b.cell.lineBreakMode=NSLineBreakByTruncatingTail;
    if(wid>0)[b.widthAnchor constraintEqualToConstant:wid].active=YES;
    if(hei>0)[b.heightAnchor constraintEqualToConstant:hei].active=YES;
    return b;
}

- (void)recordActionWithKind:(ReminderKind)kind action:(ActionType)action {
    if([self.testReminderKinds containsObject:@(kind)]){[self.testReminderKinds removeObject:@(kind)];return;}
    NSMutableArray *r=[[[NSUserDefaults standardUserDefaults] arrayForKey:RecordsKey] mutableCopy]?:[NSMutableArray array];
    [r addObject:@{@"kind":@(kind),@"action":@(action),@"time":@([[NSDate date] timeIntervalSince1970])}];
    [[NSUserDefaults standardUserDefaults] setObject:r forKey:RecordsKey];
}
- (void)primaryActionPressed:(id)sender {
    ReminderKind k=(ReminderKind)[sender tag];
    [self recordActionWithKind:k action:(k==ReminderKindStand?ActionTypeStandNow:ActionTypeAlreadyDrank)];[self closeAllReminders];
}
- (void)postponeActionPressed:(id)sender {
    [self recordActionWithKind:(ReminderKind)[sender tag] action:ActionTypeNextTime];[self closeAllReminders];
}
- (void)closeAllReminders{[self.dismissTimer invalidate];self.dismissTimer=nil;self.countdownLabel=nil;self.currentReminderWindow=nil;for(NSWindow *w in self.reminderWindows)[w close];[self.reminderWindows removeAllObjects];}
- (void)snooze:(id)sender{
    ReminderKind k=[sender respondsToSelector:@selector(tag)]?(ReminderKind)[sender tag]:ReminderKindStand;
    [self recordActionWithKind:k action:ActionTypeSnoozed];[self closeAllReminders];
    [NSTimer scheduledTimerWithTimeInterval:[self intervalForKey:SnoozeMinutesKey] repeats:NO block:^(NSTimer*t){[self showReminderIfAllowed:k];}];
}
- (void)testStand:(id)sender{if(!self.testReminderKinds)self.testReminderKinds=[NSMutableSet set];[self.testReminderKinds addObject:@(ReminderKindStand)];[self showReminder:ReminderKindStand];}
- (void)testWater:(id)sender{if(!self.testReminderKinds)self.testReminderKinds=[NSMutableSet set];[self.testReminderKinds addObject:@(ReminderKindWater)];[self showReminder:ReminderKindWater];}
- (void)standTimerFired:(id)sender{[self showReminderIfAllowed:ReminderKindStand];}
- (void)waterTimerFired:(id)sender{[self showReminderIfAllowed:ReminderKindWater];}
- (void)restartTimers:(id)sender{[self closeAllReminders];[self scheduleTimers];}



- (void)populateFontMenu {
    [self.fontSelector removeAllItems];
    NSArray *f=@[@"PingFang SC",@"STHeiti",@"Songti SC",@"STKaiti",@"Hiragino Sans GB",@"AppleSDGothicNeo",@"MarkerFelt",@"SnellRoundhand",@"Bradley Hand",@"Chalkboard",@"Noteworthy",@"Comic Sans MS",@"Chalkduster",@"Papyrus"];
    NSDictionary *n=@{@"PingFang SC":@"\xe8\x8b\xb9\xe6\x96\xb9",@"STHeiti":@"\xe5\x8d\x8e\xe6\x96\x87\xe9\xbb\x91\xe4\xbd\x93",@"Songti SC":@"\xe5\xae\x8b\xe4\xbd\x93",@"STKaiti":@"\xe5\x8d\x8e\xe6\x96\x87\xe6\xa5\xb7\xe4\xbd\x93",@"Hiragino Sans GB":@"\xe5\x86\xac\xe9\x9d\x92\xe9\xbb\x91\xe4\xbd\x93"};
    NSString *cf=[[NSUserDefaults standardUserDefaults] stringForKey:FontNameKey]?:@"PingFang SC";
    NSInteger si=0;
    for(NSInteger i=0;i<f.count;i++){NSString *fn=f[i];[self.fontSelector addItemWithTitle:n[fn]?:fn];[[self.fontSelector lastItem] setRepresentedObject:fn];if([fn isEqualToString:cf])si=i;}
    [self.fontSelector selectItemAtIndex:si];
}

- (void)populateButtonStyleMenu {
    [self.buttonStyleSelector removeAllItems];
    NSArray *s=@[@"\xe5\x9c\x86\xe8\xa7\x92",@"\xe6\xb8\x85\xe7\x88\xbd",@"\xe7\xae\x80\xe7\xba\xa6",@"\xe8\xbd\xbb\xe7\x9b\x88"];
    NSInteger c=[[NSUserDefaults standardUserDefaults] integerForKey:ButtonStyleKey];
    for(NSInteger i=0;i<s.count;i++){[self.buttonStyleSelector addItemWithTitle:s[i]];[[self.buttonStyleSelector lastItem] setTag:i];}
    [self.buttonStyleSelector selectItemAtIndex:c];
}

- (void)populateSettingsFields {
    NSUserDefaults *d=[NSUserDefaults standardUserDefaults];
    self.standMinutesField.integerValue=[self clampedIntegerForKey:StandMinutesKey min:1 max:720];
    self.waterMinutesField.integerValue=[self clampedIntegerForKey:WaterMinutesKey min:1 max:720];
    self.snoozeMinutesField.integerValue=[self clampedIntegerForKey:SnoozeMinutesKey min:1 max:180];
    self.popupPercentField.integerValue=[d integerForKey:PopupPercentKey];
    self.launchAtLoginButton.state=[d boolForKey:LaunchAtLoginKey]?NSControlStateValueOn:NSControlStateValueOff;
    self.quietHoursButton.state=[d boolForKey:QuietHoursEnabledKey]?NSControlStateValueOn:NSControlStateValueOff;
    self.quietStartField.stringValue=[d stringForKey:QuietStartKey]?:@"22:00";self.quietEndField.stringValue=[d stringForKey:QuietEndKey]?:@"08:00";
    self.actionText1Field.stringValue=[d stringForKey:ActionText1Key]?:@"\xe7\x8e\xb0\xe5\x9c\xa8\xe7\xab\x99";self.actionText2Field.stringValue=[d stringForKey:ActionText2Key]?:@"\xe5\xb7\xb2\xe5\x96\x9d";self.actionText3Field.stringValue=[d stringForKey:ActionText3Key]?:@"\xe4\xb8\x8b\xe6\xac\xa1\xe5\x90\xa7";
    self.dailyPromptField.stringValue=[d stringForKey:DailyPromptKey]?:@"今日达成率为{rate}%。";self.weeklyPromptField.stringValue=[d stringForKey:WeeklyPromptKey]?:@"本周达成率为{rate}%。";self.monthlyPromptField.stringValue=[d stringForKey:MonthlyPromptKey]?:@"本月达成率为{rate}%。";self.yearlyPromptField.stringValue=[d stringForKey:YearlyPromptKey]?:@"本年达成率为{rate}%。";
    self.praiseHighField.stringValue=[d stringForKey:PraiseHighKey]?:@"您是天底下最好的宝宝～";self.praiseGoodField.stringValue=[d stringForKey:PraiseGoodKey]?:@"很棒，继续加油！";self.praiseMediumField.stringValue=[d stringForKey:PraiseMediumKey]?:@"还不错，再加把劲！";self.praiseLowField.stringValue=[d stringForKey:PraiseLowKey]?:@"要多注意站立和喝水哦！";
    NSInteger bg=round([d doubleForKey:BgOpacityKey]*100);self.bgOpacitySlider.integerValue=bg;self.bgOpacityLabel.stringValue=[NSString stringWithFormat:@"%ld%%",(long)bg];
    [self populateFontMenu];[self populateButtonStyleMenu];
    NSData *cd=[d dataForKey:FontBgColorKey];self.fontBgColorWell.color=cd?[NSKeyedUnarchiver unarchivedObjectOfClass:[NSColor class] fromData:cd error:nil]:[NSColor clearColor];
    NSData *fcd=[d dataForKey:FontColorKey];self.fontColorWell.color=fcd?[NSKeyedUnarchiver unarchivedObjectOfClass:[NSColor class] fromData:fcd error:nil]:[NSColor colorWithCalibratedRed:0.2 green:0.5 blue:0.8 alpha:1];
    NSData *bcd=[d dataForKey:ButtonColorKey];self.buttonColorWell.color=bcd?[NSKeyedUnarchiver unarchivedObjectOfClass:[NSColor class] fromData:bcd error:nil]:[NSColor colorWithCalibratedRed:0.10 green:0.44 blue:0.78 alpha:1];
    NSData *btcd=[d dataForKey:ButtonTextColorKey];self.buttonTextColorWell.color=btcd?[NSKeyedUnarchiver unarchivedObjectOfClass:[NSColor class] fromData:btcd error:nil]:NSColor.whiteColor;
    NSData *bgcd=[d dataForKey:BgColorKey];self.bgColorWell.color=bgcd?[NSKeyedUnarchiver unarchivedObjectOfClass:[NSColor class] fromData:bgcd error:nil]:[NSColor colorWithCalibratedRed:0.9 green:0.9 blue:0.95 alpha:1];
    NSInteger fo=round([d doubleForKey:FontOpacityKey]*100);self.fontOpacitySlider.doubleValue=fo;self.fontOpacityLabel.stringValue=[NSString stringWithFormat:@"%ld%%",(long)fo];
    NSInteger bs=round([self customScaleForKey:ButtonScaleKey]*100);self.buttonScaleSlider.doubleValue=bs;self.buttonScaleLabel.stringValue=[NSString stringWithFormat:@"%ld%%",(long)bs];
    NSInteger rs=round([self customScaleForKey:ReminderContentScaleKey]*100);self.reminderContentScaleSlider.doubleValue=rs;self.reminderContentScaleLabel.stringValue=[NSString stringWithFormat:@"%ld%%",(long)rs];
    self.dismissSecondsField.integerValue=[self clampedIntegerForKey:DismissSecondsKey min:0 max:600];
    self.settingsStatusLabel.stringValue=@"";self.loginStatusField.stringValue=[self loginStatusText];
}

- (void)bgOpacityChanged:(id)s {self.bgOpacityLabel.stringValue=[NSString stringWithFormat:@"%.0f%%",self.bgOpacitySlider.doubleValue];}
- (void)fontOpacityChanged:(id)s {self.fontOpacityLabel.stringValue=[NSString stringWithFormat:@"%.0f%%",self.fontOpacitySlider.doubleValue];}
- (void)buttonScaleChanged:(id)s {self.buttonScaleLabel.stringValue=[NSString stringWithFormat:@"%.0f%%",self.buttonScaleSlider.doubleValue];}
- (void)reminderContentScaleChanged:(id)s {self.reminderContentScaleLabel.stringValue=[NSString stringWithFormat:@"%.0f%%",self.reminderContentScaleSlider.doubleValue];}
- (void)fontChanged:(id)s{}

- (NSBox *)makeSeparator {
    NSBox *s=[[NSBox alloc] initWithFrame:NSZeroRect];s.boxType=NSBoxSeparator;s.translatesAutoresizingMaskIntoConstraints=NO;
    [s.heightAnchor constraintEqualToConstant:1].active=YES;return s;
}
- (NSTextField *)settingsLabel:(NSString *)text {
    NSTextField *l=[NSTextField labelWithString:text];l.font=[NSFont systemFontOfSize:15 weight:NSFontWeightMedium];l.alignment=NSTextAlignmentRight;l.translatesAutoresizingMaskIntoConstraints=NO;return l;
}
- (NSTextField *)numberField {
    NSTextField *f=[[NSTextField alloc] initWithFrame:NSZeroRect];f.alignment=NSTextAlignmentRight;f.font=[NSFont systemFontOfSize:15 weight:NSFontWeightRegular];
    f.translatesAutoresizingMaskIntoConstraints=NO;[f.widthAnchor constraintEqualToConstant:120].active=YES;
    f.bezelStyle=NSTextFieldRoundedBezel;return f;
}
- (NSTextField *)textField {
    NSTextField *f=[[NSTextField alloc] initWithFrame:NSZeroRect];f.alignment=NSTextAlignmentRight;f.font=[NSFont systemFontOfSize:15 weight:NSFontWeightRegular];
    f.translatesAutoresizingMaskIntoConstraints=NO;[f.widthAnchor constraintEqualToConstant:200].active=YES;
    f.bezelStyle=NSTextFieldRoundedBezel;return f;
}
- (NSButton *)smallButton:(NSString *)title action:(SEL)action {
    NSButton *b=[[NSButton alloc] initWithFrame:NSZeroRect];b.title=title;b.target=self;b.action=action;b.bezelStyle=NSBezelStyleRounded;b.controlSize=NSControlSizeRegular;b.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium];b.translatesAutoresizingMaskIntoConstraints=NO;[b.heightAnchor constraintEqualToConstant:30].active=YES;return b;
}
- (NSInteger)clampedIntegerForKey:(NSString *)k min:(NSInteger)mn max:(NSInteger)mx {
    return MIN(mx,MAX(mn,[[NSUserDefaults standardUserDefaults] integerForKey:k]));
}
- (NSInteger)clampedFieldValue:(NSTextField *)f min:(NSInteger)mn max:(NSInteger)mx {return MIN(mx,MAX(mn,f.integerValue));}

- (void)saveSettings:(id)sender {
    NSString *qs=[self normalizedTimeString:self.quietStartField.stringValue fallback:@"22:00"],*qe=[self normalizedTimeString:self.quietEndField.stringValue fallback:@"08:00"];
    NSUserDefaults *d=[NSUserDefaults standardUserDefaults];
    [d setInteger:[self clampedFieldValue:self.standMinutesField min:1 max:720] forKey:StandMinutesKey];
    [d setInteger:[self clampedFieldValue:self.waterMinutesField min:1 max:720] forKey:WaterMinutesKey];
    [d setInteger:[self clampedFieldValue:self.snoozeMinutesField min:1 max:180] forKey:SnoozeMinutesKey];
    [d setInteger:[self clampedFieldValue:self.popupPercentField min:50 max:95] forKey:PopupPercentKey];
    [d setInteger:[self clampedFieldValue:self.dismissSecondsField min:0 max:600] forKey:DismissSecondsKey];
    [d setBool:self.launchAtLoginButton.state==NSControlStateValueOn forKey:LaunchAtLoginKey];
    [d setBool:self.quietHoursButton.state==NSControlStateValueOn forKey:QuietHoursEnabledKey];
    [d setObject:qs forKey:QuietStartKey];[d setObject:qe forKey:QuietEndKey];
    [d synchronize];[self scheduleTimers];
    self.quietStartField.stringValue=qs;self.quietEndField.stringValue=qe;self.settingsStatusLabel.stringValue=[self applyLaunchAtLoginPreference];self.loginStatusField.stringValue=[self loginStatusText];
}

- (void)saveBasicSettings:(id)sender {
    [self saveSettings:sender];
}

- (void)saveBackgroundSettings:(id)sender {
    NSUserDefaults *d=[NSUserDefaults standardUserDefaults];
    [d setDouble:self.bgOpacitySlider.doubleValue/100.0 forKey:BgOpacityKey];
    if(self.bgColorWell.color&&![self.bgColorWell.color isEqual:[NSColor clearColor]]){
        [d setObject:[NSKeyedArchiver archivedDataWithRootObject:self.bgColorWell.color requiringSecureCoding:YES error:nil] forKey:BgColorKey];
    }else{[d removeObjectForKey:BgColorKey];}
    [d synchronize];
    self.settingsStatusLabel.stringValue=@"\u2713 背景已保存";
}

- (void)resetBackgroundSettings:(id)sender {
    NSUserDefaults *d=[NSUserDefaults standardUserDefaults];
    [d removeObjectForKey:BgColorKey];
    [d removeObjectForKey:BgOpacityKey];
    [d synchronize];
    [self populateSettingsFields];
    self.settingsStatusLabel.stringValue=@"\u2713 背景已还原";
}

- (void)saveFontButtonSettings:(id)sender {
    NSUserDefaults *d=[NSUserDefaults standardUserDefaults];
    NSString *fn=[self.fontSelector.selectedItem representedObject]?:@"PingFang SC";
    [d setObject:fn forKey:FontNameKey];
    if(self.fontBgColorWell.color&&![self.fontBgColorWell.color isEqual:[NSColor clearColor]]){
        [d setObject:[NSKeyedArchiver archivedDataWithRootObject:self.fontBgColorWell.color requiringSecureCoding:YES error:nil] forKey:FontBgColorKey];
    }else{[d removeObjectForKey:FontBgColorKey];}
    if(self.fontColorWell.color){
        [d setObject:[NSKeyedArchiver archivedDataWithRootObject:self.fontColorWell.color requiringSecureCoding:YES error:nil] forKey:FontColorKey];
    }else{[d removeObjectForKey:FontColorKey];}
    if(self.buttonColorWell.color){
        [d setObject:[NSKeyedArchiver archivedDataWithRootObject:self.buttonColorWell.color requiringSecureCoding:YES error:nil] forKey:ButtonColorKey];
    }else{[d removeObjectForKey:ButtonColorKey];}
    if(self.buttonTextColorWell.color){
        [d setObject:[NSKeyedArchiver archivedDataWithRootObject:self.buttonTextColorWell.color requiringSecureCoding:YES error:nil] forKey:ButtonTextColorKey];
    }else{[d removeObjectForKey:ButtonTextColorKey];}
    [d setDouble:self.fontOpacitySlider.doubleValue/100.0 forKey:FontOpacityKey];
    [d setDouble:self.buttonScaleSlider.doubleValue/100.0 forKey:ButtonScaleKey];
    [d setDouble:self.reminderContentScaleSlider.doubleValue/100.0 forKey:ReminderContentScaleKey];
    [d setInteger:self.buttonStyleSelector.selectedTag forKey:ButtonStyleKey];
    [d synchronize];
    self.settingsStatusLabel.stringValue=@"\u2713 字体已保存";
}

- (void)resetFontButtonSettings:(id)sender {
    NSUserDefaults *d=[NSUserDefaults standardUserDefaults];
    [d removeObjectForKey:FontNameKey];
    [d removeObjectForKey:FontBgColorKey];
    [d removeObjectForKey:FontColorKey];
    [d removeObjectForKey:FontOpacityKey];
    [d removeObjectForKey:ButtonStyleKey];
    [d removeObjectForKey:ButtonColorKey];
    [d removeObjectForKey:ButtonTextColorKey];
    [d removeObjectForKey:ButtonScaleKey];
    [d removeObjectForKey:ReminderContentScaleKey];
    [d synchronize];
    [self populateSettingsFields];
    self.settingsStatusLabel.stringValue=@"\u2713 字体已还原";
}

- (void)saveCustomTextSettings:(id)sender {
    NSUserDefaults *d=[NSUserDefaults standardUserDefaults];
    [d setObject:self.actionText1Field.stringValue?:@"" forKey:ActionText1Key];
    [d setObject:self.actionText2Field.stringValue?:@"" forKey:ActionText2Key];
    [d setObject:self.actionText3Field.stringValue?:@"" forKey:ActionText3Key];
    [d synchronize];
    self.settingsStatusLabel.stringValue=@"\u2713 文本已保存";
}

- (void)saveAnalysisSettings:(id)sender {
    NSUserDefaults *d=[NSUserDefaults standardUserDefaults];
    [d setObject:self.dailyPromptField.stringValue?:@"" forKey:DailyPromptKey];
    [d setObject:self.weeklyPromptField.stringValue?:@"" forKey:WeeklyPromptKey];
    [d setObject:self.monthlyPromptField.stringValue?:@"" forKey:MonthlyPromptKey];
    [d setObject:self.yearlyPromptField.stringValue?:@"" forKey:YearlyPromptKey];
    [d setObject:self.praiseHighField.stringValue?:@"" forKey:PraiseHighKey];
    [d setObject:self.praiseGoodField.stringValue?:@"" forKey:PraiseGoodKey];
    [d setObject:self.praiseMediumField.stringValue?:@"" forKey:PraiseMediumKey];
    [d setObject:self.praiseLowField.stringValue?:@"" forKey:PraiseLowKey];
    [d synchronize];
    self.settingsStatusLabel.stringValue=@"\u2713 统计已保存";}

- (void)resetAnalysisSettings:(id)sender {
    NSUserDefaults *d=[NSUserDefaults standardUserDefaults];
    [d removeObjectForKey:DailyPromptKey];
    [d removeObjectForKey:WeeklyPromptKey];
    [d removeObjectForKey:MonthlyPromptKey];
    [d removeObjectForKey:YearlyPromptKey];
    [d removeObjectForKey:PraiseHighKey];
    [d removeObjectForKey:PraiseGoodKey];
    [d removeObjectForKey:PraiseMediumKey];
    [d removeObjectForKey:PraiseLowKey];
    [d synchronize];
    [self populateSettingsFields];
    self.settingsStatusLabel.stringValue=@"\u2713 分析已还原";
}

- (void)applySettings:(id)sender {
    NSUserDefaults *d=[NSUserDefaults standardUserDefaults];
    if(self.actionText1Field){[d setObject:self.actionText1Field.stringValue?:@"" forKey:ActionText1Key];[d setObject:self.actionText2Field.stringValue?:@"" forKey:ActionText2Key];[d setObject:self.actionText3Field.stringValue?:@"" forKey:ActionText3Key];}
    if(self.dailyPromptField){[d setObject:self.dailyPromptField.stringValue?:@"" forKey:DailyPromptKey];[d setObject:self.weeklyPromptField.stringValue?:@"" forKey:WeeklyPromptKey];[d setObject:self.monthlyPromptField.stringValue?:@"" forKey:MonthlyPromptKey];[d setObject:self.yearlyPromptField.stringValue?:@"" forKey:YearlyPromptKey];}
    if(self.praiseHighField){[d setObject:self.praiseHighField.stringValue?:@"" forKey:PraiseHighKey];[d setObject:self.praiseGoodField.stringValue?:@"" forKey:PraiseGoodKey];[d setObject:self.praiseMediumField.stringValue?:@"" forKey:PraiseMediumKey];[d setObject:self.praiseLowField.stringValue?:@"" forKey:PraiseLowKey];}
    if(self.bgOpacitySlider)[d setDouble:self.bgOpacitySlider.doubleValue/100.0 forKey:BgOpacityKey];
    if(self.fontSelector){
        NSString *fn=[self.fontSelector.selectedItem representedObject]?:@"PingFang SC";[d setObject:fn forKey:FontNameKey];
        if(self.fontBgColorWell.color&&![self.fontBgColorWell.color isEqual:[NSColor clearColor]]){[d setObject:[NSKeyedArchiver archivedDataWithRootObject:self.fontBgColorWell.color requiringSecureCoding:YES error:nil] forKey:FontBgColorKey];}else{[d removeObjectForKey:FontBgColorKey];}
        if(self.fontColorWell.color){[d setObject:[NSKeyedArchiver archivedDataWithRootObject:self.fontColorWell.color requiringSecureCoding:YES error:nil] forKey:FontColorKey];}else{[d removeObjectForKey:FontColorKey];}
        if(self.buttonColorWell.color){[d setObject:[NSKeyedArchiver archivedDataWithRootObject:self.buttonColorWell.color requiringSecureCoding:YES error:nil] forKey:ButtonColorKey];}else{[d removeObjectForKey:ButtonColorKey];}
        if(self.buttonTextColorWell.color){[d setObject:[NSKeyedArchiver archivedDataWithRootObject:self.buttonTextColorWell.color requiringSecureCoding:YES error:nil] forKey:ButtonTextColorKey];}else{[d removeObjectForKey:ButtonTextColorKey];}
        [d setDouble:self.fontOpacitySlider.doubleValue/100.0 forKey:FontOpacityKey];[d setInteger:self.buttonStyleSelector.selectedTag forKey:ButtonStyleKey];
    }
    [d synchronize];self.settingsStatusLabel.stringValue=@"\xe2\x9c\x93 \xe5\xa4\x96\xe8\xa7\x82\xe8\xae\xbe\xe7\xbd\xae\xe5\xb7\xb2\xe4\xbf\x9d\xe5\xad\x98";
}


- (BOOL)isInQuietHours {
    NSUserDefaults *d=[NSUserDefaults standardUserDefaults];if(![d boolForKey:QuietHoursEnabledKey])return NO;
    NSInteger st=[self minutesFromTimeString:[d stringForKey:QuietStartKey]],en=[self minutesFromTimeString:[d stringForKey:QuietEndKey]];
    if(st<0||en<0||st==en)return NO;
    NSDateComponents *p=[[NSCalendar currentCalendar] components:NSCalendarUnitHour|NSCalendarUnitMinute fromDate:[NSDate date]];
    NSInteger now=p.hour*60+p.minute;return (st<en)?(now>=st&&now<en):(now>=st||now<en);
}
- (NSString *)normalizedTimeString:(NSString *)v fallback:(NSString *)fb {
    NSInteger m=[self minutesFromTimeString:v];return (m<0)?fb:[NSString stringWithFormat:@"%02ld:%02ld",(long)(m/60),(long)(m%60)];
}
- (NSInteger)minutesFromTimeString:(NSString *)value {
    NSString *t=value?:@"";NSRegularExpression *rx=[NSRegularExpression regularExpressionWithPattern:@"^\\s*(\\d{1,2}):(\\d{2})\\s*$" options:0 error:nil];
    NSTextCheckingResult *m=[rx firstMatchInString:t options:0 range:NSMakeRange(0,t.length)];if(!m)return-1;
    NSInteger h=[[t substringWithRange:[m rangeAtIndex:1]] integerValue],min=[[t substringWithRange:[m rangeAtIndex:2]] integerValue];
    return (h>=0&&h<=23&&min>=0&&min<=59)?h*60+min:-1;
}

- (NSString *)applyLaunchAtLoginPreference {
    BOOL en=[[NSUserDefaults standardUserDefaults] boolForKey:LaunchAtLoginKey];
    if(@available(macOS 13.0,*)){SMAppService *sv=SMAppService.mainAppService;
        if(en&&sv.status==SMAppServiceStatusEnabled) return @"\xe2\x9c\x93 \xe5\xb7\xb2\xe5\x90\xaf\xe7\x94\xa8";
        if(!en&&sv.status==SMAppServiceStatusNotRegistered) return @"\xe2\x97\x8b \xe6\x9c\xaa\xe5\x90\xaf\xe7\x94\xa8";
        NSError *e=nil;BOOL ok=en?[sv registerAndReturnError:&e]:[sv unregisterAndReturnError:&e];
        if(ok)return en?@"\xe2\x9c\x93 \xe5\xb7\xb2\xe8\xaf\xb7\xe6\xb1\x82":@"\xe2\x97\x8b \xe5\xb7\xb2\xe5\x85\xb3\xe9\x97\xad";
        return [NSString stringWithFormat:@"\xe2\x9c\x97 %@",e.localizedDescription?:@"\xe6\x9c\xaa\xe7\x9f\xa5\xe9\x94\x99\xe8\xaf\xaf"];}
    return @"\xe2\x9c\x97 \xe9\x9c\x80\xe8\xa6\x81 macOS 13";
}
- (NSString *)loginStatusText {
    if(@available(macOS 13.0,*)){switch(SMAppService.mainAppService.status){case SMAppServiceStatusEnabled:return @"\xe2\x9c\x93 \xe5\xb7\xb2\xe5\x90\xaf\xe7\x94\xa8";case SMAppServiceStatusRequiresApproval:return @"\xe2\x9a\xa0 \xe9\x9c\x80\xe8\xa6\x81\xe5\x85\x81\xe8\xae\xb8";case SMAppServiceStatusNotRegistered:return @"\xe2\x97\x8b \xe6\x9c\xaa\xe5\x90\xaf\xe7\x94\xa8";case SMAppServiceStatusNotFound:return @"\xe2\x9c\x97 \xe6\x9c\xaa\xe6\x89\xbe\xe5\x88\xb0\xe6\x9c\x8d\xe5\x8a\xa1";}}
    return @"\xe2\x9c\x97 \xe9\x9c\x80\xe8\xa6\x81 macOS 13";
}
- (void)openLoginItemsSettings:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.LoginItems-Settings.extension"]];
}

- (NSArray *)recordsInPeriod:(StatsPeriod)period {
    NSArray *raw=[[NSUserDefaults standardUserDefaults] arrayForKey:RecordsKey]?:@[];
    NSCalendar *cal=[NSCalendar currentCalendar];NSDate *now=[NSDate date];NSDate *st;
    switch(period){case StatsPeriodDay:st=[cal startOfDayForDate:now];break;case StatsPeriodWeek:{NSDateComponents*c=[cal components:NSCalendarUnitYearForWeekOfYear|NSCalendarUnitWeekOfYear fromDate:now];st=[cal dateFromComponents:c];break;}case StatsPeriodMonth:{NSDateComponents*c=[cal components:NSCalendarUnitYear|NSCalendarUnitMonth fromDate:now];st=[cal dateFromComponents:c];break;}case StatsPeriodYear:{NSDateComponents*c=[cal components:NSCalendarUnitYear fromDate:now];st=[cal dateFromComponents:c];break;}}
    NSTimeInterval si=[st timeIntervalSince1970];NSMutableArray *r=[NSMutableArray array];
    for(NSDictionary *d in raw){if([d[@"time"] doubleValue]>=si)[r addObject:d];}return r;
}
- (NSDictionary *)aggregateStatsForPeriod:(StatsPeriod)period {
    NSMutableDictionary *c=[NSMutableDictionary dictionary];
    for(NSDictionary *r in [self recordsInPeriod:period]){NSInteger a=[r[@"action"] integerValue];c[@(a)]=@([c[@(a)] integerValue]+1);}return c;
}

- (void)openStats:(id)sender {
    if(!self.statsWindow)self.statsWindow=[self buildStatsWindow];
    [self refreshStatsWithPeriod:self.periodSelector?(StatsPeriod)self.periodSelector.selectedSegment:StatsPeriodWeek];
    [NSApp activateIgnoringOtherApps:YES];[self.statsWindow makeKeyAndOrderFront:nil];
}
- (NSWindow *)buildStatsWindow {
    NSWindow *win=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,640,580) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
    win.title=@"\xe7\xab\x99\xe7\xab\x8b\xe5\x96\x9d\xe6\xb0\xb4\xe7\xbb\x9f\xe8\xae\xa1";win.releasedWhenClosed=NO;[win center];
    NSView *cv=[[NSView alloc] initWithFrame:NSZeroRect];cv.translatesAutoresizingMaskIntoConstraints=NO;win.contentView=cv;
    self.periodSelector=[[NSSegmentedControl alloc] initWithFrame:NSZeroRect];[self.periodSelector setSegmentCount:4];
    [self.periodSelector setLabel:@"\xe6\x97\xa5" forSegment:0];[self.periodSelector setLabel:@"\xe5\x91\xa8" forSegment:1];[self.periodSelector setLabel:@"\xe6\x9c\x88" forSegment:2];[self.periodSelector setLabel:@"\xe5\xb9\xb4" forSegment:3];
    self.periodSelector.selectedSegment=1;self.periodSelector.target=self;self.periodSelector.action=@selector(periodChanged:);self.periodSelector.translatesAutoresizingMaskIntoConstraints=NO;
    NSButton *ab=[self smallButton:@"\xe8\xa1\x8c\xe4\xb8\xba\xe5\x88\x86\xe6\x9e\x90" action:@selector(showAnalysis:)];
    NSButton *clearBtn=[self smallButton:@"\xe6\xb8\x85\xe9\x99\xa4\xe6\x95\xb0\xe6\x8d\xae" action:@selector(clearStats:)];
    NSStackView *tb=[[NSStackView alloc] initWithFrame:NSZeroRect];tb.orientation=NSUserInterfaceLayoutOrientationHorizontal;tb.spacing=18;tb.alignment=NSLayoutAttributeCenterY;tb.translatesAutoresizingMaskIntoConstraints=NO;[tb addArrangedSubview:self.periodSelector];[tb addArrangedSubview:ab];[tb addArrangedSubview:clearBtn];
    self.analysisResultLabel=[NSTextField labelWithString:@""];self.analysisResultLabel.font=[NSFont systemFontOfSize:15 weight:NSFontWeightMedium];self.analysisResultLabel.textColor=NSColor.labelColor;self.analysisResultLabel.alignment=NSTextAlignmentCenter;self.analysisResultLabel.maximumNumberOfLines=4;self.analysisResultLabel.translatesAutoresizingMaskIntoConstraints=NO;
    self.barChart=[[BarChartView alloc] initWithFrame:NSZeroRect];self.barChart.translatesAutoresizingMaskIntoConstraints=NO;self.barChart.wantsLayer=YES;self.barChart.layer.backgroundColor=[[NSColor.controlBackgroundColor colorWithAlphaComponent:0.5] CGColor];self.barChart.layer.cornerRadius=8;
    self.pieChart=[[PieChartView alloc] initWithFrame:NSZeroRect];self.pieChart.translatesAutoresizingMaskIntoConstraints=NO;self.pieChart.wantsLayer=YES;self.pieChart.layer.backgroundColor=[[NSColor.controlBackgroundColor colorWithAlphaComponent:0.5] CGColor];self.pieChart.layer.cornerRadius=8;
    NSStackView *cr=[[NSStackView alloc] initWithFrame:NSZeroRect];cr.orientation=NSUserInterfaceLayoutOrientationHorizontal;cr.spacing=16;cr.distribution=NSStackViewDistributionFillEqually;cr.translatesAutoresizingMaskIntoConstraints=NO;[cr addArrangedSubview:self.barChart];[cr addArrangedSubview:self.pieChart];
    [cv addSubview:tb];[cv addSubview:self.analysisResultLabel];[cv addSubview:cr];
    [NSLayoutConstraint activateConstraints:@[[tb.topAnchor constraintEqualToAnchor:cv.topAnchor constant:16],[tb.centerXAnchor constraintEqualToAnchor:cv.centerXAnchor],[self.analysisResultLabel.topAnchor constraintEqualToAnchor:tb.bottomAnchor constant:12],[self.analysisResultLabel.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:20],[self.analysisResultLabel.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-20],[cr.topAnchor constraintEqualToAnchor:self.analysisResultLabel.bottomAnchor constant:8],[cr.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:12],[cr.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-12],[cr.bottomAnchor constraintEqualToAnchor:cv.bottomAnchor constant:-12],[self.barChart.heightAnchor constraintEqualToConstant:320],[self.pieChart.heightAnchor constraintEqualToConstant:320]]];
    return win;
}
- (void)periodChanged:(id)s{[self refreshStatsWithPeriod:(StatsPeriod)self.periodSelector.selectedSegment];self.analysisResultLabel.stringValue=@"";}
- (void)refreshStatsWithPeriod:(StatsPeriod)period {
    NSDictionary *s=[self aggregateStatsForPeriod:period];NSUserDefaults *d=[NSUserDefaults standardUserDefaults];
    NSDictionary *l=@{@(ActionTypeStandNow):[d stringForKey:ActionText1Key]?:@"\xe7\x8e\xb0\xe5\x9c\xa8\xe7\xab\x99",@(ActionTypeAlreadyDrank):[d stringForKey:ActionText2Key]?:@"\xe5\xb7\xb2\xe5\x96\x9d",@(ActionTypeNextTime):[d stringForKey:ActionText3Key]?:@"\xe4\xb8\x8b\xe6\xac\xa1\xe5\x90\xa7",@(ActionTypeSnoozed):@"\xe7\xa8\x8d\xe5\x90\x8e\xe6\x8f\x90\xe9\x86\x92",@(ActionTypeDismissed):@"\xe8\x87\xaa\xe5\x8a\xa8\xe5\x85\xb3\xe9\x97\xad"};
    NSArray *ac=@[[NSColor colorWithCalibratedRed:0.06 green:0.55 blue:0.42 alpha:1],[NSColor colorWithCalibratedRed:0.10 green:0.44 blue:0.78 alpha:1],[NSColor colorWithCalibratedRed:0.85 green:0.47 blue:0.16 alpha:1],[NSColor colorWithCalibratedRed:0.55 green:0.55 blue:0.58 alpha:1],[NSColor colorWithCalibratedRed:0.75 green:0.75 blue:0.78 alpha:1]];
    NSArray *ats=@[@(ActionTypeStandNow),@(ActionTypeAlreadyDrank),@(ActionTypeNextTime),@(ActionTypeSnoozed),@(ActionTypeDismissed)];
    NSMutableArray *pi=[NSMutableArray array];NSInteger idx=0;
    for(NSNumber *t in ats){NSInteger c=[s[t] integerValue];[pi addObject:@{@"label":l[t]?:@"",@"value":@(c),@"color":ac[idx]}];idx++;}
    NSArray *records=[self recordsInPeriod:period];NSCalendar *cal=[NSCalendar currentCalendar];NSDate *now=[NSDate date];NSMutableArray *bi=[NSMutableArray array];
    switch(period){
        case StatsPeriodDay:{
            NSDate *ps=[cal startOfDayForDate:now];
            for(NSInteger i=0;i<6;i++){
                NSInteger h=i*4;NSDateComponents *a=[[NSDateComponents alloc] init];a.hour=h;
                NSDateComponents *a2=[[NSDateComponents alloc] init];a2.hour=h+4;
                NSDate *bs=[cal dateByAddingComponents:a toDate:ps options:0],*be=[cal dateByAddingComponents:a2 toDate:ps options:0];
                NSTimeInterval bsi=[bs timeIntervalSince1970],bei=[be timeIntervalSince1970];
                NSInteger cnt=0;for(NSDictionary *r in records){NSTimeInterval t=[r[@"time"] doubleValue];if(t>=bsi&&t<bei)cnt++;}
                CGFloat hue=0.55+0.1*((CGFloat)i/6.0);
                [bi addObject:@{@"label":[NSString stringWithFormat:@"%ld",(long)(h+2)],@"value":@(cnt),@"color":[NSColor colorWithCalibratedHue:hue saturation:0.65 brightness:0.85 alpha:1]}];self.barChart.axisUnit=@"\xe6\x97\xb6";
            }break;
        }
        case StatsPeriodWeek:{
            NSDateComponents *wc=[cal components:NSCalendarUnitYearForWeekOfYear|NSCalendarUnitWeekOfYear fromDate:now];
            NSDate *ps=[cal dateFromComponents:wc];for(NSInteger i=0;i<7;i++){
                NSDateComponents *a=[[NSDateComponents alloc] init];a.day=i;NSDateComponents *a2=[[NSDateComponents alloc] init];a2.day=i+1;
                NSDate *bs=[cal dateByAddingComponents:a toDate:ps options:0],*be=[cal dateByAddingComponents:a2 toDate:ps options:0];
                NSTimeInterval bsi=[bs timeIntervalSince1970],bei=[be timeIntervalSince1970];
                NSInteger cnt=0;for(NSDictionary *r in records){NSTimeInterval t=[r[@"time"] doubleValue];if(t>=bsi&&t<bei)cnt++;}
                CGFloat hue=0.55+0.1*((CGFloat)i/7.0);
                [bi addObject:@{@"label":[NSString stringWithFormat:@"%ld",(long)(i+1)],@"value":@(cnt),@"color":[NSColor colorWithCalibratedHue:hue saturation:0.65 brightness:0.85 alpha:1]}];self.barChart.axisUnit=@"\xe6\x97\xa5";
            }break;
        }
        case StatsPeriodMonth:{
            NSDateComponents *mc=[cal components:NSCalendarUnitYear|NSCalendarUnitMonth fromDate:now];
            NSDate *ps=[cal dateFromComponents:mc];NSRange dmRng=[cal rangeOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitMonth forDate:now];NSInteger dim=dmRng.length;
            for(NSInteger i=0;i<5;i++){
                NSInteger ds=i*7+1,de=MIN(dim,(i+1)*7);NSDateComponents *a=[[NSDateComponents alloc] init];a.day=ds-1;
                NSDateComponents *a2=[[NSDateComponents alloc] init];a2.day=de;
                NSDate *bs=[cal dateByAddingComponents:a toDate:ps options:0],*be=[cal dateByAddingComponents:a2 toDate:ps options:0];
                NSTimeInterval bsi=[bs timeIntervalSince1970],bei=[be timeIntervalSince1970];
                NSInteger cnt=0;for(NSDictionary *r in records){NSTimeInterval t=[r[@"time"] doubleValue];if(t>=bsi&&t<bei)cnt++;}
                CGFloat hue=0.55+0.1*((CGFloat)i/5.0);
                [bi addObject:@{@"label":[NSString stringWithFormat:@"%ld",(long)(i+1)],@"value":@(cnt),@"color":[NSColor colorWithCalibratedHue:hue saturation:0.65 brightness:0.85 alpha:1]}];self.barChart.axisUnit=@"\xe5\x91\xa8";
            }break;
        }
        case StatsPeriodYear:{
            NSDateComponents *yc=[cal components:NSCalendarUnitYear fromDate:now];
            NSDate *ps=[cal dateFromComponents:yc];
            for(NSInteger i=0;i<12;i++){
                NSDateComponents *a=[[NSDateComponents alloc] init];a.month=i;NSDateComponents *a2=[[NSDateComponents alloc] init];a2.month=i+1;
                NSDate *bs=[cal dateByAddingComponents:a toDate:ps options:0],*be=[cal dateByAddingComponents:a2 toDate:ps options:0];
                NSTimeInterval bsi=[bs timeIntervalSince1970],bei=[be timeIntervalSince1970];
                NSInteger cnt=0;for(NSDictionary *r in records){NSTimeInterval t=[r[@"time"] doubleValue];if(t>=bsi&&t<bei)cnt++;}
                CGFloat hue=0.55+0.1*((CGFloat)i/12.0);
                [bi addObject:@{@"label":[NSString stringWithFormat:@"%ld",(long)(i+1)],@"value":@(cnt),@"color":[NSColor colorWithCalibratedHue:hue saturation:0.65 brightness:0.85 alpha:1]}];self.barChart.axisUnit=@"\xe6\x9c\x88";
            }break;
        }
    }
    if(bi.count==0)[bi addObject:@{@"label":@"\xe6\x9a\x82\xe6\x97\xa0\xe6\x95\xb0\xe6\x8d\xae",@"value":@1,@"color":[NSColor colorWithCalibratedRed:0.8 green:0.8 blue:0.8 alpha:0.5]}];
    self.barChart.items=bi;[self.barChart setNeedsDisplay:YES];self.pieChart.items=pi;[self.pieChart setNeedsDisplay:YES];
}
- (NSString *)promptForPeriod:(StatsPeriod)period {
    NSString *k;switch(period){case StatsPeriodDay:k=DailyPromptKey;break;case StatsPeriodWeek:k=WeeklyPromptKey;break;case StatsPeriodMonth:k=MonthlyPromptKey;break;case StatsPeriodYear:k=YearlyPromptKey;break;}
    return [[NSUserDefaults standardUserDefaults] stringForKey:k]?:@"今日达成率为{rate}%。";
}
- (NSString *)praiseForRate:(double)rate {
    NSUserDefaults *d=[NSUserDefaults standardUserDefaults];
    if(rate>=90)return[d stringForKey:PraiseHighKey]?:@"\xe6\x82\xa8\xe6\x98\xaf\xe5\xa4\xa9\xe4\xb8\x8b\xe6\x9c\x80\xe5\xa5\xbd\xe7\x9a\x84\xe5\xae\x9d\xe5\xae\x9d\xef\xbd\x9e";
    if(rate>=70)return[d stringForKey:PraiseGoodKey]?:@"\xe5\xbe\x88\xe6\xa3\x92\xef\xbc\x8c\xe7\xbb\xa7\xe7\xbb\xad\xe5\x8a\xa0\xe6\xb2\xb9\xef\xbc\x81";
    if(rate>=50)return[d stringForKey:PraiseMediumKey]?:@"\xe8\xbf\x98\xe4\xb8\x8d\xe9\x94\x99\xef\xbc\x8c\xe5\x86\x8d\xe5\x8a\xa0\xe6\x8a\x8a\xe5\x8a\xb2\xef\xbc\x81";
    return[d stringForKey:PraiseLowKey]?:@"\xe8\xa6\x81\xe5\xa4\x9a\xe6\xb3\xa8\xe6\x84\x8f\xe7\xab\x99\xe7\xab\x8b\xe5\x92\x8c\xe5\x96\x9d\xe6\xb0\xb4\xe5\x93\xa6\xef\xbc\x81";
}
- (void)clearStats:(id)sender {
    NSAlert *alert=[[NSAlert alloc] init];
    alert.messageText=@"\xe7\xa1\xae\xe8\xae\xa4\xe6\xb8\x85\xe9\x99\xa4";
    alert.informativeText=@"\xe7\xa1\xae\xe5\xae\x9a\xe8\xa6\x81\xe6\xb8\x85\xe9\x99\xa4\xe6\x89\x80\xe6\x9c\x89\xe7\xbb\x9f\xe8\xae\xa1\xe6\x95\xb0\xe6\x8d\xae\xe5\x90\x97\xef\xbc\x9f\xe6\xad\xa4\xe6\x93\x8d\xe4\xbd\x9c\xe4\xb8\x8d\xe5\x8f\xaf\xe6\x81\xa2\xe5\xa4\x8d\xe3\x80\x82";
    [alert addButtonWithTitle:@"\xe6\xb8\x85\xe9\x99\xa4"];
    [alert addButtonWithTitle:@"\xe5\x8f\x96\xe6\xb6\x88"];
    [alert beginSheetModalForWindow:self.statsWindow completionHandler:^(NSModalResponse r){
        if(r==NSAlertFirstButtonReturn){
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:RecordsKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self refreshStatsWithPeriod:(StatsPeriod)self.periodSelector.selectedSegment];
            self.analysisResultLabel.stringValue=@"\xe5\xb7\xb2\xe6\xb8\x85\xe9\x99\xa4\xe6\x89\x80\xe6\x9c\x89\xe6\x95\xb0\xe6\x8d\xae";
        }
    }];
}

- (void)showAnalysis:(id)sender {
    StatsPeriod p=(StatsPeriod)self.periodSelector.selectedSegment;
    NSDictionary *s=[self aggregateStatsForPeriod:p];
    NSInteger pos=[s[@(ActionTypeStandNow)] integerValue]+[s[@(ActionTypeAlreadyDrank)] integerValue],total=0;
    for(NSNumber*k in @[@(ActionTypeStandNow),@(ActionTypeAlreadyDrank),@(ActionTypeNextTime),@(ActionTypeSnoozed),@(ActionTypeDismissed)])total+=[s[k] integerValue];
    if(total==0){self.analysisResultLabel.stringValue=@"\xf0\x9f\x93\x8a \xe6\x9a\x82\xe6\x97\xa0\xe6\x95\xb0\xe6\x8d\xae\xef\xbc\x8c\xe5\xbf\xab\xe5\x8e\xbb\xe4\xbd\xbf\xe7\x94\xa8\xe5\x90\xa7\xef\xbd\x9e";return;}
    double rate=(double)pos/(double)total*100.0;NSString *pt=[self promptForPeriod:p],*pr=[self praiseForRate:rate];
    NSString *res=[[pt stringByReplacingOccurrencesOfString:@"{rate}" withString:[NSString stringWithFormat:@"%.0f",rate]] stringByReplacingOccurrencesOfString:@"{praise}" withString:pr];
    NSString *emo=rate>=90?@"\xf0\x9f\x98\x8a":rate>=70?@"\xf0\x9f\x91\x8d":rate>=50?@"\xf0\x9f\x92\xaa":@"\xf0\x9f\x99\x8f";
    self.analysisResultLabel.stringValue=[NSString stringWithFormat:@"%.0f%%\n%@\n%@ %@",rate,res,emo,pr];
}

- (void)quit:(id)sender{[NSApp terminate:nil];}

@end

@implementation BarChartView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    NSRect b=self.bounds;if(!self.items||self.items.count==0)return;
    CGFloat mv=1;for(NSDictionary *i in self.items){CGFloat v=[i[@"value"] doubleValue];if(v>mv)mv=v;}
    CGFloat mL=50,mR=30,mT=30,mB=50,cW=b.size.width-mL-mR,cH=b.size.height-mT-mB,N=self.items.count,bw=MIN(60,MAX(8,(cW-(N+1)*10)/N)),gap=(cW-bw*N)/(N+1);
    for(int i=0;i<=4;i++){CGFloat v=mv*i/4,y=mT+cH*i/4;NSString*l=[NSString stringWithFormat:@"%.0f",v];NSDictionary*a=@{NSFontAttributeName:[NSFont systemFontOfSize:11 weight:NSFontWeightRegular],NSForegroundColorAttributeName:NSColor.secondaryLabelColor};NSSize sz=[l sizeWithAttributes:a];[l drawAtPoint:NSMakePoint(mL-sz.width-6,y-sz.height/2)withAttributes:a];[[NSColor.separatorColor colorWithAlphaComponent:0.3]set];[NSBezierPath strokeLineFromPoint:NSMakePoint(mL,y)toPoint:NSMakePoint(b.size.width-mR,y)];}
    for(NSUInteger i=0;i<N;i++){NSDictionary*it=self.items[i];CGFloat v=[it[@"value"]doubleValue];NSColor*c=it[@"color"];NSString*l=it[@"label"]?:@"";
        CGFloat bh=(v/mv)*cH,x=mL+gap+i*(bw+gap),y=mT;[c setFill];[[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(x,y,bw,bh)xRadius:4 yRadius:4]fill];
        if(v>0){NSString*vs=[NSString stringWithFormat:@"%.0f",v];NSDictionary*a=@{NSFontAttributeName:[NSFont systemFontOfSize:12 weight:NSFontWeightSemibold],NSForegroundColorAttributeName:NSColor.labelColor};NSSize vsz=[vs sizeWithAttributes:a];[vs drawAtPoint:NSMakePoint(x+bw/2-vsz.width/2,y+bh+4)withAttributes:a];}
        NSDictionary*a=@{NSFontAttributeName:[NSFont systemFontOfSize:9 weight:NSFontWeightMedium],NSForegroundColorAttributeName:NSColor.secondaryLabelColor};NSSize lsz=[l sizeWithAttributes:a];[l drawAtPoint:NSMakePoint(x+bw/2-lsz.width/2,y-22)withAttributes:a];}
    if(self.axisUnit){NSDictionary*ua=@{NSFontAttributeName:[NSFont systemFontOfSize:9 weight:NSFontWeightMedium],NSForegroundColorAttributeName:NSColor.secondaryLabelColor};NSSize usz=[self.axisUnit sizeWithAttributes:ua];[self.axisUnit drawAtPoint:NSMakePoint(b.size.width-mR-4-usz.width+27,mT-22)withAttributes:ua];}
    [NSColor.separatorColor set];[NSBezierPath strokeLineFromPoint:NSMakePoint(mL,mT)toPoint:NSMakePoint(mL,b.size.height-mR)];[NSBezierPath strokeLineFromPoint:NSMakePoint(mL,mT)toPoint:NSMakePoint(b.size.width-mR,mT)];
}
@end

@implementation PieChartView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    NSRect b=self.bounds;if(!self.items||self.items.count==0)return;
    CGFloat t=0;for(NSDictionary*i in self.items)t+=[i[@"value"]doubleValue];
    if(t<=0){NSDictionary*a=@{NSFontAttributeName:[NSFont systemFontOfSize:16 weight:NSFontWeightMedium],NSForegroundColorAttributeName:NSColor.secondaryLabelColor};NSString*m=@"\xe6\x9a\x82\xe6\x97\xa0\xe6\x95\xb0\xe6\x8d\xae";NSSize sz=[m sizeWithAttributes:a];[m drawAtPoint:NSMakePoint(b.size.width/2-sz.width/2,b.size.height/2-sz.height/2)withAttributes:a];return;}
    CGFloat r=MIN(b.size.width,b.size.height)/2-50;NSPoint c=NSMakePoint(b.size.width/2,b.size.height/2+10);CGFloat sa=-90;
    for(NSDictionary*i in self.items){CGFloat v=[i[@"value"]doubleValue];if(v<=0)continue;CGFloat sl=v/t*360;NSColor*co=i[@"color"];
        NSBezierPath*arc=[NSBezierPath bezierPath];[arc moveToPoint:c];[arc appendBezierPathWithArcWithCenter:c radius:r startAngle:sa endAngle:sa+sl];[arc closePath];[co setFill];[arc fill];[[NSColor.windowBackgroundColor colorWithAlphaComponent:0.3]setStroke];[arc setLineWidth:1.5];[arc stroke];sa+=sl;}
    CGFloat lY=12,lX=20;for(NSDictionary*i in self.items){if([i[@"value"]doubleValue]<=0)continue;NSColor*co=i[@"color"];NSString*l=i[@"label"]?:@"";NSInteger v=[i[@"value"]integerValue];
        [[co colorWithAlphaComponent:0.9]setFill];[[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(lX,lY,10,10)xRadius:2 yRadius:2]fill];
        NSString*lt=[NSString stringWithFormat:@"%@ (%ld)",l,(long)v];NSDictionary*a=@{NSFontAttributeName:[NSFont systemFontOfSize:11 weight:NSFontWeightRegular],NSForegroundColorAttributeName:NSColor.labelColor};NSSize ls=[lt sizeWithAttributes:a];[lt drawAtPoint:NSMakePoint(lX+16,lY-2)withAttributes:a];lX+=ls.width+30;if(lX+100>b.size.width){lX=20;lY+=20;}}
}
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
