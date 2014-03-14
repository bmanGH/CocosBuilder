/*
 * CocosBuilder: http://www.cocosbuilder.com
 *
 * Copyright (c) 2011 Viktor Lidholt
 * Copyright (c) 2012 Zynga Inc.
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
 */

#import "CocosScene.h"
#import "CCBGlobals.h"
#import "CocosBuilderAppDelegate.h"
#import "CCBReaderInternalV1.h"
#import "NodeInfo.h"
#import "PlugInManager.h"
#import "PlugInNode.h"
#import "RulersLayer.h"
#import "GuidesLayer.h"
#import "NotesLayer.h"
#import "CCBTransparentWindow.h"
#import "CCBTransparentView.h"
#import "PositionPropertySetter.h"
#import "CCBGLView.h"
#import "MainWindow.h"
#import "CCNode+NodeInfo.h"
#import "SequencerHandler.h"
#import "SequencerSequence.h"
#import "SequencerNodeProperty.h"
#import "SequencerKeyframe.h"
#import "CCScale9Sprite.h"


// math helper
CGPoint ccpRound(CGPoint pt)
{
    CGPoint rounded;
    rounded.x = roundf(pt.x);
    rounded.y = roundf(pt.y);
    return rounded;
}

// Return closest point on line segment vw and point p
CGPoint ccpClosestPointOnLine(CGPoint v, CGPoint w, CGPoint p)
{
    const float l2 =  ccpLengthSQ(ccpSub(w, v));  // i.e. |w-v|^2 -  avoid a sqrt
    if (l2 == 0.0)
        return v;   // v == w case
    
    // Consider the line extending the segment, parameterized as v + t (w - v).
    // We find projection of point p onto the line.
    // It falls where t = [(p-v) . (w-v)] / |w-v|^2
    const float t = ccpDot(ccpSub(p, v),ccpSub(w , v)) / l2;
    if (t < 0.0)
        return v;        // Beyond the 'v' end of the segment
    else if (t > 1.0)
        return w;  // Beyond the 'w' end of the segment
    
    const CGPoint projection =  ccpAdd(v,  ccpMult(ccpSub(w, v),t));  // v + t * (w - v);  Projection falls on the segment
    return projection;
}


#define kCCBSelectionOutset 3
#define kCCBSinglePointSelectionRadius 23
#define kCCBAnchorPointRadius 6
#define kCCBTransformHandleRadius 5

static CocosScene* sharedCocosScene;

@implementation CocosScene

@synthesize rootNode;
@synthesize isMouseTransforming;
@synthesize scrollOffset;
@synthesize currentTool;
@synthesize guideLayer;
@synthesize rulerLayer;
@synthesize notesLayer;

+(id) sceneWithAppDelegate:(CocosBuilderAppDelegate*)app
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	CocosScene *layer = [[[CocosScene alloc] initWithAppDelegate:app] autorelease];
    sharedCocosScene = layer;
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

+ (CocosScene*) cocosScene
{
    return sharedCocosScene;
}

-(void) setupEditorNodes
{
    // Rulers
    rulerLayer = [RulersLayer node];
    [self addChild:rulerLayer z:6];
    
    // Guides
    guideLayer = [GuidesLayer node];
    [self addChild:guideLayer z:3];
    
    // Sticky notes
    notesLayer = [NotesLayer node];
    [self addChild:notesLayer z:5];
    
    // Selection layer
    selectionLayer = [CCLayer node];
    [self addChild:selectionLayer z:4];
    
    // Border layer
    borderLayer = [CCLayer node];
    [self addChild:borderLayer z:1];
    
    ccColor4B borderColor = ccc4(128, 128, 128, 180);
    
    borderBottom = [CCLayerColor layerWithColor:borderColor];
    borderTop = [CCLayerColor layerWithColor:borderColor];
    borderLeft = [CCLayerColor layerWithColor:borderColor];
    borderRight = [CCLayerColor layerWithColor:borderColor];
    
    [borderLayer addChild:borderBottom];
    [borderLayer addChild:borderTop];
    [borderLayer addChild:borderLeft];
    [borderLayer addChild:borderRight];
    
    borderDevice = [CCSprite node];
    [borderLayer addChild:borderDevice z:1];
    
    // Gray background
    bgLayer = [CCLayerColor layerWithColor:ccc4(128, 128, 128, 255) width:4096 height:4096];
    bgLayer.position = ccp(0,0);
    bgLayer.anchorPoint = ccp(0,0);
    [self addChild:bgLayer z:-1];
    
    // Black content layer
    stageBgLayer = [CCLayerColor layerWithColor:ccc4(0, 0, 0, 255) width:0 height:0];
    stageBgLayer.anchorPoint = ccp(0.5,0.5);
    stageBgLayer.ignoreAnchorPointForPosition = NO;
    [self addChild:stageBgLayer z:0];
    
    contentLayer = [CCLayer node];
    [stageBgLayer addChild:contentLayer];
}

- (void) setStageBorder:(int)type
{
    borderDevice.visible = NO;
    
    if (stageBgLayer.contentSize.width == 0 || stageBgLayer.contentSize.height == 0)
    {
        type = kCCBBorderNone;
        stageBgLayer.visible = NO;
    }
    else
    {
        stageBgLayer.visible = YES;
    }
    
    if (type == kCCBBorderDevice)
    {
        [borderBottom setOpacity:255];
        [borderTop setOpacity:255];
        [borderLeft setOpacity:255];
        [borderRight setOpacity:255];
        
        CCTexture2D* deviceTexture = NULL;
        BOOL rotateDevice = NO;
        
        int devType = [appDelegate orientedDeviceTypeForSize:stageBgLayer.contentSize];
        if (devType == kCCBCanvasSizeIPhonePortrait)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:@"frame-iphone.png"];
            rotateDevice = NO;
        }
        else if (devType == kCCBCanvasSizeIPhoneLandscape)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:@"frame-iphone.png"];
            rotateDevice = YES;
        }
        if (devType == kCCBCanvasSizeIPhone5Portrait)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:@"frame-iphone5.png"];
            rotateDevice = NO;
        }
        else if (devType == kCCBCanvasSizeIPhone5Landscape)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:@"frame-iphone5.png"];
            rotateDevice = YES;
        }
        else if (devType == kCCBCanvasSizeIPadPortrait)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:@"frame-ipad.png"];
            rotateDevice = NO;
        }
        else if (devType == kCCBCanvasSizeIPadLandscape)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:@"frame-ipad.png"];
            rotateDevice = YES;
        }
        else if (devType == kCCBCanvasSizeAndroidXSmallPortrait)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:@"frame-android-xsmall.png"];
            rotateDevice = NO;
        }
        else if (devType == kCCBCanvasSizeAndroidXSmallLandscape)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:@"frame-android-xsmall.png"];
            rotateDevice = YES;
        }
        else if (devType == kCCBCanvasSizeAndroidSmallPortrait)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:@"frame-android-small.png"];
            rotateDevice = NO;
        }
        else if (devType == kCCBCanvasSizeAndroidSmallLandscape)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:@"frame-android-small.png"];
            rotateDevice = YES;
        }
        else if (devType == kCCBCanvasSizeAndroidMediumPortrait)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:@"frame-android-medium.png"];
            rotateDevice = NO;
        }
        else if (devType == kCCBCanvasSizeAndroidMediumLandscape)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:@"frame-android-medium.png"];
            rotateDevice = YES;
        }
        
        if (deviceTexture)
        {
            if (rotateDevice) borderDevice.rotation = 90;
            else borderDevice.rotation = 0;
            
            borderDevice.texture = deviceTexture;
            borderDevice.textureRect = CGRectMake(0, 0, deviceTexture.contentSize.width, deviceTexture.contentSize.height);
            
            borderDevice.visible = YES;
        }
        borderLayer.visible = YES;
    }
    else if (type == kCCBBorderTransparent)
    {
        [borderBottom setOpacity:180];
        [borderTop setOpacity:180];
        [borderLeft setOpacity:180];
        [borderRight setOpacity:180];
        
        borderLayer.visible = YES;
    }
    else if (type == kCCBBorderOpaque)
    {
        [borderBottom setOpacity:255];
        [borderTop setOpacity:255];
        [borderLeft setOpacity:255];
        [borderRight setOpacity:255];
        borderLayer.visible = YES;
    }
    else
    {
        borderLayer.visible = NO;
    }
    
    stageBorderType = type;
    
    [appDelegate updateCanvasBorderMenu];
}

