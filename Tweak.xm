@interface SSSDittoRootViewController : UIViewController
- (void)containerViewControllerHadGestureInteraction:(id)viewController;
- (void)containerViewController:(id)viewController requestsDismissWithVelocity:(CGFloat)velocity;
- (void)containerViewControllerRequestsDeletionDismiss:(id)viewController;
- (void)_addContainerViewController:(UIViewController *)controller;
@end

@interface SSSScreenshotsView : UIView
- (UIView *)visibleView;
- (CGRect)rectForViewOverlayingLatestScreenshot;
@end

@interface SSSScreenshotView : UIView
-(CGRect)extent;
- (CGRect)currentlyVisibleRect;
@end

@interface SSSScreenshotsViewController : UIViewController
- (CGRect)screenshotsExtentRect;
- (SSSScreenshotsView *)_screenshotsView;
- (NSArray *)visibleScreenshots; // iOS 12
- (CGRect)rectForViewOverlayingLatestScreenshot;
- (void)setBorderViewStyleOverride:(NSUInteger)style withAnimator:(UIViewPropertyAnimator *)animator;
- (void)setState:(NSUInteger)state;
@end

@interface SSSContainerViewController : UIViewController {
	CGPoint _pileTranslation;
	UIPanGestureRecognizer *_pileFlingGesture;
	UIViewController *_screenshotsViewController;
}
- (BOOL)_pileTranslationIsTowardsOppositeEdge;
- (BOOL)_pileTranslationIsTowardsEdge;
- (void)_updateForCurrentSize;
- (void)_updateFlashViewFrame;
- (CGFloat)_pileTranslationAmountForDismiss;
- (SSSDittoRootViewController *)delegate;
- (void)_stopCurrentFlash;
- (void)_prepareForDismiss;
- (void)_moveScreenshotsViewForHorizontalSlideOffDismiss;
- (void)dismissScreenshotsWithVelocity:(CGFloat)velocity completion:(void (^)(void))completion;
- (void)deleteRequestedForAllScreenshotsFromScreenshotsViewController:(id)screenshotsController animatingDeletion:(BOOL)deletion;
- (BOOL)_pileTranslationIsTopEdge;
- (void)_pileTapped;
- (void)_setState:(NSUInteger)state animated:(BOOL)animated completion:(id)completion;
- (CGFloat)_pileTranslationAmountForPresentation;
- (NSDirectionalEdgeInsets)_miniatureInsets;
- (CGFloat)_scaleAmountForState:(NSUInteger)state;
- (void)_updateScreenshotsViewTransform;
- (void)screenshotsViewController:(SSSScreenshotsViewController *)viewController requestsDeleteForScreenshots:(NSArray *)screenshots forReason:(NSUInteger)reason; // iOS 12
@end

CGFloat clamp(CGFloat value, CGFloat min, CGFloat max) {
	return fmax(fmin(max, value), min);
}

static BOOL fakePileTap;

@interface SSSContainerViewController (SSGestures)
@property (nonatomic, assign) BOOL isVertical;
@property (nonatomic, assign) BOOL directionSet;
@end

static CGFloat dismissVelocity = 0;

%hook SSSContainerViewController

%property (nonatomic, assign) BOOL isVertical;
%property (nonatomic, assign) BOOL directionSet;

- (CGVector)_translationAmountForState:(NSUInteger)state pileTranslation:(CGPoint)pileTranslation {
	if (fakePileTap & !state) {
		NSDirectionalEdgeInsets miniInsets = [self _miniatureInsets];
		SSSScreenshotsViewController *ssController = MSHookIvar<SSSScreenshotsViewController *>(self, "_screenshotsViewController");
		NSArray *shots = MSHookIvar<NSArray *>([ssController _screenshotsView], "_screenshotViews");
		SSSScreenshotView *ssView = [shots lastObject];
		UIView *borderView = MSHookIvar<UIView *>(ssView, "_borderView");
		CGRect borderFrame = [self.view convertRect:borderView.bounds fromView:borderView];
		CGRect frame9 = [self.view convertRect:[ssView currentlyVisibleRect] fromView:[ssView superview]];
		UIView *newView = [[UIView alloc] initWithFrame:CGRectMake(frame9.origin.x , 0, borderFrame.size.width, 50)];
		newView.backgroundColor = [UIColor greenColor];
		newView.alpha = 0.5;
		return CGVectorMake(0 - miniInsets.leading * 2, miniInsets.bottom);
	}
	CGVector orig = %orig;
	if (orig.dx > 0)
		orig.dx = pileTranslation.x;
	return orig;
}

