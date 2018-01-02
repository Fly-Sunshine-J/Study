//
//  FSProgressHUD.m
//  FSProgressHUD
//
//  Created by vcyber on 2017/10/30.
//  Copyright © 2017年 vcyber. All rights reserved.
//

#import "FSProgressHUD.h"

static const CGFloat FSDefaultTitleFontSize = 16.0f;
static const CGFloat FSDefaultDetailFontSize = 12.0f;

CGFloat const FSProgressMaxOffset = 10000.0f;
static const CGFloat FSProgressHUDSubViewPadding = 4.0f;

//MARK: - 圆角button
@interface FSProgressHUDRoundButton: UIButton

@end


@implementation FSProgressHUDRoundButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.layer.borderWidth = 1.0f;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius = ceil(CGRectGetHeight(self.bounds) / 2);
}

- (CGSize)intrinsicContentSize {
    if (self.allControlEvents == 0) {
        return CGSizeZero;
    }
    CGSize size = [super intrinsicContentSize];
    size.width += 20;
    return size;
}

@end


//MARK: - FSProgressHUD

@interface FSProgressHUD()

@property (nonatomic, assign, getter=isFinished) BOOL finished;
@property (nonatomic, strong) UIView *indicator;
@property (nonatomic, strong) UIView *topSpacer;
@property (nonatomic, strong) UIView *bottomSpacer;

@end

@implementation FSProgressHUD

//MARK: -生命周期方法

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self hudInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self hudInit];
    }
    return self;
}

- (instancetype)initWithView:(UIView *)view {
    NSAssert(view, @"View must not be nil");
    self = [self initWithFrame:view.bounds];
    [view addSubview:self];
    return self;
}

- (void)hudInit {
    self.alpha = 0.f;
    _mode = FSProgressHUDModeIndeterminate;
    _animationType = FSProgressHUDAnimationFade;
    _removeFromSuperViewOnHide = NO;
    _contentColor = [UIColor colorWithWhite:0.f alpha:0.7f];
    _margin = UIEdgeInsetsMake(20, 20, 20, 20);
    _contentMargin = UIEdgeInsetsMake(20, 20, 20, 20);
    self.opaque = NO;
    self.backgroundColor = [UIColor clearColor];
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.layer.allowsGroupOpacity = NO;
    
    [self setupUI];
    [self updateIndicator];
}

- (void)setupUI {
    
    FSBackgroundView *backgroundView = [[FSBackgroundView alloc] initWithFrame:self.bounds];
    backgroundView.style = FSProgressHUDBackgroundStyleSolidColor;
    backgroundView.color = [UIColor redColor];
    backgroundView.alpha = 0.0f;
    backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:backgroundView];
    _backgroundView = backgroundView;
    
    FSBackgroundView *contentView = [[FSBackgroundView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    contentView.layer.cornerRadius = 5;
    contentView.alpha = 0;
    contentView.layer.masksToBounds = YES;
    [self addSubview:contentView];
    _contentView = contentView;
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.adjustsFontSizeToFitWidth = NO;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = _contentColor;
    titleLabel.font = [UIFont systemFontOfSize:FSDefaultTitleFontSize];
    [_contentView addSubview:titleLabel];
    _titleLabel = titleLabel;
    
    UILabel *detailLabel = [[UILabel alloc] init];
    detailLabel.textAlignment = NSTextAlignmentCenter;
    detailLabel.adjustsFontSizeToFitWidth = NO;
    detailLabel.textColor = _contentColor;
    detailLabel.font = [UIFont systemFontOfSize:FSDefaultDetailFontSize];
    detailLabel.numberOfLines = 0;
    [_contentView addSubview:detailLabel];
    _detailLbael = detailLabel;
    
    FSProgressHUDRoundButton *btn = [FSProgressHUDRoundButton buttonWithType:UIButtonTypeCustom];
    btn.titleLabel.textAlignment = NSTextAlignmentCenter;
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:FSDefaultDetailFontSize];
    [btn setTitleColor:_contentColor forState:UIControlStateNormal];
    btn.layer.borderWidth = 1;
    btn.layer.borderColor = btn.currentTitleColor.CGColor;
    [_contentView addSubview:btn];
    _button = btn;
    
    for (UIView *view in @[titleLabel, detailLabel, btn]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [view setContentCompressionResistancePriority:998.0f forAxis:UILayoutConstraintAxisVertical];
        [view setContentCompressionResistancePriority:998.0f forAxis:UILayoutConstraintAxisHorizontal];
    }
    
    UIView *top = [[UIView alloc] init];
    top.translatesAutoresizingMaskIntoConstraints = NO;
    top.hidden = YES;
    [_contentView addSubview:top];
    _topSpacer = top;
    
    UIView *botttom = [[UIView alloc] init];
    botttom.translatesAutoresizingMaskIntoConstraints = NO;
    botttom.hidden = YES;
    [_contentView addSubview:botttom];
    _bottomSpacer = botttom;
    
}