- (int) stageBorder
{
    return stageBorderType;
}

- (void) setupDefaultNodes
{
}

#pragma mark Stage properties

- (void) setStageSize: (CGSize) size centeredOrigin:(BOOL)centeredOrigin
{
    
    stageBgLayer.contentSize = size;
    if (centeredOrigin) contentLayer.position = ccp(size.width/2, size.height/2);
    else contentLayer.position = ccp(0,0);
    
    [self setStageBorder:stageBorderType];
    
    
    if (renderedScene)
    {
        [self removeChild:renderedScene cleanup:YES];
        renderedScene = NULL;
    }
    
    if (size.width > 0 && size.height > 0 && size.width <= 1024 && size.height <= 1024)
    {
        // Use a new autorelease pool
        // Otherwise, two successive calls to the running method (_cmd) cause a crash!
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        renderedScene = [CCRenderTexture renderTextureWithWidth:size.width height:size.height];
        renderedScene.anchorPoint = ccp(0.5f,0.5f);
        [self addChild:renderedScene];

        [pool drain];
    }
    
    
}

- (CGSize) stageSize
{
    return stageBgLayer.contentSize;
}

- (BOOL) centeredOrigin
{
    return (contentLayer.position.x != 0);
}

- (void) setStageZoom:(float) zoom
{
    float zoomFactor = zoom/stageZoom;
    
    scrollOffset = ccpMult(scrollOffset, zoomFactor);
    
    stageBgLayer.scale = zoom;
    borderDevice.scale = zoom;
    
    stageZoom = zoom;
}

- (float) stageZoom
{
    return stageZoom;
}

#pragma mark Extra properties

- (void) setupExtraPropsForNode:(CCNode*) node
{
    [node setExtraProp:[NSNumber numberWithInt:-1] forKey:@"tag"];
    [node setExtraProp:[NSNumber numberWithBool:YES] forKey:@"lockedScaleRatio"];
    
    [node setExtraProp:@"" forKey:@"customClass"];
    [node setExtraProp:[NSNumber numberWithInt:0] forKey:@"memberVarAssignmentType"];
    [node setExtraProp:@"" forKey:@"memberVarAssignmentName"];
    
    [node setExtraProp:[NSNumber numberWithBool:YES] forKey:@"isExpanded"];
}

#pragma mark Replacing content

- (void) replaceRootNodeWith:(CCNode*)node
{
    CCBGlobals* g = [CCBGlobals globals];
    
    [contentLayer removeChild:rootNode cleanup:YES];
    
    self.rootNode = node;
    g.rootNode = node;
    
    if (!node) return;
    
    [contentLayer addChild:node];
}

#pragma mark Handle selections

- (BOOL) selectedNodeHasReadOnlyProperty:(NSString*)prop
{
    CCNode* selectedNode = appDelegate.selectedNode;
    
    if (!selectedNode) return NO;
    NodeInfo* info = selectedNode.userObject;
    PlugInNode* plugIn = info.plugIn;
    
    NSDictionary* propInfo = [plugIn.nodePropertiesDict objectForKey:prop];
    return [[propInfo objectForKey:@"readOnly"] boolValue];
}

- (void) updateSelection
{
    NSArray* nodes = appDelegate.selectedNodes;
    
    uint overTypeField = 0x0;
    
    // Clear selection
    [selectionLayer removeAllChildrenWithCleanup:YES];
    
    if (nodes.count > 0)
    {
        for (CCNode* node in nodes)
        {
            CGPoint localAnchor = ccp(node.anchorPoint.x * node.contentSize.width,
                                      node.anchorPoint.y * node.contentSize.height);
            
            CGPoint anchorPointPos = [node convertToWorldSpace:localAnchor];
            
            CCSprite* anchorPointSprite = [CCSprite spriteWithFile:@"select-pt.png"];
            anchorPointSprite.position = anchorPointPos;
            [selectionLayer addChild:anchorPointSprite z:1];
            
            if (node.ignoreAnchorPointForPosition)
            {
                anchorPointSprite.opacity = 127;
            }
            
            CGPoint points[4]; //{bl,br,tr,tl}
            BOOL isContentSizeZero = NO;
            
            if (node.contentSize.width > 0 && node.contentSize.height > 0)
            {
                // Selection corners in world space
                CCSprite* blSprt = [CCSprite spriteWithFile:@"select-corner.png"];
                CCSprite* brSprt = [CCSprite spriteWithFile:@"select-corner.png"];
                CCSprite* tlSprt = [CCSprite spriteWithFile:@"select-corner.png"];
                CCSprite* trSprt = [CCSprite spriteWithFile:@"select-corner.png"];
                
                [self getCornerPointsForNode:node withPoints:points];
                
                blSprt.position = points[0];
                brSprt.position = points[1];
                trSprt.position = points[2];
                tlSprt.position = points[3];
                
                [selectionLayer addChild:blSprt];
                [selectionLayer addChild:brSprt];
                [selectionLayer addChild:tlSprt];
                [selectionLayer addChild:trSprt];
                
                CCDrawNode* drawing = [CCDrawNode node];
                
                float borderWidth = 1.0; // / [CCDirector sharedDirector].contentScaleFactor;
                
                ccColor4F clearColor = ccc4f(0, 0, 0, 0);
                ccColor4F borderColor = ccc4f(1, 1, 1, 0.3);
                [drawing drawPolyWithVerts:points count:4 fillColor:clearColor borderWidth:borderWidth borderColor:borderColor];
                
                [selectionLayer addChild:drawing z:-1];
            }
            else
            {
                isContentSizeZero = YES;
                CGPoint pos = [node convertToWorldSpace: ccp(0,0)];
                
                CCSprite* sel = [CCSprite spriteWithFile:@"sel-round.png"];
                sel.anchorPoint = ccp(0.5f, 00.5f);
                sel.position = pos;
                [selectionLayer addChild:sel];
                
                [self getCornerPointsForZeroContentSizeNode:node withImageContentSize:CGSizeMake(32, 32) withPoints:points];
            }
            
            // update cursor
            if(!isContentSizeZero && !(overTypeField & kCCBToolAnchor) && currentMouseTransform == kCCBTransformHandleNone)
            {
                if([self isOverAnchor:node withPoint:mousePos])
                {
                    overTypeField |= kCCBToolAnchor;
                }
            }
            
            if(!isContentSizeZero && !(overTypeField & kCCBToolSkew) && currentMouseTransform == kCCBTransformHandleNone)
            {
                if([self isOverSkew:node withPoint:mousePos withOrientation:&skewSegmentOrientation alongAxis:&skewSegment])
                {
                    overTypeField |= kCCBToolSkew;
                }
            }
            
            if(!(overTypeField & kCCBToolRotate) && currentMouseTransform == kCCBTransformHandleNone)
            {
                if([self isOverRotation:mousePos withPoints:points withCorner:&cornerIndex withOrientation:&cornerOrientation])
                {
                    overTypeField |= kCCBToolRotate;
                }
            }
            
            if(!(overTypeField & kCCBToolScale) && currentMouseTransform == kCCBTransformHandleNone)
            {
                if([self isOverScale:mousePos withPoints:points withCorner:&cornerIndex withOrientation:&cornerOrientation])
                {
                    overTypeField |= kCCBToolScale;
                }
            }
            
            if(!(overTypeField & kCCBToolTranslate) && currentMouseTransform == kCCBTransformHandleNone)
            {
                if([self isOverContentBorders:mousePos withPoints:points])
                {
                    overTypeField |= kCCBToolTranslate;
                }
            }
            
        }
    }
    
    // actual update cursor
    if(currentMouseTransform == kCCBTransformHandleNone)
    {
        if(!(overTypeField & currentTool))
        {
            self.currentTool = kCCBToolSelection;
        }
        
        if (overTypeField)
        {
            for(int i = 0; (1 << i) != kCCBToolMax; i++)
            {
                CCBTool type = (1 << i);
                if(overTypeField & type && self.currentTool > type)
                {
                    self.currentTool = type;
                    break;
                }
            }
        }
    }
}

