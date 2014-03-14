
#import "CCBPEXTextField.h"

@implementation CCBPEXTextField

@synthesize fontName;
@synthesize fontSize;
@synthesize placeHolder;
@synthesize spriteFrame;
@synthesize dimensions;

- (void) setSpriteFrame:(CCSpriteFrame *)value {
    [super setDisplayFrame:value];
}

@end
