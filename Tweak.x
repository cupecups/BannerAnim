#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <math.h>

// ====== Parameter ======
// Awal: kapsul sebesar Dynamic Island, di tengah atas
static const CGFloat kStartScaleX = 0.22;   // lebar awal (relatif ukuran akhir)
static const CGFloat kStartScaleY = 0.30;   // tinggi awal
static const CGFloat kStartDY     = -32.0;  // posisi awal: ke atas dari posisi akhir (pt)

// Gerak vertikal (turun dari island, sedikit melewati titik akhir)
static const CGFloat kMoveOmega   = 18.0;
static const CGFloat kMoveZeta    = 0.60;

// Squishy: spring lebar & tinggi dibuat beda fase
static const CGFloat kXOmega      = 14.0;   // besar = lebih cepat
static const CGFloat kXZeta       = 0.50;   // kecil = lebih membal
static const CGFloat kYOmega      = 14.0;
static const CGFloat kYZeta       = 0.35;
static const CGFloat kYDelay      = 0.08;   // tinggi menyusul lebar -> efek squash/stretch

static const CGFloat kTotalTime   = 1.10;
static const CGFloat kFadeTime    = 0.18;
// =======================

@interface NCNotificationShortLookViewController : UIViewController
@end

static const void *kPlayedKey = &kPlayedKey;

static BOOL isInBanner(UIView *view) {
    for (UIView *v = view; v; v = v.superview) {
        if ([NSStringFromClass([v class]) containsString:@"Banner"]) return YES;
    }
    UIResponder *r = view;
    while ((r = r.nextResponder)) {
        if ([r isKindOfClass:[UIViewController class]] &&
            [NSStringFromClass([r class]) containsString:@"Banner"]) return YES;
    }
    return NO;
}

// Progres spring 0 -> 1 (bisa overshoot kalau zeta < 1)
static CGFloat springProgress(CGFloat t, CGFloat omega, CGFloat zeta) {
    if (t <= 0) return 0;
    if (zeta >= 1.0) return 1.0 - exp(-omega * t) * (1.0 + omega * t);
    CGFloat wd = omega * sqrt(1.0 - zeta * zeta);
    CGFloat e  = exp(-zeta * omega * t);
    return 1.0 - e * (cos(wd * t) + (zeta * omega / wd) * sin(wd * t));
}

static void playBannerIn(UIView *v) {
    CALayer *layer = v.layer;
    if ([layer animationForKey:@"bannerIn"]) return;

    CGFloat w = layer.bounds.size.width;
    CGFloat h = layer.bounds.size.height;
    if (w <= 0 || h <= 0) return;

    // Titik tumpu: tengah-atas banner (sisi atas tetap, tumbuh ke bawah)
    const int N = 110;
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:N + 1];
    for (int i = 0; i <= N; i++) {
        CGFloat t  = kTotalTime * i / N;
        CGFloat px = springProgress(t, kXOmega, kXZeta);
        CGFloat py = springProgress(t - kYDelay, kYOmega, kYZeta);
        CGFloat pm = springProgress(t, kMoveOmega, kMoveZeta);

        CGFloat sx = kStartScaleX + (1.0 - kStartScaleX) * px;
        CGFloat sy = kStartScaleY + (1.0 - kStartScaleY) * py;

        CGFloat tx = 0;
        CGFloat ty = -(1.0 - sy) * h / 2.0 + kStartDY * (1.0 - pm);

        CATransform3D tr = CATransform3DMakeTranslation(tx, ty, 0);
        tr = CATransform3DScale(tr, sx, sy, 1);
        if (i == N) tr = CATransform3DIdentity;
        [values addObject:[NSValue valueWithCATransform3D:tr]];
    }
    CAKeyframeAnimation *move = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
    move.values = values;
    move.calculationMode = kCAAnimationLinear;
    move.duration = kTotalTime;

    CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fade.fromValue = @0.0;
    fade.toValue   = @1.0;
    fade.duration  = kFadeTime;
    fade.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];

    CAAnimationGroup *g = [CAAnimationGroup animation];
    g.animations = @[move, fade];
    g.duration = kTotalTime;

    [layer addAnimation:g forKey:@"bannerIn"];
}

%hook NCNotificationShortLookViewController

- (void)viewDidLayoutSubviews {
    %orig;
    UIView *v = self.view;
    if (!v.window) return;
    if (!isInBanner(v) && !isInBanner(v.superview)) return;
    if (objc_getAssociatedObject(self, kPlayedKey)) return;
    objc_setAssociatedObject(self, kPlayedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    playBannerIn(v);
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    objc_setAssociatedObject(self, kPlayedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%end