- (void) selectBehind
{
    if (currentNodeAtSelectionPtIdx < 0) return;
    
    currentNodeAtSelectionPtIdx -= 1;
    if (currentNodeAtSelectionPtIdx < 0)
    {
        currentNodeAtSelectionPtIdx = (int)[nodesAtSelectionPt count] -1;
    }
    
    [appDelegate setSelectedNodes:[NSArray arrayWithObject:[nodesAtSelectionPt objectAtIndex:currentNodeAtSelectionPtIdx]]];
}

//0=bottom, 1=right  2=top 3=left
-(CGPoint)vertexLocked:(CGPoint)anchorPoint
{
    CGPoint vertexScaler = ccp(-1.0f,-1.0f);
    
    const float kTolerance = 0.01f;
    if(fabsf(anchorPoint.x) <= kTolerance)
    {
        vertexScaler.x = 3;
    }
    
    if(fabsf(anchorPoint.x) >=  1.0f - kTolerance)
    {
        vertexScaler.x = 1;
    }
    
    if(fabsf(anchorPoint.y) <= kTolerance)
    {
        vertexScaler.y = 0;
    }
    if(fabsf(anchorPoint.y) >=  1.0f - kTolerance)
    {
        vertexScaler.y = 2;
    }
    return vertexScaler;
}

-(CGPoint)vertexLockedScaler:(CGPoint)anchorPoint withCorner:(int) cornerSelected /*{bl,br,tr,tl} */
{
    CGPoint vertexScaler = {1.0f,1.0f};
    
    const float kTolerance = 0.01f;
    if(fabsf(anchorPoint.x) < kTolerance)
    {
        if(cornerSelected == 0 || cornerSelected == 3)
        {
            vertexScaler.x = 0.0f;
        }
    }
    if(fabsf(anchorPoint.x) >  1.0f - kTolerance)
    {
        if(cornerSelected == 1 || cornerSelected == 2)
        {
            vertexScaler.x = 0.0f;
        }
    }
    
    if(fabsf(anchorPoint.y) < kTolerance)
    {
        if(cornerSelected == 0 || cornerSelected == 1)
        {
            vertexScaler.y = 0.0f;
        }
    }
    if(fabsf(anchorPoint.y) >  1.0f - kTolerance)
    {
        if(cornerSelected == 2 || cornerSelected == 3)
        {
            vertexScaler.y = 0.0f;
        }
    }
    return vertexScaler;
}

-(CGPoint)projectOntoVertex:(CGPoint)point withContentSize:(CGSize)size alongAxis:(int)axis//b,r,t,l
{
    CGPoint v = CGPointZero;
    CGPoint w = CGPointZero;
    
    switch (axis) {
        case 0:
            w = CGPointMake(size.width, 0.0f);
            break;
        case 1:
            v = CGPointMake(size.width, 0.0f);
            w = CGPointMake(size.width, size.height);
            
            break;
        case 2:
            v = CGPointMake(size.width, size.height);
            w = CGPointMake(0, size.height);
            
            break;
        case 3:
            v = CGPointMake(0, size.height);
            break;
            
        default:
            break;
    }
    
    //see ccpClosestPointOnLine for notes.
    const float l2 =  ccpLengthSQ(ccpSub(w, v));  // i.e. |w-v|^2 -  avoid a sqrt
    const float t = ccpDot(ccpSub(point, v),ccpSub(w , v)) / l2;
    const CGPoint projection =  ccpAdd(v,  ccpMult(ccpSub(w, v),t));  // v + t * (w - v);  Projection falls on the segment
    return projection;
}

//{bl,br,tr,tl}
-(void)getCornerPointsForNode:(CCNode*)node withPoints:(CGPoint*)points
{
    // Selection corners in world space
    points[0] = ccpRound([node convertToWorldSpace: ccp(0,0)]);
    points[1] = ccpRound([node convertToWorldSpace: ccp(node.contentSize.width,0)]);
    points[2] = ccpRound([node convertToWorldSpace: ccp(node.contentSize.width,node.contentSize.height)]);
    points[3] = ccpRound([node convertToWorldSpace: ccp(0,node.contentSize.height)]);
}

//{bl,br,tr,tl}
-(void)getCornerPointsForZeroContentSizeNode:(CCNode*)node withImageContentSize:(CGSize)contentSize withPoints:(CGPoint*)points
{
    //Hard coded offst
    const CGPoint cornerPos = {11.0f,11.0f};
    
    CGPoint diaganol = ccp(contentSize.width/2, contentSize.height/2);
    diaganol = ccpSub(diaganol, cornerPos);
    CGPoint position  = [node convertToWorldSpace:ccp(0.0f,0.0f)];
    
    points[0] = ccpRound( ccpAdd(position, ccpMult(diaganol, -1.0f)));
    points[1] = ccpRound( ccpAdd(position,ccpRPerp(diaganol)));
    points[2] = ccpRound( ccpAdd(position,diaganol));
    points[3] = ccpRound( ccpAdd(position, ccpPerp(diaganol)));
}

- (BOOL) isOverAnchor:(CCNode*)node withPoint:(CGPoint)pt
{
    CGPoint localAnchor = ccp(node.anchorPoint.x * node.contentSize.width,
                              node.anchorPoint.y * node.contentSize.height);
    
    CGPoint center = [node convertToWorldSpace:localAnchor];
    
    if (ccpDistance(pt, center) < kCCBAnchorPointRadius)
        return YES;
    
    return NO;
}

