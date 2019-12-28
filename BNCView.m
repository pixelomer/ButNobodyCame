#import "BNCView.h"
#import <stdint.h>
#import <CoreText/CoreText.h>
#import <unistd.h>
#import "data/font.h"

static uint8_t fontData[] = DETERMINATION_FONT_DATA;

@implementation BNCView

static NSObject *lockObject;
static UIFont *font;

+ (void)load {
	if (self == [BNCView class]) {
		lockObject = [NSObject new];
	}
}

+ (UIFont *)font {
	@synchronized (lockObject) {
		if (!font) {
			CGDataProviderRef fontDataRef = CGDataProviderCreateWithData(
				NULL, fontData, sizeof(fontData), NULL
			);
			CGFontRef fontRef = CGFontCreateWithDataProvider(fontDataRef);
			CFRelease(fontDataRef);
			CTFontRef graphicsFontRef = CTFontCreateWithGraphicsFont(fontRef, 22.5, NULL, NULL);
			CFRelease(fontRef);
			font = [(__bridge UIFont *)graphicsFontRef copy];
			CFRelease(graphicsFontRef);
		}
	}
	return font;
}

- (instancetype)init {
	if ((self = [super init])) {
		_label = [UILabel new];
		self.backgroundColor = [UIColor blackColor];
		_label.textColor = [UIColor whiteColor];
		_label.numberOfLines = 0;
		_label.font = self.class.font;
		_label.translatesAutoresizingMaskIntoConstraints = NO;
		[self addSubview:_label];
		[_label.widthAnchor constraintGreaterThanOrEqualToConstant:0.0].active = 
		[_label.heightAnchor constraintGreaterThanOrEqualToConstant:0.0].active = YES;
	}
	return self;
}

- (void)centerText {
	[_label.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = 
	[_label.centerXAnchor constraintEqualToAnchor:self.centerXAnchor].active = YES;
}

- (void)prepareTextAnimation {
	[_label.topAnchor constraintEqualToAnchor:self.centerYAnchor constant:-40.0].active = 
	[_label.leftAnchor constraintEqualToAnchor:self.centerXAnchor constant:-142.5].active = YES;
}

- (void)animateString:(NSString *)text completion:(void(^)(void))completion {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		for (NSInteger i=0; i<text.length; i++) {
			dispatch_sync(dispatch_get_main_queue(), ^{
				if (!i) _label.text = @"";
				unichar c = [text characterAtIndex:i];
				if (c != 0x07) _label.text = [NSString stringWithFormat:@"%@%C", _label.text, c];
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