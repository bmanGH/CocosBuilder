/*
 * CCControlButton.m
 *
 * Copyright 2011 Yannick Loriot.
 * http://yannickloriot.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#import "CCControlButton.h"
#import "CCScale9Sprite.h"

enum
{
    kControlButtonTitleLabelZOrder = 2,
    kControlButtonTitleImageZOrder = 1,
    kControlButtonBackgroundZOrder = 0,
	kZoomActionTag = 0xCCCB0001,
};

@interface CCControlButton ()

/** Table of correspondence between the state and its title. */
@property (nonatomic, retain) NSMutableDictionary *titleDispatchTable;
/** Table of correspondence between the state and its title color. */
@property (nonatomic, retain) NSMutableDictionary *titleColorDispatchTable;
/** Table of correspondence between the state and its title image. */
@property (nonatomic, retain) NSMutableDictionary *titleImageDispatchTable;

@end

@implementation CCControlButton

@synthesize titleLabel                      = titleLabel_;
@synthesize titleImage                      = titleImage_;
@synthesize backgroundSprite                = backgroundSprite_;
@synthesize titleDispatchTable              = titleDispatchTable_;
@synthesize titleColorDispatchTable         = titleColorDispatchTable_;
@synthesize titleImageDispatchTable         = titleImageDispatchTable_;
@synthesize touchdownZoomScaleRatio         = touchdownZoomScaleRatio_;
@synthesize touchAreaScaleRatio             = touchAreaScaleRatio_;

- (void)dealloc
{
    [titleImageDispatchTable_       release];
    [titleColorDispatchTable_       release];
    [titleDispatchTable_            release];
    [titleLabel_                    release];
    [titleImage_                    release];
    [backgroundSprite_              release];
    
    [super                          dealloc];
}

#pragma mark -
#pragma mark CCButton - Initializers

- (id)init
{
    return [self initWithLabel:[CCLabelTTF labelWithString:@"" fontName:@"Helvetica" fontSize:12]
              backgroundSprite:[[[CCScale9Sprite alloc] init] autorelease]];
}

- (id)initWithLabel:(CCNode<CCLabelProtocol,CCRGBAProtocol> *)label backgroundSprite:(CCScale9Sprite *)backgroundsprite
{
    if ((self = [super init]))
    {
        NSAssert(label, @"Label must not be nil.");
        NSAssert(backgroundsprite, @"Background sprite must not be nil.");
        NSAssert([backgroundsprite isKindOfClass:[CCScale9Sprite class]], @"The background sprite must be kind of 'CCScale9Sprite' class.");
        
        // Set the default anchor point
        self.ignoreAnchorPointForPosition          = NO;
        self.anchorPoint                    = ccp (0.5f, 0.5f);
        
        // Set the nodes
        self.titleLabel                     = label;
        self.backgroundSprite               = backgroundsprite;
        CCSprite* sprite = [[CCSprite alloc] init];
        self.titleImage                     = sprite;
        [sprite release];
        self.titleImage.visible             = NO;
        
        // Initialize the button state tables
        self.titleDispatchTable             = [NSMutableDictionary dictionary];
        self.titleColorDispatchTable        = [NSMutableDictionary dictionary];
        self.titleImageDispatchTable        = [NSMutableDictionary dictionary];
        
        // Set the default color and opacity
        self.color                          = ccc3(255.0f, 255.0f, 255.0f);
        self.opacity                        = 255.0f;
        self.opacityModifyRGB               = YES;
        
        self.labelAnchorPoint = ccp (0.5f, 0.5f);
        self.imageAnchorPoint = ccp (0.5f, 0.5f);
        
        self.touchdownZoomScaleRatio = 1.1f;
        self.touchAreaScaleRatio = 1.0f;
        
        // Layout update
        [self needsLayout];
    }
    return self;
}

+ (id)buttonWithLabel:(CCNode<CCLabelProtocol,CCRGBAProtocol> *)label backgroundSprite:(CCScale9Sprite *)backgroundsprite
{
    return [[[self alloc] initWithLabel:label backgroundSprite:backgroundsprite] autorelease];
}

- (id)initWithTitle:(NSString *)title fontName:(NSString *)fontName fontSize:(NSUInteger)fontsize
{
    CCLabelTTF *label = [CCLabelTTF labelWithString:title fontName:fontName fontSize:fontsize];
    
    return [self initWithLabel:label backgroundSprite:[CCScale9Sprite node]];
}