- (BOOL) isOverSkew:(CCNode*)node withPoint:(CGPoint)pt withOrientation:(CGPoint*)orientation alongAxis:(int*)isXAxis  //{b,r,t,l}
{
    CGPoint points[4]; //{bl,br,tr,tl}
    [self getCornerPointsForNode:node withPoints:points];
    
    if([self isOverContentBorders:mousePos withPoints:points])
        return NO;
    
    for (int i = 0; i < 4; i++)
    {
        
        CGPoint p1 = points[i % 4];
        CGPoint p2 = points[(i + 1) % 4];
        CGPoint segment = ccpSub(p2, p1);
        CGPoint unitSegment = ccpNormalize(segment);
        
        const int kInsetFromEdge = 8;
        const float kDistanceFromSegment = 3.0f;
        
        if(ccpLength(segment) <= kInsetFromEdge * 2)
        {
            continue;//Its simply too small for Skew.
        }
        
        CGPoint adj1 = ccpAdd(p1, ccpMult(unitSegment, kInsetFromEdge));
        CGPoint adj2 = ccpSub(p2, ccpMult(unitSegment, kInsetFromEdge));
        
        
        CGPoint closestPoint = ccpClosestPointOnLine(adj1, adj2, pt);
        float dotProduct = ccpDot( ccpNormalize(ccpSub(adj1, adj2)),ccpNormalize(ccpSub(pt, closestPoint)));
        
        CGPoint vectorFromLine = ccpSub(pt, closestPoint);
        
        //Its close to the line, and perpendicular.
        if((ccpLength(vectorFromLine) < kDistanceFromSegment && fabsf(dotProduct) < 0.01f) ||
           (ccpLength(vectorFromLine) < 0.001 /*very small*/ && fabsf(dotProduct) == 1.0f) /*we're on the line*/)
        {
            CGPoint lockedVertex = [self vertexLocked:node.anchorPoint];
            if(i == lockedVertex.x || i == lockedVertex.y)
                continue;
            
            
            if(orientation)
            {
                *orientation = unitSegment;
            }
            
            if(isXAxis)
            {
                *isXAxis = i;
            }
            
            return YES;
        }
    }
    
    return NO;
}

- (BOOL) isOverContentBorders:(CGPoint)_mousePoint withPoints:(const CGPoint *)points /*{bl,br,tr,tl}*/
{
    CGMutablePathRef mutablePath = CGPathCreateMutable();
    CGPathAddLines(mutablePath, nil, points, 4);
    CGPathCloseSubpath(mutablePath);
    BOOL result = CGPathContainsPoint(mutablePath, nil, _mousePoint, NO);
    CFRelease(mutablePath);
    return result;
}

- (BOOL) isOverScale:(CGPoint)_mousePos withPoints:(const CGPoint*)points/*{bl,br,tr,tl}*/  withCorner:(int*)_cornerIndex withOrientation:(CGPoint*)_orientation
{
    int lCornerIndex = -1;
    CGPoint orientation;
    float minDistance = INFINITY;
    
    for (int i = 0; i < 4; i++)
    {
        CGPoint p1 = points[i % 4];
        CGPoint p2 = points[(i + 1) % 4];
        CGPoint p3 = points[(i + 2) % 4];
        
        const float kDistanceToCorner = 8.0f;
        
        float distance = ccpLength(ccpSub(_mousePos, p2));
        
        if(distance < kDistanceToCorner  && distance < minDistance)
        {
            CGPoint segment1 = ccpSub(p2, p1);
            CGPoint segment2 = ccpSub(p2, p3);
            
            orientation = ccpNormalize(ccpAdd(segment1, segment2));
            lCornerIndex = (i + 1) % 4;
            minDistance = distance;
            
        }
    }
    
    if(lCornerIndex != -1)
    {
        if(_orientation)
        {
            *_orientation = orientation;
        }
        
        if(_cornerIndex)
        {
            *_cornerIndex = lCornerIndex;
        }
        return YES;
    }
    
    return NO;
}

- (BOOL) isOverRotation:(CGPoint)_mousePos withPoints:(const CGPoint*)points/*{bl,br,tr,tl}*/ withCorner:(int*)_cornerIndex withOrientation:(CGPoint*)orientation
{
    for (int i = 0; i < 4; i++)
    {
        CGPoint p1 = points[i % 4];
        CGPoint p2 = points[(i + 1) % 4];
        CGPoint p3 = points[(i + 2) % 4];
        
        CGPoint segment1 = ccpSub(p2, p1);
        CGPoint unitSegment1 = ccpNormalize(segment1);
        
        
        CGPoint segment2 = ccpSub(p2, p3);
        CGPoint unitSegment2 = ccpNormalize(segment2);
        
        const float kMinDistanceForRotation = 8.0f;
        const float kMaxDistanceForRotation = 25.0f;
        
        
        CGPoint mouseVector = ccpSub(_mousePos, p2);
        
        float dot1 = ccpDot(mouseVector, unitSegment1);
        float dot2 = ccpDot(mouseVector, unitSegment2);
        float distanceToCorner = ccpLength(mouseVector);
        
        if(dot1 > 0.0f && dot2 > 0.0f && distanceToCorner > kMinDistanceForRotation && distanceToCorner < kMaxDistanceForRotation)
        {
            if(_cornerIndex)
            {
                *_cornerIndex = (i + 1) % 4;
            }
            
            if(orientation)
            {
                *orientation = ccpNormalize(ccpAdd(unitSegment1, unitSegment2));
            }
            
            return YES;
        }
    }
    
    return NO;
}

#pragma mark Handle mouse input

- (CGPoint) convertToDocSpace:(CGPoint)viewPt
{
    return [contentLayer convertToNodeSpace:viewPt];
}

- (CGPoint) convertToViewSpace:(CGPoint)docPt
{
    return [contentLayer convertToWorldSpace:docPt];
}

- (NSString*) positionPropertyForSelectedNode
{
    NodeInfo* info = appDelegate.selectedNode.userObject;
    PlugInNode* plugIn = info.plugIn;
    
    return plugIn.positionProperty;
}

- (CGPoint) selectedNodePos
{
    if (!appDelegate.selectedNode) return CGPointZero;
    
    return NSPointToCGPoint([PositionPropertySetter positionForNode:appDelegate.selectedNode prop:[self positionPropertyForSelectedNode]]);
}

- (int) transformHandleUnderPt:(CGPoint)pt
{
    for (CCNode* node in appDelegate.selectedNodes)
    {
        transformScalingNode = node;
        
        BOOL isContentSizeZero = NO;
        CGPoint points[4];
        
        if (transformScalingNode.contentSize.width == 0 || transformScalingNode.contentSize.height == 0)
        {
            isContentSizeZero = YES;
            [self getCornerPointsForZeroContentSizeNode:node withImageContentSize:CGSizeMake(24,24) withPoints:points];
        }
        else
        {
            [self getCornerPointsForNode:node withPoints:points];
        }
        
        //NOTE The following return statements should go in order of the CCBTool enumeration.
        //kCCBToolAnchor
        if(!isContentSizeZero && [self isOverAnchor:node withPoint:pt])
            return kCCBTransformHandleAnchorPoint;
        
        if([self isOverContentBorders:pt withPoints:points])
            return kCCBTransformHandleDownInside;
        
        //kCCBToolScale
        if([self isOverScale:pt withPoints:points withCorner:nil withOrientation:nil])
            return kCCBTransformHandleScale;
        
        //kCCBToolSkew
        if(!isContentSizeZero && [self isOverSkew:node withPoint:pt withOrientation:nil alongAxis:nil])
            return kCCBTransformHandleSkew;
        
        //kCCBToolRotate
        if([self isOverRotation:pt withPoints:points withCorner:nil withOrientation:nil])
            return kCCBTransformHandleRotate;
    }
    
    transformScalingNode = NULL;
    return kCCBTransformHandleNone;
}

