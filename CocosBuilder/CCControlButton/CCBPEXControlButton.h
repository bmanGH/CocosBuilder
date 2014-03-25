//
//  CCBPEXControlButton.h
//  CocosBuilder
//
//  Created by bman on 3/25/14.
//
//

#import "CCControlButton.h"


@interface CCBPEXControlButton : CCControlButton

@property (nonatomic, retain) NSString* titleTTF;
@property (nonatomic, assign) float titleTTFSize;

- (void) setBackgroundSpriteFrame:(CCSpriteFrame *)backgroundSpriteFrame;
@property (nonatomic, assign) float backgroundSpriteInsetLeft;
@property (nonatomic, assign) float backgroundSpriteInsetTop;
@property (nonatomic, assign) float backgroundSpriteInsetRight;
@property (nonatomic, assign) float backgroundSpriteInsetBottom;
@property (nonatomic, assign) BOOL backgroundSpriteTiled;

@end