- (void)updateIndicator {
    UIView *indicator = self.indicator;
    BOOL isActivityIndicator = [indicator isKindOfClass:[UIActivityIndicatorView class]];
    
    FSProgressHUDMode mode = _mode;
    if (mode == FSProgressHUDModeIndeterminate) {
        if (!isActivityIndicator) {
            [indicator removeFromSuperview];
            UIActivityIndicatorView *indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
            indicatorView.color = _contentColor;
            [indicatorView startAnimating];
            [_contentView addSubview:indicatorView];
            indicator = indicatorView;
        }
    }else if (mode == FSProgressHUDModeCustomView && (indicator != self.customView || ![indicator isEqual:self.customView])) {
        [indicator removeFromSuperview];
        indicator = _customView;
        [_contentView addSubview:indicator];
    }else if (mode == FSProgressHUDModeText) {
        [indicator removeFromSuperview];
        indicator = nil;
    }
    indicator.translatesAutoresizingMaskIntoConstraints = NO;
    _indicator = indicator;
    [self setNeedsUpdateConstraints];
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
}

//MARK: -类方法
+ (instancetype)showHUDForView:(UIView *)view animation:(BOOL)animation {
    FSProgressHUD *hud = [[self alloc] initWithView:view];
    hud.removeFromSuperViewOnHide = YES;
    [view addSubview:hud];
    [hud showAnimated:animation];
    return hud;
}


+ (instancetype)HUDForView:(UIView *)view {
    NSEnumerator *subviewsEnum = [view.subviews reverseObjectEnumerator];
    for (UIView *subview in subviewsEnum) {
        if ([subview isKindOfClass:[FSProgressHUD class]]) {
            FSProgressHUD *hud = (FSProgressHUD *)subview;
            if (!hud.isFinished) {
                return hud;
            }
        }
    }
    return nil;
}

+ (BOOL)hideHUDForView:(UIView *)view animation:(BOOL)animation {
    FSProgressHUD *hud = [self HUDForView:view];
    if (hud) {
        [hud hideAnimated:animation];
        return YES;
    }
    return NO;
}


//MARK: -显示/隐藏
- (void)showAnimated:(BOOL)animated {
    [self.contentView.layer removeAllAnimations];
    [self.backgroundView.layer removeAllAnimations];
    self.alpha = 1.0f;
    self.finished = YES;
    if (animated) {
        [self show:YES animation:animated withType:_animationType complete:nil];
    }else {
        self.backgroundView.alpha = 1.0f;
        self.contentView.alpha = 1.f;
    }
    
}

- (void)hideAnimated:(BOOL)animated {
    [self show:NO animation:animated withType:_animationType complete:^(BOOL finished) {
        [self hideComplete];
    }];
}