- (void) nodesUnderPt:(CGPoint)pt rootNode:(CCNode*) node nodes:(NSMutableArray*)nodes
{
    if (!node) return;
    
    NodeInfo* parentInfo = node.parent.userObject;
    PlugInNode* parentPlugIn = parentInfo.plugIn;
    if (parentPlugIn && !parentPlugIn.canHaveChildren) return;
    
    if (node.contentSize.width == 0 || node.contentSize.height == 0)
    {
        CGPoint worldPos = [node.parent convertToWorldSpace:node.position];
        if (ccpDistance(worldPos, pt) < kCCBSinglePointSelectionRadius)
        {
            [nodes addObject:node];
        }
    }
    else
    {
        CGRect hitRect = [node boundingBox];
        
        CCNode* parent = node.parent;
        CGPoint ptLocal = [parent convertToNodeSpace:pt];
        
        if (CGRectContainsPoint(hitRect, ptLocal))
        {
            [nodes addObject:node];
        }
    }
    
    // Visit children
    for (int i = 0; i < [node.children count]; i++)
    {
        [self nodesUnderPt:pt rootNode:[node.children objectAtIndex:i] nodes:nodes];
    }
}

- (BOOL) isLocalCoordinateSystemFlipped:(CCNode*)node
{
    // TODO: Can this be done more efficiently?
    BOOL isMirroredX = NO;
    BOOL isMirroredY = NO;
    CCNode* nodeMirrorCheck = node;
    while (nodeMirrorCheck != rootNode && nodeMirrorCheck != NULL)
    {
        if (nodeMirrorCheck.scaleY < 0) isMirroredY = !isMirroredY;
        if (nodeMirrorCheck.scaleX < 0) isMirroredX = !isMirroredX;
        nodeMirrorCheck = nodeMirrorCheck.parent;
    }
    
    return (isMirroredX ^ isMirroredY);
}

- (BOOL) ccMouseDown:(NSEvent *)event
{
    if (!appDelegate.hasOpenedDocument) return YES;
    
    NSPoint posRaw = [event locationInWindow];
    CGPoint pos = NSPointToCGPoint([appDelegate.cocosView convertPoint:posRaw fromView:NULL]);
    
    if ([notesLayer mouseDown:pos event:event]) return YES;
    if ([guideLayer mouseDown:pos event:event]) return YES;
    
    mouseDownPos = pos;
    
    // Handle grab tool
    if (currentTool == kCCBToolGrab || ([event modifierFlags] & NSCommandKeyMask))
    {
        [[NSCursor closedHandCursor] push];
        isPanning = YES;
        panningStartScrollOffset = scrollOffset;
        return YES;
    }
    
    // Find out which objects were clicked
    
    // Transform handles
    int th = [self transformHandleUnderPt:pos];
    
    if (th == kCCBTransformHandleAnchorPoint)
    {
        // Anchor points are fixed for singel point nodes
        if (transformScalingNode.contentSize.width == 0 || transformScalingNode.contentSize.height == 0)
        {
            return YES;
        }
        
        BOOL readOnly = [[[transformScalingNode.plugIn.nodePropertiesDict objectForKey:@"anchorPoint"] objectForKey:@"readOnly"] boolValue];
        if (readOnly)
        {
            return YES;
        }
        
        // Transform anchor point
        currentMouseTransform = kCCBTransformHandleAnchorPoint;
        transformScalingNode.transformStartPosition = transformScalingNode.anchorPoint;
        return YES;
    }
    if (th == kCCBTransformHandleScale && appDelegate.selectedNode != rootNode)
    {
        if (([event modifierFlags] & NSAlternateKeyMask) &&
            ![appDelegate.selectedNode usesFlashSkew])
        {
            // Start rotation transform (instead of scale)
            currentMouseTransform = kCCBTransformHandleRotate;
            transformStartRotation = transformScalingNode.rotation;
            return YES;
        }
        else
        {
            // Start scale transform
            currentMouseTransform = kCCBTransformHandleScale;
            transformStartScaleX = [PositionPropertySetter scaleXForNode:transformScalingNode prop:@"scale"];
            transformStartScaleY = [PositionPropertySetter scaleYForNode:transformScalingNode prop:@"scale"];
            return YES;
        }
    }
    if (th == kCCBTransformHandleSkew && appDelegate.selectedNode != rootNode)
    {
        currentMouseTransform = kCCBTransformHandleSkew;
        transformStartSkewX = transformScalingNode.skewX;
        transformStartSkewY = transformScalingNode.skewY;
        return YES;
    }
    
    // Clicks inside objects
    [nodesAtSelectionPt removeAllObjects];
    [self nodesUnderPt:pos rootNode:rootNode nodes:nodesAtSelectionPt];
    currentNodeAtSelectionPtIdx = (int)[nodesAtSelectionPt count] -1;
    
    currentMouseTransform = kCCBTransformHandleNone;
    
    if (currentNodeAtSelectionPtIdx >= 0)
    {
        currentMouseTransform = kCCBTransformHandleDownInside;
    }
    else
    {
        // No clicked node
        if ([event modifierFlags] & NSShiftKeyMask)
        {
            // Ignore
            return YES;
        }
        else
        {
            // Deselect
            appDelegate.selectedNodes = NULL;
        }
    }
    
    return YES;
}

