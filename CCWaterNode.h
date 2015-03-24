//
//  IDWaterNode.h
//  WaterSample
//
//  Created by Pavel Muratov on 10.03.15.
//  Copyright (c) 2015 Apportable. All rights reserved.
//

#import "CCNode.h"

@interface CCWaterNode : CCNode

/** @name Water tension
 *
 *  Value should be between 0 and 1.
 *  A high value will make the water look more like jiggling Jello.
 */
@property (nonatomic) float tension;

/** @name Dampening factor
 *
 *  Dampens oscillation of waves.
 *  Value should be between 0 and 1.
 */
@property (nonatomic) float dampening;

/** @name Wave spread
 *
 * Controls how fast the waves spread.
 * It can take values between 0 and 0.5,
 * with larger values making the waves spread out faster. 
 */
@property (nonatomic) float spread;

/** @name Interpolate water columns' heights 
 *
 * Interpolating between water columns' heights for smooth gradient.
 */
@property (nonatomic) BOOL interpolated;

+(id)waterNodeWithWidth:(int)w height:(int)h dropsFrame:(CCSpriteFrame *)frame;
+(id)waterNodeWithWidth:(int)w height:(int)h color:(CCColor *)c dropsFrame:(CCSpriteFrame *)frame;
+(id)waterNodeWithWidth:(int)w height:(int)h tension:(float)t dampening:(float)d spread:(float)s color:(CCColor *)c dropsFrame:(CCSpriteFrame *)frame;

-(id)initWithWidth:(int)w height:(int)h dropsFrame:(CCSpriteFrame *)frame;
-(id)initWithWidth:(int)w height:(int)h color:(CCColor *)c dropsFrame:(CCSpriteFrame *)frame;
-(id)initWithWidth:(int)w height:(int)h tension:(float)t dampening:(float)d spread:(float)s color:(CCColor *)c dropsFrame:(CCSpriteFrame *)frame;

/**
 *  Returns height of water column at a given index
 *
 *  @param xPosition X coord of body and water collistion.
 *  @param radius Radius of the body.
 *  @param speed Y velocity of the body.
 */
-(void)splash:(float)xPosition radius:(float)radius speed:(float)speed;

@end