- (void)show:(BOOL)isShow animation:(BOOL)animated withType:(FSProgressHUDAnimation)type complete:(void(^)(BOOL))completion {
    
    CGAffineTransform small = CGAffineTransformMakeScale(0.5, 0.5f);
    CGAffineTransform large = CGAffineTransformMakeScale(1.5f, 1.5f);
    
    if (type == FSProgressHUDAnimationZoom) {
        if (isShow) {
            _contentView.transform = small;
        }else {
            _contentView.transform = large;
        }
    }
    
    [UIView animateWithDuration:.3f delay:0.f usingSpringWithDamping:1.f initialSpringVelocity:0.f options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        if (isShow) {
            _backgroundView.alpha = 1.0f;
            _contentView.alpha = 10.f;
            _contentView.transform = CGAffineTransformIdentity;
        }else {
            _contentView.transform = CGAffineTransformIdentity;
            _backgroundView.alpha = 0.0f;
            _contentView.alpha = 00.f;
        }
        
    } completion:completion];
}


- (void)hideComplete {
    if (self.removeFromSuperViewOnHide) {
        [self removeFromSuperview];
    }
    FSProgressHUDCompletionBlock complete = self.completeBlock;
    if (complete) {
        complete();
    }
}

//MARK: -布局
- (void)updateConstraints {
    
    UIView *contentView = _contentView;
    UIView *topSpacer = _topSpacer;
    UIView *bottomSpacer = _bottomSpacer;
    
    NSMutableArray *subviews = [NSMutableArray arrayWithArray:@[_topSpacer, _titleLabel, _detailLbael, _button, _bottomSpacer]];
    if (_indicator) {
        [subviews insertObject:_indicator atIndex:1];
    }
    
    [self removeConstraints:self.constraints];
    [topSpacer removeConstraints:topSpacer.constraints];
    [bottomSpacer removeConstraints:bottomSpacer.constraints];
    
    CGPoint offset = self.offset;

//    contentView中心约束
    NSMutableArray *centerConstraints = [NSMutableArray array];
    NSLayoutConstraint *centerX = [NSLayoutConstraint constraintWithItem:contentView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1.0f constant:offset.x];
    NSLayoutConstraint *centerY = [NSLayoutConstraint constraintWithItem:contentView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1.0f constant:offset.y];
    [centerConstraints addObject:centerX];
    [centerConstraints addObject:centerY];
    [self setPriority:998.0f constraints:centerConstraints];
    [self addConstraints:centerConstraints];

    
    
//    contentView周边边距 相互约束
    NSMutableArray *marginContraints = [NSMutableArray array];
    [marginContraints addObject:[NSLayoutConstraint constraintWithItem:contentView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1.0f constant:_margin.top]];
    [marginContraints addObject:[NSLayoutConstraint constraintWithItem:contentView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationLessThanOrEqual toItem:self attribute:NSLayoutAttributeBottom multiplier:1.0f constant:-_margin.bottom]];
    [marginContraints addObject:[NSLayoutConstraint constraintWithItem:contentView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1.0f constant:_margin.left]];
    [marginContraints addObject:[NSLayoutConstraint constraintWithItem:contentView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationLessThanOrEqual toItem:self attribute:NSLayoutAttributeRight multiplier:1.0f constant:-_margin.right]];

    [self setPriority:999.0f constraints:marginContraints];
    [self addConstraints:marginContraints];
    
    
//    contentView最小尺寸约束
    CGSize minSize = self.minSize;
    if (!CGSizeEqualToSize(minSize, CGSizeZero)) {
        NSMutableArray *minSizeContrains = [NSMutableArray array];
        [minSizeContrains addObject:[NSLayoutConstraint constraintWithItem:contentView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0f constant:minSize.width]];
        [minSizeContrains addObject:[NSLayoutConstraint constraintWithItem:contentView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0f constant:minSize.height]];
        [self setPriority:997.0f constraints:minSizeContrains];
        [contentView addConstraints:minSizeContrains];
    }

//    contentView正方形约束
    if (_square) {
        NSLayoutConstraint *square = [NSLayoutConstraint constraintWithItem:contentView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeHeight multiplier:1.0f constant:0];
        square.priority = 997.0f;
        [contentView addConstraint:square];
    }

//    content上下间距约束
    [topSpacer addConstraint:[NSLayoutConstraint constraintWithItem:topSpacer attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0f constant:_contentMargin.top]];
    [bottomSpacer addConstraint:[NSLayoutConstraint constraintWithItem:bottomSpacer attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0f constant:_contentMargin.bottom]];

//    保持上下间距相等
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:topSpacer attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:bottomSpacer attribute:NSLayoutAttributeHeight multiplier:1.0f constant:0.0f]];

