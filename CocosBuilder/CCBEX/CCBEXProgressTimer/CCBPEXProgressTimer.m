
#import "CCBPEXProgressTimer.h"

@implementation CCBPEXProgressTimer


- (void) setDisplayFrame:(CCSpriteFrame *)displayFrame
{
    self.sprite = [CCSprite spriteWithSpriteFrame:displayFrame];
}

- (CCSpriteFrame*) displayFrame
{
    return self.sprite.displayFrame;
}


@end