- (CGFloat)_scaleAmountForState:(NSUInteger)state {
	if (fakePileTap && !state)
		return 0.8;
	return %orig;
}

- (void)_moveScreenshotsViewForHorizontalSlideOffDismiss {
	if (!fakePileTap) {
		UIView *view = ((UIViewController *)MSHookIvar<UIViewController *>(self, "_screenshotsViewController")).view;
		view.alpha = 0.0;
	}
	%orig;
}

- (CGAffineTransform)_transformForState:(NSUInteger)state pileTranslation:(CGPoint)translation {
	if (fakePileTap && !state) {
		CGFloat scale = [self _scaleAmountForState:state];
		CGAffineTransform transform = CGAffineTransformScale(CGAffineTransformIdentity, scale, scale);
		SSSScreenshotsViewController *ssController = MSHookIvar<SSSScreenshotsViewController *>(self, "_screenshotsViewController");
		UIView *view = ssController.view;
		CGRect frame3 = [self.view convertRect:[ssController rectForViewOverlayingLatestScreenshot] fromView:[ssController _screenshotsView]];
		CGRect frame4 = [self.view convertRect:[ssController screenshotsExtentRect] fromView:[ssController _screenshotsView]];
		CGFloat valA = (self.view.frame.size.width*0.5) - (frame3.size.width*0.5);
		CGFloat transX = valA - view.frame.origin.x + (frame3.origin.x - frame4.origin.x);
		CGAffineTransform translationTrans = CGAffineTransformTranslate(CGAffineTransformIdentity, transX,0);
		transform = CGAffineTransformConcat(translationTrans, transform);
		return transform;
	}
	return %orig;
}

- (CGFloat)_amountToMoveScreenshotsViewWithFrameForHorizontalSlideOffDismiss:(CGRect)frame {
	CGFloat orig = %orig;
	if ([self _pileTranslationIsTowardsOppositeEdge]) {
		orig *= -1;
	}
	return orig;
}