- (BOOL) ccMouseDragged:(NSEvent *)event
{
    if (!appDelegate.hasOpenedDocument) return YES;
    [self mouseMoved:event];
    
    NSPoint posRaw = [event locationInWindow];
    CGPoint pos = NSPointToCGPoint([appDelegate.cocosView convertPoint:posRaw fromView:NULL]);
    
    if ([notesLayer mouseDragged:pos event:event]) return YES;
    if ([guideLayer mouseDragged:pos event:event]) return YES;
    
    if (currentMouseTransform == kCCBTransformHandleDownInside)
    {
        CCNode* clickedNode = [nodesAtSelectionPt objectAtIndex:currentNodeAtSelectionPtIdx];
        
        BOOL selectedNodeUnderClickPt = NO;
        for (CCNode* selectedNode in appDelegate.selectedNodes)
        {
            if ([nodesAtSelectionPt containsObject:selectedNode])
            {
                selectedNodeUnderClickPt = YES;
                break;
            }
        }
        
        if ([event modifierFlags] & NSShiftKeyMask)
        {
            // Add to selection
            NSMutableArray* modifiedSelection = [NSMutableArray arrayWithArray: appDelegate.selectedNodes];
            
            if (![modifiedSelection containsObject:clickedNode])
            {
                [modifiedSelection addObject:clickedNode];
            }
            appDelegate.selectedNodes = modifiedSelection;
        }
        else if (![appDelegate.selectedNodes containsObject:clickedNode]
                 && ! selectedNodeUnderClickPt)
        {
            // Replace selection
            appDelegate.selectedNodes = [NSArray arrayWithObject:clickedNode];
        }
        
        for (CCNode* selectedNode in appDelegate.selectedNodes)
        {
            CGPoint pos = NSPointToCGPoint([PositionPropertySetter positionForNode:selectedNode prop:@"position"]);
            
            selectedNode.transformStartPosition = [selectedNode.parent convertToWorldSpace:pos];
        }
    
        if (appDelegate.selectedNode != rootNode)
        {
            currentMouseTransform = kCCBTransformHandleMove;
        }
    }
    
    if (currentMouseTransform == kCCBTransformHandleMove)
    {
        for (CCNode* selectedNode in appDelegate.selectedNodes)
        {
            float xDelta = (int)(pos.x - mouseDownPos.x);
            float yDelta = (int)(pos.y - mouseDownPos.y);
            
            CGSize parentSize = [PositionPropertySetter getParentSize:selectedNode];
            
            // Swap axis for relative positions
            int positionType = [PositionPropertySetter positionTypeForNode:selectedNode prop:@"position"];
            if (positionType == kCCBPositionTypeRelativeBottomRight)
            {
                xDelta = -xDelta;
            }
            else if (positionType == kCCBPositionTypeRelativeTopLeft)
            {
                yDelta = -yDelta;
            }
            else if (positionType == kCCBPositionTypeRelativeTopRight)
            {
                xDelta = -xDelta;
                yDelta = -yDelta;
            }
            else if (positionType == kCCBPositionTypePercent)
            {
                // Handle percental positions
                if (parentSize.width > 0)
                {
                    xDelta = (xDelta/parentSize.width)*100.0f;
                }
                else
                {
                    xDelta = 0;
                }
                
                if (parentSize.height > 0)
                {
                    yDelta = (yDelta/parentSize.height)*100.0f;
                }
                else
                {
                    yDelta = 0;
                }
            }
            
            // Handle shift key (straight drags)
            if ([event modifierFlags] & NSShiftKeyMask)
            {
                if (fabs(xDelta) > fabs(yDelta))
                {
                    yDelta = 0;
                }
                else
                {
                    xDelta = 0;
                }
            }
            
            CGPoint newPos = ccp(selectedNode.transformStartPosition.x+xDelta, selectedNode.transformStartPosition.y+yDelta);
            
            // Snap to guides
            /*
            if (appDelegate.showGuides && appDelegate.snapToGuides)
            {
                // Convert to absolute position (conversion need to happen in node space)
                CGPoint newAbsPos = [selectedNode.parent convertToNodeSpace:newPos];
                
                newAbsPos = NSPointToCGPoint([PositionPropertySetter calcAbsolutePositionFromRelative:NSPointFromCGPoint(newAbsPos) type:positionType parentSize:parentSize]);
                
                newAbsPos = [selectedNode.parent convertToWorldSpace:newAbsPos];
                
                // Perform snapping (snapping happens in world space)
                newAbsPos = [guideLayer snapPoint:newAbsPos];
                
                // Convert back to relative (conversion need to happen in node space)
                newAbsPos = [selectedNode.parent convertToNodeSpace:newAbsPos];
                
                newAbsPos = NSPointToCGPoint([PositionPropertySetter calcRelativePositionFromAbsolute:NSPointFromCGPoint(newAbsPos) type:positionType parentSize:parentSize]);
                
                newPos = [selectedNode.parent convertToWorldSpace:newAbsPos];
            }
             */
            
        
            CGPoint newLocalPos = [selectedNode.parent convertToNodeSpace:newPos];
            
            [appDelegate saveUndoStateWillChangeProperty:@"position"];
            
            [PositionPropertySetter setPosition:NSPointFromCGPoint(newLocalPos) forNode:selectedNode prop:@"position"];
        }
        [appDelegate refreshProperty:@"position"];
    }
    else if (currentMouseTransform == kCCBTransformHandleScale)
    {
        CGPoint nodePos = [transformScalingNode.parent convertToWorldSpace:transformScalingNode.position];
        
        CGPoint deltaStart = ccpSub(nodePos, mouseDownPos);
        CGPoint deltaNew = ccpSub(nodePos, pos);
        
        // Rotate deltas
        CGPoint anglePos0 = [transformScalingNode convertToWorldSpace:ccp(0,0)];
        CGPoint anglePos1 = [transformScalingNode convertToWorldSpace:ccp(1,0)];
        CGPoint angleVector = ccpSub(anglePos1, anglePos0);
        
        float angle = atan2f(angleVector.y, angleVector.x);
        
        deltaStart = ccpRotateByAngle(deltaStart, CGPointZero, -angle);
        deltaNew = ccpRotateByAngle(deltaNew, CGPointZero, -angle);
        
        // Calculate new scale
        float xScaleNew;
        float yScaleNew;
        
        if (fabs(deltaStart.x) > 4) xScaleNew = (deltaNew.x  * transformStartScaleX)/deltaStart.x;
        else xScaleNew = transformStartScaleX;
        if (fabs(deltaStart.y) > 4) yScaleNew = (deltaNew.y  * transformStartScaleY)/deltaStart.y;
        else yScaleNew = transformStartScaleY;
        
        // Handle shift key (uniform scale)
        if ([event modifierFlags] & NSShiftKeyMask)
        {
            // Use the smallest scale composit
            if (fabs(xScaleNew) < fabs(yScaleNew))
            {
                yScaleNew = xScaleNew;
            }
            else
            {
                xScaleNew = yScaleNew;
            }
        }
        
        // Set new scale
        [appDelegate saveUndoStateWillChangeProperty:@"scale"];
        
        int type = [PositionPropertySetter scaledFloatTypeForNode:transformScalingNode prop:@"scale"];
        [PositionPropertySetter setScaledX:xScaleNew Y:yScaleNew type:type forNode:transformScalingNode prop:@"scale"];
        
        [appDelegate refreshProperty:@"scale"];
    }
    else if (currentMouseTransform == kCCBTransformHandleRotate)
    {
        CGPoint nodePos = [transformScalingNode.parent convertToWorldSpace:transformScalingNode.position];
        
        CGPoint handleAngleVectorStart = ccpSub(nodePos, mouseDownPos);
        CGPoint handleAngleVectorNew = ccpSub(nodePos, pos);
        
        float handleAngleRadStart = atan2f(handleAngleVectorStart.y, handleAngleVectorStart.x);
        float handleAngleRadNew = atan2f(handleAngleVectorNew.y, handleAngleVectorNew.x);
        
        float deltaRotationRad = handleAngleRadNew - handleAngleRadStart;
        float deltaRotation = -(deltaRotationRad/(2*M_PI))*360;
        
        if ([self isLocalCoordinateSystemFlipped:transformScalingNode.parent])
        {
            deltaRotation = -deltaRotation;
        }
        
        while ( deltaRotation > 180.0f )
            deltaRotation -= 360.0f;
        while ( deltaRotation < -180.0f )
            deltaRotation += 360.0f;
        
        float newRotation = (transformStartRotation + deltaRotation);
        
        // Handle shift key (fixed rotation angles)
        if ([event modifierFlags] & NSShiftKeyMask)
        {
            float factor = 360.0f/16.0f;
            newRotation = roundf(newRotation/factor)*factor;
        }
        
        [appDelegate saveUndoStateWillChangeProperty:@"rotation"];
        transformScalingNode.rotation = newRotation;
        [appDelegate refreshProperty:@"rotation"];
    }
    else if (currentMouseTransform == kCCBTransformHandleAnchorPoint)
    {
        CGPoint localPos = [transformScalingNode convertToNodeSpace:pos];
        CGPoint localDownPos = [transformScalingNode convertToNodeSpace:mouseDownPos];
        
        CGPoint deltaLocal = ccpSub(localPos, localDownPos);
        CGPoint deltaAnchorPoint = ccp(deltaLocal.x / transformScalingNode.contentSize.width, deltaLocal.y / transformScalingNode.contentSize.height);
        
        [appDelegate saveUndoStateWillChangeProperty:@"anchorPoint"];
        transformScalingNode.anchorPoint = ccpAdd(transformScalingNode.transformStartPosition, deltaAnchorPoint);
        [appDelegate refreshProperty:@"anchorPoint"];
    }
    else if (currentMouseTransform == kCCBTransformHandleSkew)
    {
        CGPoint nodePos = [transformScalingNode.parent convertToWorldSpace:transformScalingNode.position];
        CGPoint anchorInPoint = transformScalingNode.anchorPointInPoints;
        
        //Where did we start.
        CGPoint deltaStart = ccpSub(mouseDownPos, nodePos);
        
        //Where are we now.
        CGPoint deltaNew = ccpSub(pos,nodePos);
        
        //Delta New needs to be projected onto the vertex we're dragging as we're only effecting one skew at the moment.
        
        //First, unwind the current mouse down position to form an untransformed 'root' position: ie where on an untransformed image would you have clicked.
        //CGSize contentSizeInPoints = transformScalingNode.contentSizeInPoints;
        // CGPoint anchorPointInPoints = ccp( contentSizeInPoints.width * transformScalingNode.anchorPoint.x, contentSizeInPoints.height * transformScalingNode.anchorPoint.y );
        
        //T
        CGAffineTransform translateTranform = CGAffineTransformTranslate(CGAffineTransformIdentity, -anchorInPoint.x, -anchorInPoint.y);
        
        //S
        CGAffineTransform scaleTransform = CGAffineTransformMakeScale(transformScalingNode.scaleX,transformScalingNode.scaleY);
        
        //K
        CGAffineTransform skewTransform = CGAffineTransformMake(1.0f, tanf(CC_DEGREES_TO_RADIANS(transformStartSkewY)),
                                                                tanf(CC_DEGREES_TO_RADIANS(transformStartSkewX)), 1.0f,
                                                                0.0f, 0.0f );
        
        //R
        CGAffineTransform rotationTransform = CGAffineTransformMakeRotation(CC_DEGREES_TO_RADIANS(-transformScalingNode.rotation));
        
        
        CGAffineTransform transform = CGAffineTransformConcat(CGAffineTransformConcat(CGAffineTransformConcat(translateTranform,skewTransform),scaleTransform), rotationTransform);
        
        //Root position == x,   xTKSR=mouseDown
        
        //We've got a root position now.cecream
        CGPoint rootStart = CGPointApplyAffineTransform(deltaStart,CGAffineTransformInvert(transform));
        CGPoint rootNew   = CGPointApplyAffineTransform(deltaNew,CGAffineTransformInvert(transform));
        
        
        //Project the delta mouse position onto
        rootStart   = [self projectOntoVertex:rootStart withContentSize:transformScalingNode.contentSize alongAxis:skewSegment];
        rootNew     = [self projectOntoVertex:rootNew   withContentSize:transformScalingNode.contentSize alongAxis:skewSegment];
        
        //Apply translation
        rootStart = CGPointApplyAffineTransform(rootStart,translateTranform);
        rootNew   = CGPointApplyAffineTransform(rootNew,translateTranform);
        CGPoint skew = CGPointMake((rootNew.x - rootStart.x)/rootStart.y,(rootNew.y - rootStart.y)/rootStart.x);
        
        CGAffineTransform skewTransform2 = CGAffineTransformMake(1.0f, skew.y,
                                                                 skew.x, 1.0f,
                                                                 0.0f, 0.0f );
        CGAffineTransform newSkew = CGAffineTransformConcat(skewTransform, skewTransform2);
        
        
        float skewXFinal = CC_RADIANS_TO_DEGREES(atanf(newSkew.c));
        float skewYFinal = CC_RADIANS_TO_DEGREES(atanf(newSkew.b));
        
        [appDelegate saveUndoStateWillChangeProperty:@"skew"];
        transformScalingNode.skewX = skewXFinal;
        transformScalingNode.skewY = skewYFinal;
        [appDelegate refreshProperty:@"skew"];
    }
    else if (isPanning)
    {
        CGPoint delta = ccpSub(pos, mouseDownPos);
        scrollOffset = ccpAdd(panningStartScrollOffset, delta);
    }
    
    return YES;
}

