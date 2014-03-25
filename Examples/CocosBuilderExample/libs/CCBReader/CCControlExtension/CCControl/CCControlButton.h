/*
 * CCControlButton.h
 *
 * Copyright 2011 Yannick Loriot. All rights reserved.
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

#import "CCControl.h"

/* Define the button margin for Left/Right edge */
#define CCControlButtonMarginLR 8 // px
/* Define the button margin for Top/Bottom edge */
#define CCControlButtonMarginTB 2 // px

@class CCScale9Sprite;

/** @class CCControlButton Button control for Cocos2D. */
@interface CCControlButton : CCControl
{
@public
    CCNode<CCLabelProtocol, CCRGBAProtocol> *titleLabel_;
    CCSprite                                *titleImage_;
    CCScale9Sprite                          *backgroundSprite_;
    
@protected
    BOOL                                    needUpdateUI_;
    
    NSMutableDictionary                     *titleDispatchTable_;
    NSMutableDictionary                     *titleColorDispatchTable_;
    NSMutableDictionary                     *titleImageDispatchTable_;
    
    CGPoint labelAnchorPoint_;
    CGPoint imageAnchorPoint_;
    
    float touchdownZoomScaleRatio_;
    float touchAreaScaleRatio_;
}

/** The current title label. */
@property (nonatomic, retain) CCNode<CCLabelProtocol,CCRGBAProtocol> *titleLabel;
/** The current title label. */
@property (nonatomic, retain) CCSprite *titleImage;
/** The current background sprite. */
@property (nonatomic, retain) CCScale9Sprite *backgroundSprite;
/** The anchorPoint of the label, default is (0.5,0.5) */
@property (nonatomic, assign) CGPoint labelAnchorPoint;
/** The anchorPoint of the image, default is (0.5,0.5) */
@property (nonatomic, assign) CGPoint imageAnchorPoint;
/** Scale ratio button on touchdown. Default value 1.1f */
@property (nonatomic, assign) float touchdownZoomScaleRatio;
/** Scale ratio button touch area on touchdown. Default value 1.0f */
@property (nonatomic, assign) float touchAreaScaleRatio;

#pragma mark Constructors - Initializers

/** Initializes a button with a label in foreground and a sprite in background. */
- (id)initWithLabel:(CCNode<CCLabelProtocol, CCRGBAProtocol> *)label backgroundSprite:(CCScale9Sprite *)backgroundsprite;

/** Creates a button with a label in foreground and a sprite in background. */
+ (id)buttonWithLabel:(CCNode<CCLabelProtocol, CCRGBAProtocol> *)label backgroundSprite:(CCScale9Sprite *)backgroundsprite;

/** Initializes a button with a title, a font name and a font size for the label in foreground. */
- (id)initWithTitle:(NSString *)title fontName:(NSString *)fontName fontSize:(NSUInteger)fontsize;

/** Creates a button with a title, a font name and a font size for the label in foreground. */
+ (id)buttonWithTitle:(NSString *)title fontName:(NSString *)fontName fontSize:(NSUInteger)fontsize;

/** Initializes a button with a sprite in background. */
- (id)initWithBackgroundSprite:(CCScale9Sprite *)sprite;

/** Creates a button with a sprite in background. */
+ (id)buttonWithBackgroundSprite:(CCScale9Sprite *)sprite;

#pragma mark - Public Methods

/**
 * Returns the title used for a state.
 *
 * @param state The state that uses the title. Possible values are described in
 * "CCControlState".
 *
 * @return The title for the specified state.
 */
- (NSString *)titleForState:(CCControlState)state;

/**
 * Sets the title string to use for the specified state.
 * If a property is not specified for a state, the default is to use
 * the CCButtonStateNormal value.
 *
 * @param title The title string to use for the specified state.
 * @param state The state that uses the specified title. The values are described
 * in "CCControlState".
 */
- (void)setTitle:(NSString *)title forState:(CCControlState)state;

/**
 * Returns the title color used for a state.
 *
 * @param state The state that uses the specified color. The values are described
 * in "CCControlState".
 *
 * @return The color of the title for the specified state.
 */
- (ccColor3B)titleColorForState:(CCControlState)state;

/**
 * Sets the color of the title to use for the specified state.
 *
 * @param color The color of the title to use for the specified state.
 * @param state The state that uses the specified color. The values are described
 * in "CCControlState".
 */
- (void)setTitleColor:(ccColor3B)color forState:(CCControlState)state;

/**
 * Returns the background sprite used for a state.
 *
 * @param state The state that uses the background sprite. Possible values are
 * described in "CCControlState".
 */
- (CCSpriteFrame *)titleImageForState:(CCControlState)state;

/**
 * Sets the background sprite to use for the specified button state.
 *
 * @param sprite The background sprite to use for the specified state.
 * @param state The state that uses the specified image. The values are described
 * in "CCControlState".
 */
- (void)setTitleImage:(CCSpriteFrame *)sprite forState:(CCControlState)state;

@end