- (void)_handlePilePanGesture:(UIPanGestureRecognizer *)gestureRecognizer {
	CGPoint translation = [gestureRecognizer translationInView:self.view];
	if ([gestureRecognizer state] == UIGestureRecognizerStateBegan) {
		fakePileTap = NO;
		self.directionSet = NO;
		self.isVertical = NO;
		MSHookIvar<CGPoint>(self, "_pileTranslation") = translation;
		[self _updateForCurrentSize];
		if ([self respondsToSelector:@selector(_updateFlashViewFrame)])
			[self _updateFlashViewFrame];
		[[self delegate] containerViewControllerHadGestureInteraction:self];
		return;
	}
	if ([gestureRecognizer state] == UIGestureRecognizerStateChanged) {
		if (!self.directionSet) {
			CGFloat absX = fabs(translation.x);
			CGFloat absY = fabs(translation.y);

			if (absX > 5 || absY > 5) {
				self.directionSet = YES;
				self.isVertical = absY > absX;
			} else {
				MSHookIvar<CGPoint>(self, "_pileTranslation") = translation;
				[self _updateForCurrentSize];
				if ([self respondsToSelector:@selector(_updateFlashViewFrame)])
					[self _updateFlashViewFrame];
				[[self delegate] containerViewControllerHadGestureInteraction:self];
				return;
			}
		}
		if (self.directionSet) {
			MSHookIvar<CGPoint>(self, "_pileTranslation") = translation;
			if (self.isVertical) {
				translation.x *= 0.05;
				MSHookIvar<CGPoint>(self, "_pileTranslation") = translation;
				[self _updateForCurrentSize];
				if ([self respondsToSelector:@selector(_updateFlashViewFrame)])
					[self _updateFlashViewFrame];
				[[self delegate] containerViewControllerHadGestureInteraction:self];
				return;
			} else if ([self _pileTranslationIsTowardsOppositeEdge]) {
				translation.y *= 0.05;
				MSHookIvar<CGPoint>(self, "_pileTranslation") = translation;
				[self _updateForCurrentSize];
				if ([self respondsToSelector:@selector(_updateFlashViewFrame)])
					[self _updateFlashViewFrame];
				[[self delegate] containerViewControllerHadGestureInteraction:self];
				return;
			}
		}
	}

    if (([gestureRecognizer state] != UIGestureRecognizerStateEnded && [gestureRecognizer state] != UIGestureRecognizerStateFailed) && [gestureRecognizer state] != UIGestureRecognizerStatePossible) {
    
    } else if (self.directionSet) {
    	MSHookIvar<CGPoint>(self, "_pileTranslation") = translation;
    	CGPoint velocity = [gestureRecognizer velocityInView:self.view];
    	if (self.isVertical) {
    		if (translation.y < [self _pileTranslationAmountForPresentation]) {
    			UISpringTimingParameters *timingParams = [[UISpringTimingParameters alloc] initWithMass:2.0 stiffness:300.0 damping:400.0 initialVelocity:CGVectorMake(0, 0)];
				UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc] initWithDuration:0.2 timingParameters:timingParams];
				MSHookIvar<CGPoint>(self, "_pileTranslation") = CGPointZero;
				fakePileTap = NO;
				[animator addAnimations:^{
					[self _updateScreenshotsViewTransform];
				}];
				[animator addCompletion:^(UIViewAnimatingPosition finalPosition) {
					fakePileTap = NO;
					[self _pileTapped];
				}];
				[animator startAnimation];
    			[[self delegate] containerViewControllerHadGestureInteraction:self];
    			return;
    		}
    	} else if ([self _pileTranslationIsTowardsOppositeEdge]) {
    		if (fabs(translation.x) > fabs([self _pileTranslationAmountForDismiss])) {
				if ([self respondsToSelector:@selector(_stopCurrentFlash)])
    				[self _stopCurrentFlash];
    			dismissVelocity = velocity.x;
    			SSSScreenshotsViewController *screenshotsController = MSHookIvar<SSSScreenshotsViewController *>(self, "_screenshotsViewController");
				if ([self respondsToSelector:@selector(screenshotsViewController:requestsDeleteForScreenshots:forReason:)])
					[self screenshotsViewController:screenshotsController requestsDeleteForScreenshots:[screenshotsController visibleScreenshots] forReason:0];			
				else if ([self respondsToSelector:@selector(deleteRequestedForAllScreenshotsFromScreenshotsViewController:animatingDeletion:)])
    				[self deleteRequestedForAllScreenshotsFromScreenshotsViewController:screenshotsController animatingDeletion:YES];
    			[[self delegate] containerViewControllerHadGestureInteraction:self];
    			return;
    		}
    	}
    }

	%orig;
}

- (void)dismissScreenshotsWithSlideWithCompletion:(void (^)(void))completion {
	if ([self _pileTranslationIsTowardsOppositeEdge]) {
		[self dismissScreenshotsWithVelocity:dismissVelocity completion:completion];
		dismissVelocity = 0;
	} else {
		%orig;
	}
}

- (CGFloat)_pileTranslationAmountForDismiss {
	CGFloat orig = %orig;
	if ([self _pileTranslationIsTowardsOppositeEdge]) {
		orig *= 4;
	}
	return orig;
}

%new
- (CGFloat)_pileTranslationAmountForPresentation {
	return 50;
}

%new
- (BOOL)_pileTranslationIsTowardsOppositeEdge {
	CGPoint translation = MSHookIvar<CGPoint>(self, "_pileTranslation");
	if ([self.view effectiveUserInterfaceLayoutDirection])
		return translation.x < 0.0;
	return translation.x > 0.0;
}

%new
- (BOOL)_pileTranslationIsTopEdge {
	CGPoint translation = MSHookIvar<CGPoint>(self, "_pileTranslation");
	if (fabs(translation.y) > fabs(translation.x))
		return translation.y < 0.0;
	return NO;
}

%end