- (void) updateAnimateablePropertyValue:(id)value propName:(NSString*)propertyName type:(int)type
{
    CCNode* selectedNode = appDelegate.selectedNode;
    
    NodeInfo* nodeInfo = selectedNode.userObject;
    PlugInNode* plugIn = nodeInfo.plugIn;
    SequencerHandler* sh = [SequencerHandler sharedHandler];
    
    if ([plugIn isAnimatableProperty:propertyName node:selectedNode])
    {
        SequencerSequence* seq = sh.currentSequence;
        int seqId = seq.sequenceId;
        SequencerNodeProperty* seqNodeProp = [selectedNode sequenceNodeProperty:propertyName sequenceId:seqId];
        
        if (seqNodeProp)
        {
            SequencerKeyframe* keyframe = [seqNodeProp keyframeAtTime:seq.timelinePosition];
            if (keyframe)
            {
                keyframe.value = value;
            }
            else
            {
                SequencerKeyframe* keyframe = [[[SequencerKeyframe alloc] init] autorelease];
                keyframe.time = seq.timelinePosition;
                keyframe.value = value;
                keyframe.type = type;
                
                [seqNodeProp setKeyframe:keyframe];
            }
            
            [sh redrawTimeline];
        }
        else
        {
            [nodeInfo.baseValues setObject:value forKey:propertyName];
        }
    }
}

- (BOOL) ccMouseUp:(NSEvent *)event
{
    if (!appDelegate.hasOpenedDocument) return YES;
    
    CCNode* selectedNode = appDelegate.selectedNode;
    
    NSPoint posRaw = [event locationInWindow];
    CGPoint pos = NSPointToCGPoint([appDelegate.cocosView convertPoint:posRaw fromView:NULL]);
    
    if (currentMouseTransform == kCCBTransformHandleDownInside)
    {
        CCNode* clickedNode = [nodesAtSelectionPt objectAtIndex:currentNodeAtSelectionPtIdx];
        
        if ([event modifierFlags] & NSShiftKeyMask)
        {
            // Add to/subtract from selection
            NSMutableArray* modifiedSelection = [NSMutableArray arrayWithArray: appDelegate.selectedNodes];
            
            if ([modifiedSelection containsObject:clickedNode])
            {
                [modifiedSelection removeObject:clickedNode];
            }
            else
            {
                [modifiedSelection addObject:clickedNode];
                //currentMouseTransform = kCCBTransformHandleMove;
            }
            appDelegate.selectedNodes = modifiedSelection;
        }
        else
        {
            // Replace selection
            [appDelegate setSelectedNodes:[NSArray arrayWithObject:clickedNode]];
            //currentMouseTransform = kCCBTransformHandleMove;
        }
        
        currentMouseTransform = kCCBTransformHandleNone;
    }
    
    if (currentMouseTransform != kCCBTransformHandleNone)
    {
        // Update keyframes & base value
        id value = NULL;
        NSString* propName = NULL;
        int type = kCCBKeyframeTypeDegrees;
        
        if (currentMouseTransform == kCCBTransformHandleRotate)
        {
            value = [NSNumber numberWithFloat: selectedNode.rotation];
            propName = @"rotation";
            type = kCCBKeyframeTypeDegrees;
        }
        else if (currentMouseTransform == kCCBTransformHandleScale)
        {
            float x = [PositionPropertySetter scaleXForNode:selectedNode prop:@"scale"];
            float y = [PositionPropertySetter scaleYForNode:selectedNode prop:@"scale"];
            value = [NSArray arrayWithObjects:
                     [NSNumber numberWithFloat:x],
                     [NSNumber numberWithFloat:y],
                     nil];
            propName = @"scale";
            type = kCCBKeyframeTypeScaleLock;
        }
        else if (currentMouseTransform == kCCBTransformHandleMove)
        {
            CGPoint pt = NSPointToCGPoint([PositionPropertySetter positionForNode:selectedNode prop:@"position"]);
            value = [NSArray arrayWithObjects:
                     [NSNumber numberWithFloat:pt.x],
                     [NSNumber numberWithFloat:pt.y],
                     nil];
            propName = @"position";
            type = kCCBKeyframeTypePosition;
        }
        else if (currentMouseTransform == kCCBTransformHandleSkew)
        {
            float sx = selectedNode.skewX;
            float sy = selectedNode.skewY;
            value = [NSArray arrayWithObjects:
                     [NSNumber numberWithFloat:sx],
                     [NSNumber numberWithFloat:sy],
                     nil];
            propName = @"skew";
            type = kCCBKeyframeTypeFloatXY;
        }
        
        if (value)
        {
            [self updateAnimateablePropertyValue:value propName:propName type:type];
        }
    }
    
    if ([notesLayer mouseUp:pos event:event]) return YES;
    if ([guideLayer mouseUp:pos event:event]) return YES;
    
    isMouseTransforming = NO;
    
    if (isPanning)
    {
        [NSCursor pop];
        isPanning = NO;
    }
    
    currentMouseTransform = kCCBTransformHandleNone;
    return YES;
}