+ (id)buttonWithTitle:(NSString *)title fontName:(NSString *)fontName fontSize:(NSUInteger)fontsize
{
    return [[[self alloc] initWithTitle:title fontName:fontName fontSize:fontsize] autorelease];
}

/** Initializes a button with a sprite in background. */
- (id)initWithBackgroundSprite:(CCScale9Sprite *)sprite
{
    CCLabelTTF *label = [CCLabelTTF labelWithString:@"" fontName:@"Marker Felt" fontSize:30];
    
    return [self initWithLabel:label backgroundSprite:sprite];
}

+ (id)buttonWithBackgroundSprite:(CCScale9Sprite *)sprite
{
    return [[[self alloc] initWithBackgroundSprite:sprite] autorelease];
}

#pragma mark Properties

- (void)setHighlighted:(BOOL)highlighted
{
    highlighted_        = highlighted;
    
    CCAction *action    = [self getActionByTag:kZoomActionTag];
    if (action)
    {
        [self stopAction:action];
    }
    
    [self needsLayout];
    
    if (touchdownZoomScaleRatio_ != 1.0f)
    {
        float scaleValue        = [self isHighlighted] ? self.touchdownZoomScaleRatio : 1.0f;
        CCAction *zoomAction    = [CCScaleTo actionWithDuration:0.05f scale:scaleValue];
        zoomAction.tag          = kZoomActionTag;
        [self runAction:zoomAction];
    }
}

- (void) setLabelAnchorPoint:(CGPoint)labelAnchorPoint
{
    labelAnchorPoint_ = labelAnchorPoint;
    
    [self needsLayout];
}

- (CGPoint) labelAnchorPoint
{
    return labelAnchorPoint_;
}

- (void) setImageAnchorPoint:(CGPoint)imageAnchorPoint
{
    imageAnchorPoint_ = imageAnchorPoint;
    
    [self needsLayout];
}

- (CGPoint) imageAnchorPoint
{
    return imageAnchorPoint_;
}

#pragma mark -
#pragma mark CCButton Public Methods

- (void) setTitleLabel:(CCNode<CCLabelProtocol,CCRGBAProtocol> *)titleLabel
{
    [titleLabel retain];
    [titleLabel_ release];
    titleLabel_ = titleLabel;
    if (titleLabel) {
        [self addChild:titleLabel z:kControlButtonTitleLabelZOrder];
        [self needsLayout];
    }
}

- (void) setTitleImage:(CCSprite *)titleImage
{
    [titleImage retain];
    [titleImage_ release];
    titleImage_ = titleImage;
    if (titleImage) {
        [self addChild:titleImage z:kControlButtonTitleImageZOrder];
        [self needsLayout];
    }
}

- (void) setBackgroundSprite:(CCScale9Sprite *)backgroundSprite
{
    [backgroundSprite retain];
    [backgroundSprite_ release];
    backgroundSprite_ = backgroundSprite;
    if (backgroundSprite) {
        [self addChild:backgroundSprite z:kControlButtonBackgroundZOrder];
        [self needsLayout];
    }
}

- (NSString *)titleForState:(CCControlState)state
{
    NSNumber *stateNumber = [NSNumber numberWithLong:state];
    NSString *title = [titleDispatchTable_ objectForKey:stateNumber];
    
    if (title)
    {
        return title;
    }
    
    return @"";
}

- (void)setTitle:(NSString *)title forState:(CCControlState)state
{
    NSNumber *stateNumber = [NSNumber numberWithLong:state];
    
    [titleDispatchTable_ removeObjectForKey:stateNumber];
    
    if (title)
    {
        [titleDispatchTable_ setObject:title forKey:stateNumber];
    }
    
    // If the current state if equal to the given state we update the layout
    if (state_ == state)
    {
        [self needsLayout];
    }
}

- (ccColor3B)titleColorForState:(CCControlState)state
{
    ccColor3B returnColor = ccWHITE;
    
    NSNumber *stateNumber   = [NSNumber numberWithLong:state];
    NSValue *colorValue     = [titleColorDispatchTable_ objectForKey:stateNumber];
    
    if (colorValue)
    {
        [colorValue getValue:&returnColor];
        return returnColor;
    }
    
    return returnColor;
}

