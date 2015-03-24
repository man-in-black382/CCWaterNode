Cocos2D water node
==================

This great article (http://gamedevelopment.tutsplus.com/tutorials/make-a-splash-with-dynamic-2d-water-effects--gamedev-236)
inspired me to make a CCNode that will simulate water behaviour. Water consists of springs which obeys Hooke's law. 
Splahses consists of particles that are drawn as metaballs.

Add CCWaterNode.h and CCWaterNode.m to your project. Then create water node and add it to CCPhysicsNode, because it has
physics body for collision detection. By default water's collision type is set to "Water", but you can change it.

```
_water = [CCWaterNode waterNodeWithWidth:200 height:200
                                     tension:0.25 dampening:0.06 spread:0.1
                                       color:[CCColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:0.8]
                                  dropsFrame:[CCSpriteFrame frameWithImageNamed: @"ccbResources/ccbParticleFire.png"]];
    
_water.positionInPoints = ccp(0, 0);
[_physicsNode addChild: _water];
```
Note, that you'll need to provide a sprite frame for the drops which looks like this:
![Alt text](/Packages/SpriteBuilder Resources.sbpack/ccbResources/resources-auto/ccbParticleFire.png?raw=true "Particle")

In this sample project we're creating small red balls that fall on water surface. When ball hits the water, collision is 
detected and we're making the splash:

```
-(BOOL)ccPhysicsCollisionBegin:(CCPhysicsCollisionPair *)pair Ball:(CCNode *)nodeA Water:(CCNode *)nodeB
{
    [_water splash:nodeA.positionInPoints.x radius: nodeA.contentSizeInPoints.width / 2 speed: nodeA.physicsBody.velocity.y];
    [nodeA removeFromParentAndCleanup:YES];
    return NO;
}
```

Screenshots
-----------

For the sake of performance in simulator, water node is small
![Alt text](/Screenshots/Water_main_screenshot.png?raw=true "Screenshot")

This two screenshots demonstrate how interpolation property affects the water:
![Alt text](/Screenshots/WaterNode_interpolated.png?raw=true "Interpolated")

![Alt text](/Screenshots/WaterNode_not_interpolated.png?raw=true "Not interpolated")