- (void)mouseMoved:(NSEvent *)event
{
    if (!appDelegate.hasOpenedDocument) return;
    
    NSPoint posRaw = [event locationInWindow];
    CGPoint pos = NSPointToCGPoint([appDelegate.cocosView convertPoint:posRaw fromView:NULL]);
    
    mousePos = pos;
}

- (void)mouseEntered:(NSEvent *)event
{
    mouseInside = YES;
    
    if (!appDelegate.hasOpenedDocument) return;
    
    [rulerLayer mouseEntered:event];
}
- (void)mouseExited:(NSEvent *)event
{
    mouseInside = NO;
    
    if (!appDelegate.hasOpenedDocument) return;
    
    [rulerLayer mouseExited:event];
}

- (void)cursorUpdate:(NSEvent *)event
{
    if (!appDelegate.hasOpenedDocument) return;
    
    if (currentTool == kCCBToolGrab)
    {
        [[NSCursor openHandCursor] set];
    }
}

- (void) scrollWheel:(NSEvent *)theEvent
{
    if (!appDelegate.window.isKeyWindow) return;
    if (isMouseTransforming || isPanning || currentMouseTransform != kCCBTransformHandleNone) return;
    if (!appDelegate.hasOpenedDocument) return;
    
    int dx = [theEvent deltaX]*4;
    int dy = -[theEvent deltaY]*4;
    
    scrollOffset.x = scrollOffset.x+dx;
    scrollOffset.y = scrollOffset.y+dy;
}

#pragma mark Updates every frame

- (void) nextFrame:(ccTime) time
{
    // Recenter the content layer
    BOOL winSizeChanged = !CGSizeEqualToSize(winSize, [[CCDirector sharedDirector] winSize]);
    winSize = [[CCDirector sharedDirector] winSize];
    CGPoint stageCenter = ccp((int)(winSize.width/2+scrollOffset.x) , (int)(winSize.height/2+scrollOffset.y));
    
    self.contentSize = winSize;
    
    stageBgLayer.position = stageCenter;
    renderedScene.position = stageCenter;
    
    if (stageZoom <= 1 || !renderedScene)
    {
        // Use normal rendering
        stageBgLayer.visible = YES;
        renderedScene.visible = NO;
        [[borderDevice texture] setAntiAliasTexParameters];
    }
    else
    {
        // Render with render-texture
        stageBgLayer.visible = NO;
        renderedScene.visible = YES;
        renderedScene.scale = stageZoom;
        [renderedScene beginWithClear:0 g:0 b:0 a:1];
        [contentLayer visit];
        [renderedScene end];
        [[borderDevice texture] setAliasTexParameters];
    }
    
    [self updateSelection];
    
    // Setup border layer
    CGRect bounds = [stageBgLayer boundingBox];
    
    borderBottom.position = ccp(0,0);
    [borderBottom setContentSize:CGSizeMake(winSize.width, bounds.origin.y)];
    
    borderTop.position = ccp(0, bounds.size.height + bounds.origin.y);
    [borderTop setContentSize:CGSizeMake(winSize.width, winSize.height - bounds.size.height - bounds.origin.y)];
    
    borderLeft.position = ccp(0,bounds.origin.y);
    [borderLeft setContentSize:CGSizeMake(bounds.origin.x, bounds.size.height)];
    
    borderRight.position = ccp(bounds.origin.x+bounds.size.width, bounds.origin.y);
    [borderRight setContentSize:CGSizeMake(winSize.width - bounds.origin.x - bounds.size.width, bounds.size.height)];
    
    CGPoint center = ccp(bounds.origin.x+bounds.size.width/2, bounds.origin.y+bounds.size.height/2);
    borderDevice.position = center;
    
    // Update rulers
    origin = ccpAdd(stageCenter, ccpMult(contentLayer.position,stageZoom));
    origin.x -= stageBgLayer.contentSize.width/2 * stageZoom;
    origin.y -= stageBgLayer.contentSize.height/2 * stageZoom;
    
    [rulerLayer updateWithSize:winSize stageOrigin:origin zoom:stageZoom];
    [rulerLayer updateMousePos:mousePos];
    
    // Update guides
    guideLayer.visible = appDelegate.showGuides;
    [guideLayer updateWithSize:winSize stageOrigin:origin zoom:stageZoom];
    
    // Update sticky notes
    notesLayer.visible = appDelegate.showStickyNotes;
    [notesLayer updateWithSize:winSize stageOrigin:origin zoom:stageZoom];
    
    if (winSizeChanged)
    {
        // Update mouse tracking
        if (trackingArea)
        {
            [[appDelegate cocosView] removeTrackingArea:trackingArea];
            [trackingArea release];
        }
        
        trackingArea = [[NSTrackingArea alloc] initWithRect:NSMakeRect(0, 0, winSize.width, winSize.height) options:NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited | NSTrackingCursorUpdate | NSTrackingActiveInKeyWindow  owner:[appDelegate cocosView] userInfo:NULL];
        [[appDelegate cocosView] addTrackingArea:trackingArea];
    }
}

#pragma mark Init and dealloc

-(id) initWithAppDelegate:(CocosBuilderAppDelegate*)app;
{
    appDelegate = app;
    
    nodesAtSelectionPt = [[NSMutableArray array] retain];
    
	if( (self=[super init] ))
    {
        
        [self setupEditorNodes];
        [self setupDefaultNodes];
        
        [self schedule:@selector(nextFrame:)];
        
        self.mouseEnabled = YES;
        
        stageZoom = 1;
        
        [self nextFrame:0];
	}
	return self;
}

- (void) dealloc
{
    [trackingArea release];
    [nodesAtSelectionPt release];
	[super dealloc];
}

#pragma mark Debug


@end