- (void)setTitleColor:(ccColor3B)color forState:(CCControlState)state
{
    NSNumber *stateNumber   = [NSNumber numberWithLong:state];
    
    NSValue *colorValue     = [NSValue valueWithBytes:&color objCType:@encode(ccColor3B)];
    
    [titleColorDispatchTable_ removeObjectForKey:stateNumber];
    [titleColorDispatchTable_ setObject:colorValue forKey:stateNumber];
    
    // If the current state if equal to the given state we update the layout
    if (state_ == state)
    {
        [self needsLayout];
    }
}

- (CCSpriteFrame*) titleImageForState:(CCControlState)state
{
    NSNumber *stateNumber = [NSNumber numberWithLong:state];
    CCSpriteFrame *image = [titleImageDispatchTable_ objectForKey:stateNumber];
    
    if (image)
    {
        return image;
    }
    
    return nil;
}

- (void)setTitleImage:(CCScale9Sprite *)image forState:(CCControlState)state
{
    NSNumber *stateNumber   = [NSNumber numberWithLong:state];
    
    [titleImageDispatchTable_ removeObjectForKey:stateNumber];
    [titleImageDispatchTable_ setObject:image forKey:stateNumber];
    
    // If the current state if equal to the given state we update the layout
    if (state_ == state)
    {
        [self needsLayout];
    }
}

#pragma mark CCButton Private Methods

- (void)needsLayout
{
    if (self.titleLabel)
    {
        self.titleLabel.string = [self titleForState:self.state];
        self.titleLabel.color = [self titleColorForState:self.state];
        self.titleLabel.position = ccp (self.contentSize.width / 2, self.contentSize.height / 2);
        self.titleLabel.anchorPoint = self.labelAnchorPoint;
    }
    
    CCSpriteFrame* imageFrame = [self titleImageForState:self.state];
    if (imageFrame)
    {
        [self.titleImage setDisplayFrame:imageFrame];
        self.titleImage.color = [self titleColorForState:self.state];
        self.titleImage.position = ccp (self.contentSize.width / 2, self.contentSize.height / 2);
        self.titleImage.anchorPoint = self.imageAnchorPoint;
        self.titleImage.visible = YES;
    }
    else
    {
        self.titleImage.visible = NO;
    }
    
    if (self.backgroundSprite)
    {
        self.backgroundSprite.color = [self titleColorForState:self.state];
        [self.backgroundSprite setContentSize:self.contentSize];
        self.backgroundSprite.position = ccp (self.contentSize.width / 2, self.contentSize.height / 2);
        self.backgroundSprite.anchorPoint = ccp(0.5f, 0.5f);
    }
}

#pragma mark -
#pragma mark CCTargetedTouch Delegate Methods

#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED

- (BOOL)ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event
{
    if (![self isTouchInside:touch]
        || ![self isEnabled]
        || ![self visible]
        || ![self hasVisibleParents])
    {
		return NO;
	}
    
    state_              = CCControlStateHighlighted;
    pushed_             = YES;
    self.highlighted    = YES;
    
    [self sendActionsForControlEvents:CCControlEventTouchDown];
    
	return YES;
}

- (void)ccTouchMoved:(UITouch *)touch withEvent:(UIEvent *)event
{
    if (![self isEnabled]
        || [self isSelected])
    {
        if ([self isHighlighted])
        {
            [self setHighlighted:NO];
        }
        return;
    }
    
    BOOL isTouchMoveInside = [self isTouchInside:touch];
    if (isTouchMoveInside && ![self isHighlighted])
    {
        state_ = CCControlStateHighlighted;
        
        [self setHighlighted:YES];
        
        [self sendActionsForControlEvents:CCControlEventTouchDragEnter];
    } else if (isTouchMoveInside && [self isHighlighted])
    {
        [self sendActionsForControlEvents:CCControlEventTouchDragInside];
    } else if (!isTouchMoveInside && [self isHighlighted])
    {
        state_ = CCControlStateNormal;
        
        [self setHighlighted:NO];
        
        [self sendActionsForControlEvents:CCControlEventTouchDragExit];
    } else if (!isTouchMoveInside && ![self isHighlighted])
    {
        [self sendActionsForControlEvents:CCControlEventTouchDragOutside];
    }
}

