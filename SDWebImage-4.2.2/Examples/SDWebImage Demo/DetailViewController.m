/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "DetailViewController.h"
#import <SDWebImage/FLAnimatedImageView.h>
#import <SDWebImage/FLAnimatedImageView+WebCache.h>
#import <SDWebImage/UIImageView+WebCache.h>


@interface DetailViewController ()

@property (strong, nonatomic) IBOutlet FLAnimatedImageView *imageView;
@property (strong, nonatomic) UIActivityIndicatorView *activityIndicator;
@property (strong, nonatomic) UIProgressView *progressView;


@end

@implementation DetailViewController

- (UIActivityIndicatorView *)activityIndicator
{
    if (!_activityIndicator) {
        _activityIndicator = [UIActivityIndicatorView.alloc initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _activityIndicator.center = self.imageView.center;
        _activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [self.imageView addSubview:_activityIndicator];
        
    }
    return _activityIndicator;
}

- (UIProgressView *)progressView
{
    if (!_progressView) {
        _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        [self.view addSubview:_progressView];
    }
    return _progressView;
}

- (void)configureView
{
    self.activityIndicator.hidden = NO;
    [self.activityIndicator startAnimating];
    
    __weak typeof(self) weakSelf = self;
    [self.imageView sd_setImageWithURL:self.imageURL
                      placeholderImage:nil
                               options:SDWebImageProgressiveDownload
                              progress:^(NSInteger receivedSize, NSInteger expectedSize, NSURL *targetURL) {
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                      float progress = 0;
                                      if (expectedSize != 0) {
                                          progress = (float)receivedSize / (float)expectedSize;
                                      }
                                      weakSelf.progressView.hidden = NO;
                                      [weakSelf.progressView setProgress:progress animated:YES];
                                  });
                              }
                             completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
                                 weakSelf.progressView.hidden = YES;
                                 [weakSelf.activityIndicator stopAnimating];
                                 weakSelf.activityIndicator.hidden = YES;
                             }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
//    [self configureView];
    [[SDWebImageDownloader sharedDownloader] downloadImageWithURL:[NSURL URLWithString:@"https://ss1.bdstatic.com/70cFvXSh_Q1YnxGkpoWK1HF6hhy/it/u=2463979922,1038971135&fm=27&gp=0.jpg"] options:0 progress:^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
        
    } completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        
    }];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    self.progressView.frame = CGRectMake(0, self.topLayoutGuide.length, CGRectGetWidth(self.view.bounds), 2.0);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

@end
