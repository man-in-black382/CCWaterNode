#import "MainScene.h"
#import "CCWaterNode.h"

@implementation MainScene
{
    CCWaterNode *_water;
    CCButton *_button;
    CCPhysicsNode *_physicsNode;
}
-(void)didLoadFromCCB
{
    // 
    _water = [CCWaterNode waterNodeWithWidth:200 height:200
                                     tension:0.25 dampening:0.06 spread:0.1
                                       color:[CCColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:0.8]
                                  dropsFrame:[CCSpriteFrame frameWithImageNamed: @"ccbResources/ccbParticleFire.png"]];
    
    _water.positionInPoints = ccp(0, 0);
    [_physicsNode addChild: _water];
    [CCDirector sharedDirector].displayStats = YES;
    self.userInteractionEnabled = YES;

    _physicsNode.collisionDelegate = self;
    _physicsNode.gravity = ccp(0, -300);
}

-(void)touchBegan:(CCTouch *)touch withEvent:(CCTouchEvent *)event
{
    CCSprite *s = (CCSprite *)[CCBReader load: @"RedBall"];
    s.positionInPoints = [touch locationInWorld];
    s.physicsBody.collisionType = @"Ball";
    [_physicsNode addChild: s];
}


// Сolor interpolation of water columns
// in order to make them look smooth
-(void)interpolationBtnPressed
{
    if (_water.interpolated) {
        _water.interpolated = NO;
        _button.title = @"Interpolation is OFF";
    }
    else {
        _water.interpolated = YES;
        _button.title = @"Interpolation is ON";
    }
}

// CCWaterNode has physics body with collision type set to "Water"
-(BOOL)ccPhysicsCollisionBegin:(CCPhysicsCollisionPair *)pair Ball:(CCNode *)nodeA Water:(CCNode *)nodeB
{
    [_water splash: nodeA.positionInPoints.x radius: nodeA.contentSizeInPoints.width / 2 speed: nodeA.physicsBody.velocity.y];
    [nodeA removeFromParentAndCleanup:YES];
    return NO;
}

@end
