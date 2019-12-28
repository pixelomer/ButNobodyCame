#import "BNCViewController.h"
#import <stdint.h>
#import <CoreText/CoreText.h>
#import <unistd.h>
#import "data/font.h"

@implementation BNCViewController
@dynamic view;

- (void)loadView {
	self.view = [BNCView new];
}

@end