- (void)ccTouchEnded:(UITouch *)touch withEvent:(UIEvent *)event
{
    state_              = CCControlStateNormal;
    self.highlighted    = NO;
    
    if ([self isTouchInside:touch])
    {
        [self sendActionsForControlEvents:CCControlEventTouchUpInside];
    } else
    {
        [self sendActionsForControlEvents:CCControlEventTouchUpOutside];
    }
}

- (void)ccTouchCancelled:(UITouch *)touch withEvent:(UIEvent *)event
{
    state_              = CCControlStateNormal;
    self.highlighted    = NO;
    
    [self sendActionsForControlEvents:CCControlEventTouchCancel];
}

#elif __MAC_OS_X_VERSION_MAX_ALLOWED

- (BOOL)ccMouseDown:(NSEvent *)event
{
    if (![self isMouseInside:event])
    {
        return NO;
    }
    
    state_              = CCControlStateHighlighted;
    self.highlighted    = YES;
    
    [self sendActionsForControlEvents:CCControlEventTouchDown];
    
    return YES;
}


- (BOOL)ccMouseDragged:(NSEvent *)event
{
	if (![self isEnabled]
        || [self isSelected])
    {
        if ([self isHighlighted])
        {
            [self setHighlighted:NO];
        }
        return NO;
    }
    
    BOOL isMouseMoveInside = [self isMouseInside:event];
    if (isMouseMoveInside && ![self isHighlighted])
    {
        state_ = CCControlStateHighlighted;
        
        [self setHighlighted:YES];
        
        [self sendActionsForControlEvents:CCControlEventTouchDragEnter];
    } else if (isMouseMoveInside && [self isHighlighted])
    {
        [self sendActionsForControlEvents:CCControlEventTouchDragInside];
    } else if (!isMouseMoveInside && [self isHighlighted])
    {
        state_ = CCControlStateNormal;
        
        [self setHighlighted:NO];
        
        [self sendActionsForControlEvents:CCControlEventTouchDragExit];
    } else if (!isMouseMoveInside && ![self isHighlighted])
    {
        [self sendActionsForControlEvents:CCControlEventTouchDragOutside];
    }
    
	return YES;
}

- (BOOL)ccMouseUp:(NSEvent *)event
{
    state_              = CCControlStateNormal;
    self.highlighted    = NO;
    
    if ([self isMouseInside:event])
    {
        [self sendActionsForControlEvents:CCControlEventTouchUpInside];
    } else
    {
        [self sendActionsForControlEvents:CCControlEventTouchUpOutside];
    }
    
	return NO;
}

#endif

- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
    NSArray* chunks = [key componentsSeparatedByString:@"|"];
    if ([chunks count] == 2)
    {
        NSString* keyChunk = [chunks objectAtIndex:0];
        int state = [[chunks objectAtIndex:1] intValue];
        
        if ([keyChunk isEqualToString:@"title"])
        {
            [self setTitle:value forState:state];
        }
        else if ([keyChunk isEqualToString:@"imageSpriteFrame"])
        {
            [self setTitleImage:value forState:state];
        }
        else if ([keyChunk isEqualToString:@"titleColor"])
        {
            ccColor3B c;
            [value getValue:&c];
            [self setTitleColor:c forState:state];
        }
        else
        {
            [super setValue:value forUndefinedKey:key];
        }
        
        [self needsLayout];
    }
    else
    {
        [super setValue:value forUndefinedKey:key];
    }
}

- (id)valueForUndefinedKey:(NSString *)key
{
    NSArray* chunks = [key componentsSeparatedByString:@"|"];
    if ([chunks count] == 2)
    {
        NSString* keyChunk = [chunks objectAtIndex:0];
        int state = [[chunks objectAtIndex:1] intValue];
        
        if ([keyChunk isEqualToString:@"title"])
        {
            return [self titleForState:state];
        }
        else if ([keyChunk isEqualToString:@"titleColor"])
        {
            ccColor3B c = [self titleColorForState:state];
            return [NSValue value:&c withObjCType:@encode(ccColor3B)];
        }
        else
        {
            return [super valueForUndefinedKey:key];
        }
    }
    else
    {
        return [super valueForUndefinedKey:key];
    }
}

#pragma mark - override

- (void) setContentSize:(CGSize)contentSize
{
    [super setContentSize:contentSize];
    
    [self needsLayout];
}

@end
