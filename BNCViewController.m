#import "BNCViewController.h"
#import <stdint.h>
#import <CoreText/CoreText.h>
#import <unistd.h>

@implementation BNCViewController

- (void)viewDidLoad {
	_label = [UILabel new];
	self.view.backgroundColor = [UIColor blackColor];
	_label.text = @"But nobody came.";
	_label.textColor = [UIColor whiteColor];
	_label.numberOfLines = 0;

	CFURLRef fontURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (__bridge CFStringRef)@"/Library/ButNobodyCame/font.ttf", kCFURLPOSIXPathStyle, 0);
	CGDataProviderRef fontDataRef = CGDataProviderCreateWithURL(fontURL);
	CFRelease(fontURL);
	CGFontRef fontRef = CGFontCreateWithDataProvider(fontDataRef);
	CFRelease(fontDataRef);
	CTFontRef graphicsFontRef = CTFontCreateWithGraphicsFont(fontRef, 22.5, NULL, NULL);
	CFRelease(fontRef);
	_label.font = [(__bridge UIFont *)graphicsFontRef copy];
	CFRelease(graphicsFontRef);

	_label.translatesAutoresizingMaskIntoConstraints = NO;
	[self.view addSubview:_label];
	[_label.widthAnchor constraintGreaterThanOrEqualToConstant:0.0].active = 
	[_label.heightAnchor constraintGreaterThanOrEqualToConstant:0.0].active = YES;
}

- (void)centerText {
	[self loadViewIfNeeded];
	[_label.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor].active = 
	[_label.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
}

- (void)prepareTextAnimation {
	[self loadViewIfNeeded];
	[_label.topAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-40.0].active = 
	[_label.leftAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:-142.5].active = YES;
}

- (void)animateString:(NSString *)text completion:(void(^)(void))completion {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		for (NSInteger i=0; i<text.length; i++) {
			dispatch_sync(dispatch_get_main_queue(), ^{
				if (!i) _label.text = @"";
				_label.text = [NSString stringWithFormat:@"%@%C", _label.text, [text characterAtIndex:i]];
			});
			[NSThread sleepForTimeInterval:0.1];
		}
		if (completion) {
			dispatch_async(dispatch_get_main_queue(), ^{ completion(); });
		}
	});
}

- (void)animateStrings:(NSArray<NSString *> *)array delay:(NSTimeInterval)delay completion:(void(^)(void))completion {
	if (!array.count) return;
	NSMutableArray *newArray = array.mutableCopy;
	[newArray removeObjectAtIndex:0];
	newArray = (id)[newArray copy];
	[self animateString:array[0] completion:^{
		if (newArray.count) {
			[NSThread sleepForTimeInterval:delay];
			[self animateStrings:(id)newArray delay:delay completion:nil];
		}
		else if (completion) {
			completion();
		}
	}];
}

@end