//    subviews约束
    [subviews enumerateObjectsUsingBlock:^(UIView *  _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        //subview居中约束
        [contentView addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeCenterX multiplier:1.0f constant:0.0f]];
        //左右间距约束,保证最小间距
//        [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(>=margin)-[view]-(>=margin)-|" options:0 metrics:metrics views:NSDictionaryOfVariableBindings(view)]];
        [contentView addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:contentView attribute:NSLayoutAttributeLeft multiplier:1.0f constant:_contentMargin.left]];
        [contentView addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationLessThanOrEqual toItem:contentView attribute:NSLayoutAttributeRight multiplier:1.0f constant:-_contentMargin.right]];
        if (idx == 0) {
            //第一个subview的top约束
            [contentView addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeTop multiplier:1.0f constant:0.0f]];
        }else if (idx == subviews.count - 1) {
            //最后一个底部约束
            [contentView addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeBottom multiplier:1.0f constant:0.0f]];
        }
        if (idx > 0) {
            CGFloat padding = 0.f;
            if (!view.hidden && view.intrinsicContentSize.width < self.bounds.size.width && view.alpha != 0 && !CGSizeEqualToSize(view.intrinsicContentSize, CGSizeZero)) {
                padding = FSProgressHUDSubViewPadding;
            }
            [contentView addConstraint: [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:subviews[idx - 1] attribute:NSLayoutAttributeBottom multiplier:1.0f constant:padding]];
        }

    }];
    
    [super updateConstraints];
}

- (void)setPriority:(UILayoutPriority)priority constraints:(NSArray<NSLayoutConstraint *> *)constraints {
    for (NSLayoutConstraint *constraint in constraints) {
        constraint.priority = priority;
    }
}



@end



//MARK: - FSBackgroundView

@interface FSBackgroundView()

@property (nonatomic, strong) UIVisualEffectView *effectView;

@end

@implementation FSBackgroundView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _style = FSProgressHUDBackgroundStyleBlur;
        _color = [UIColor colorWithWhite:0.95 alpha:0.6];
        self.clipsToBounds = YES;
        [self updateStyle];
    }
    return self;
}

- (CGSize)intrinsicContentSize {
    // Smallest size possible. Content pushes against this.
    return CGSizeZero;
}

- (void)updateStyle {
    FSProgressHUDBackgroundStyle style = self.style;
    if (style == FSProgressHUDBackgroundStyleBlur) {
        if (_effectView == nil) {
            UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
            UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:effect];
            [self addSubview:effectView];
            effectView.frame = self.bounds;
            self.layer.allowsGroupOpacity = NO;
            self.effectView = effectView;
        }
        self.backgroundColor = self.color;
    }else {
        [self.effectView removeFromSuperview];
        self.effectView = nil;
        self.backgroundColor = self.color;
    }
}


- (void)setColor:(UIColor *)color {
    if (color != _color && ![color isEqual:_color]) {
        _color = color;
        [self updateStyle];
    }
}

- (void)setStyle:(FSProgressHUDBackgroundStyle)style {
    if (style != _style) {
        _style = style;
        [self updateStyle];
    }
}

@end


