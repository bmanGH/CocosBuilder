
#import "cocos2d.h"

@interface CCBPEXEditBox : CCSprite

@property (nonatomic, readwrite, copy) NSString* fontName;
@property (nonatomic, readwrite, assign) CGFloat fontSize;
@property (nonatomic, readwrite, copy) NSString* placeHolder;
@property (nonatomic, readwrite, retain) CCSpriteFrame* spriteFrame;
@property (nonatomic, readwrite, assign) CGSize dimensions;

@end
