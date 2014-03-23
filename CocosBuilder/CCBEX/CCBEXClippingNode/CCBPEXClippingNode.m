
#import "CCBPEXClippingNode.h"

@implementation CCBPEXClippingNode

- (void) setStencilSpriteFrame:(CCSpriteFrame *)stencilSpriteFrame
{
    CCSprite* sprite = [CCSprite spriteWithSpriteFrame:stencilSpriteFrame];
    self.stencil = sprite;
}

- (CCSpriteFrame *) stencilSpriteFrame
{
    CCNode* stencil = self.stencil;
    if (stencil &&
        [stencil isKindOfClass:[CCSprite class]]) {
        CCSprite* sprite = (CCSprite*)stencil;
        return sprite.displayFrame;
    }
    return nil;
}

@end
