//
//  FSProgressHUD.h
//  FSProgressHUD
//
//  Created by vcyber on 2017/10/30.
//  Copyright © 2017年 vcyber. All rights reserved.
//

#import <UIKit/UIKit.h>

extern CGFloat const FSProgressMaxOffset;

//MARK: - FSProgressHUD

typedef NS_ENUM(NSInteger, FSProgressHUDMode) {
    FSProgressHUDModeIndeterminate,
    FSProgressHUDModeCustomView,
    FSProgressHUDModeText
};


typedef NS_ENUM(NSInteger, FSProgressHUDAnimation) {
    FSProgressHUDAnimationFade,
    FSProgressHUDAnimationZoom
};

typedef void(^FSProgressHUDCompletionBlock)(void);

@class FSBackgroundView;

@interface FSProgressHUD : UIView

//MARK: - Class Method
+ (instancetype)showHUDForView:(UIView *)view animation:(BOOL)animation;
+ (instancetype)HUDForView:(UIView *)view;
+ (BOOL)hideHUDForView:(UIView *)view animation:(BOOL)animation;
//AMRK: - Method
- (instancetype)initWithView:(UIView *)view;

- (void)showAnimated:(BOOL)animated;
-(void)hideAnimated:(BOOL)animated;
//MARK: - Property
@property (nonatomic, assign) FSProgressHUDMode mode;

@property (nonatomic, assign) FSProgressHUDAnimation animationType;

@property (nonatomic, assign) BOOL removeFromSuperViewOnHide;
@property (nonatomic, assign) UIColor *contentColor;

@property (nonatomic, copy) FSProgressHUDCompletionBlock completeBlock;
//布局相关属性
@property (nonatomic, assign) UIEdgeInsets margin;
@property (nonatomic, assign) UIEdgeInsets contentMargin;
@property (nonatomic, assign) CGPoint offset;
@property (nonatomic, assign) CGSize minSize;
@property (nonatomic, assign) BOOL square;
//子视图属性
@property (nonatomic, strong, readonly) FSBackgroundView *backgroundView;
@property (nonatomic, strong, readonly) FSBackgroundView *contentView;
@property (nonatomic, strong, readonly) UILabel *titleLabel;
@property (nonatomic, strong, readonly) UILabel *detailLbael;
@property (nonatomic, strong, readonly) UIButton *button;
@property (nonatomic, strong) UIView *customView;


@end

//MARK: - FSBackgroundView

typedef NS_ENUM(NSInteger, FSProgressHUDBackgroundStyle) {
    FSProgressHUDBackgroundStyleBlur,
    FSProgressHUDBackgroundStyleSolidColor
};

@interface FSBackgroundView:UIView

@property (nonatomic, assign) FSProgressHUDBackgroundStyle style;

@property (nonatomic, strong) UIColor *color;

@end
