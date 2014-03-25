//
//  CCBPEXControlButton.m
//  CocosBuilder
//
//  Created by bman on 3/25/14.
//
//

#import "CCBPEXControlButton.h"
#import "CCScale9Sprite.h"

@implementation CCBPEXControlButton

- (NSString*) titleTTF
{
    CCLabelTTF* labelTTF = (CCLabelTTF*)self.titleLabel;
    return labelTTF.fontName;
}

- (void) setTitleTTF:(NSString*)ttf
{
    CCLabelTTF* labelTTF = (CCLabelTTF*)self.titleLabel;
    labelTTF.fontName = ttf;
    
    [self needsLayout];
}

- (float) titleTTFSize
{
    CCLabelTTF* labelTTF = (CCLabelTTF*)self.titleLabel;
    return labelTTF.fontSize;
}

- (void) setTitleTTFSize:(float)size
{
    CCLabelTTF* labelTTF = (CCLabelTTF*)self.titleLabel;
    labelTTF.fontSize = size;
    
    [self needsLayout];
}

- (void) setBackgroundSpriteFrame:(CCSpriteFrame*)value
{
    [self.backgroundSprite setSpriteFrame:value];
    
    [self needsLayout];
}

- (float) backgroundSpriteInsetLeft
{
    return self.backgroundSprite.insetLeft;
}

- (void) setBackgroundSpriteInsetLeft:(float)value
{
    self.backgroundSprite.insetLeft = value;
    
    [self needsLayout];
}

- (float) backgroundSpriteInsetTop
{
    return self.backgroundSprite.insetTop;
}

- (void) setBackgroundSpriteInsetTop:(float)value
{
    self.backgroundSprite.insetTop = value;
    
    [self needsLayout];
}

- (float) backgroundSpriteInsetRight
{
    return self.backgroundSprite.insetRight;
}

- (void) setBackgroundSpriteInsetRight:(float)value
{
    self.backgroundSprite.insetRight = value;
    
    [self needsLayout];
}

- (float) backgroundSpriteInsetBottom
{
    return self.backgroundSprite.insetBottom;
}

- (void) setBackgroundSpriteInsetBottom:(float)value
{
    self.backgroundSprite.insetBottom = value;
    
    [self needsLayout];
}

- (BOOL) backgroundSpriteTiled
{
    return [self.backgroundSprite isTiled];
}

- (void) setBackgroundSpriteTiled:(BOOL)value
{
    self.backgroundSprite.tiled = value;
    
    [self needsLayout];
}

@end
