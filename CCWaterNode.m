//
//  IDWaterNode.m
//  WaterSample
//
//  Created by Pavel Muratov on 10.03.15.
//  Copyright (c) 2015 Apportable. All rights reserved.
//

#import "CCWaterNode.h"
#import <CCPhysics+ObjectiveChipmunk.h>
#import <chipmunk/chipmunk_unsafe.h>
#import <chipmunk/chipmunk.h>

////////////////////////////////////////
#pragma mark Math section
////////////////////////////////////////

// Linear interpolation
static inline double lerp(double a, double b, double t)
{
    return a + (b - a) * t;
}

static inline float DegreesToRadians(CGFloat degrees)
{
    return degrees * M_PI / 180;
};

static inline CGPoint FromPolar(float angle, float magnitude)
{
    return ccpMult(ccp(cosf(angle), sinf(angle)), magnitude);
}

static inline float RandomFloat(float min, float max)
{
    return (min + (float)arc4random_uniform(max - min + 1));
}

static inline CGPoint RandomVector2(float maxLength)
{
    return FromPolar(RandomFloat(-M_PI, M_PI), RandomFloat(0, maxLength));
}

static inline float Angle(CGPoint vector)
{
    return atan2f(vector.y, vector.x);
}

////////////////////////////////////////
#pragma mark Particle Class
////////////////////////////////////////
@interface Particle : CCSprite

@property (nonatomic) CGPoint velocity;
@property (nonatomic) float orientation;

@end

@implementation Particle
{
    CGPoint _gravity;
    CGPoint _startPositionInPoints;
}

-(id)initWithPosition:(CGPoint) position velocity:(CGPoint) velocity
          orientation:(float) orientation spriteFrame:(CCSpriteFrame *)frame
                color:(CCColor *)color
{
    if(self = [super init])
    {
        self.positionInPoints = position;
        self.velocity = velocity;
        self.orientation = orientation;
        self.spriteFrame = frame;
        self.colorRGBA = color;
        
        _gravity = ccp(0, -0.3);
        self.anchorPoint = ccp(0.5, 0.5);
    }
    return self;
}

+(id)particleWithPosition:(CGPoint) position velocity:(CGPoint) velocity
          orientation:(float) orientation spriteFrame:(CCSpriteFrame *)frame
                color:(CCColor *)color
{
    return [[self alloc] initWithPosition:position velocity:velocity
                              orientation:orientation spriteFrame:frame
                                    color:color];
}

-(void)update
{
    self.velocity = ccpAdd(self.velocity, _gravity);
    self.positionInPoints = ccpAdd(self.positionInPoints, self.velocity);
    //float r = Angle(self.velocity);
    //self.rotation += Angle(self.velocity) + 90.f;
}

@end

////////////////////////////////////////
#pragma mark WaterColumn Class
////////////////////////////////////////
@interface WaterColumn : NSObject

@property (nonatomic) float targetHeight;
@property (nonatomic) float height;
@property (nonatomic) float speed;

//-(id)initWithHeight:(float)height targetHeight:(float)targetHeigth speed:(float)speed;

@end

@implementation WaterColumn

-(id)initWithHeight:(float)height targetHeight:(float)targetHeigth speed:(float)speed
{
    if (self = [super init]) {
        self.targetHeight = targetHeigth;
        self.height = height;
        self.speed = speed;
    }
    return self;
}

-(void)updateWithDampening:(float)dampening tension:(float)tension
{
    float x = self.targetHeight - self.height;
    self.speed += tension * x - self.speed * dampening;
    self.height += self.speed;
}
@end

////////////////////////////////////////
#pragma mark CCWaterNode Class
////////////////////////////////////////
@implementation CCWaterNode
{
    NSMutableArray *_waterColumns;
    NSMutableArray *_lDeltas;
    NSMutableArray *_rDeltas;
    NSMutableArray *_heights;
    NSMutableArray *_particles;
    
    // Physics shapes that will be updated every frame
    NSMutableArray *_physicsShapes;
    
    CCDrawNode *_waterColumnsDrawNode;
    CCDrawNode *_heightsDrawNode;
    
    // Rendering water here
    CCRenderTexture *_renderTexture;
    
    // Since passing uniform array in a shader is a pain,
    // we will write height of water columns to texture
    // and then pass it into shader
    CCRenderTexture *_heightsRenderTex;
    
    // Render water splash particles here
    CCRenderTexture *_particlesRenderTex;
    
    // Name of the image that will be used as
    // texture for splash drops
    CCSpriteFrame *_splashDropFrame;
    
    int _numberOfColumns;
    int _scaleFactor;
}

/// ------------------------------------------------------- ///
#pragma mark Init
/// ------------------------------------------------------- ///

/// -------------------------   +   ----------------------- ///

+(id)waterNodeWithWidth:(int)w height:(int)h dropsFrame:(CCSpriteFrame *)frame
{
    return [[self alloc] initWithWidth:w height:h tension: 0.2 dampening: 0.06
                                spread: 0.25 color: [CCColor blueColor] dropsFrame: frame];
}

+(id)waterNodeWithWidth:(int)w height:(int)h color:(CCColor *)c dropsFrame:(CCSpriteFrame *)frame
{
    return [[self alloc] initWithWidth:w height:h tension: 0.2 dampening: 0.06
                                spread: 0.25 color: c dropsFrame: frame];
}

+(id)waterNodeWithWidth:(int)w height:(int)h tension:(float)t dampening:(float)d
                 spread:(float)s color:(CCColor *)c dropsFrame:(CCSpriteFrame *)frame
{
    return [[self alloc] initWithWidth:w height:h tension: t dampening: d
                                spread: s color: c dropsFrame: frame];
}

/// -------------------------   -   ----------------------- ///

-(id)initWithWidth:(int)w height:(int)h dropsFrame:(CCSpriteFrame *)frame
{
    return [self initWithWidth:w height:h tension: 0.2 dampening: 0.06 spread: 0.25 color: [CCColor blueColor] dropsFrame:frame];
}

-(id)initWithWidth:(int)w height:(int)h color:(CCColor *)c dropsFrame:(CCSpriteFrame *)frame
{
    return [self initWithWidth:w height:h tension: 0.2 dampening: 0.06 spread: 0.25 color: c dropsFrame: frame];
}

-(id)initWithWidth:(int)w height:(int)h tension:(float)t dampening:(float)d
            spread:(float)s color:(CCColor *)c dropsFrame:(CCSpriteFrame *)frame
{
    if (self = [super init]) {
        self.tension = t;
        self.dampening = d;
        self.spread = s;
        self.contentSizeInPoints = CGSizeMake(w, h);
        self.colorRGBA = c;
        _splashDropFrame = frame;
        
        _scaleFactor = 4;
        _numberOfColumns = self.contentSizeInPoints.width / _scaleFactor + 1;
        
        _waterColumnsDrawNode = [CCDrawNode node];
        _heightsDrawNode = [CCDrawNode node];
        
        _heightsRenderTex = [CCRenderTexture renderTextureWithWidth: (_numberOfColumns - _scaleFactor / 2) height: 1];
        _renderTexture = [CCRenderTexture renderTextureWithWidth:self.contentSize.width
                                                          height:self.contentSize.height];
        _renderTexture.positionInPoints = ccp(_renderTexture.contentSize.width / 2,
                                              _renderTexture.contentSize.height / 2);
        _renderTexture.sprite.blendMode = [CCBlendMode blendModeWithOptions:@{
                                                                              CCBlendFuncSrcColor: @(GL_ONE),
                                                                              CCBlendFuncDstColor: @(GL_ONE_MINUS_SRC_ALPHA),
                                                                              }];
        _particlesRenderTex = [CCRenderTexture renderTextureWithWidth:self.contentSize.width
                                                               height: [CCDirector sharedDirector].viewSize.height];
        
        _particlesRenderTex.positionInPoints = ccp(_particlesRenderTex.contentSize.width / 2,
                                                   _particlesRenderTex.contentSize.height / 2);
        
        _particlesRenderTex.sprite.blendMode = [CCBlendMode blendModeWithOptions:@{
                                                                                   CCBlendFuncSrcColor: @(GL_ONE),
                                                                                   CCBlendFuncDstColor: @(GL_ONE_MINUS_SRC_ALPHA),
                                                                                   }];
        // Gradient shader
        // Using lenear interpolation in a few passes.
        _renderTexture.sprite.shader = [[CCShader alloc] initWithFragmentShaderSource:
                                        @"uniform sampler2D uHeightTex;\n"
                                        @"uniform float uStep0;\n"
                                        @"uniform float uStep1;\n"
                                        @"uniform float uStep2;\n"
                                        @"uniform float uAlpha;\n"
                                        @"uniform float uInterpolate;\n"
                                        
                                        @"void main()\n"
        @"{\n"
            @"vec4 origColor = texture2D(cc_MainTexture, cc_FragTexCoord1);\n"
            @"float height, height1, height2;\n"
            
            @"// Don't process transparent pixels\n"
            @"if (origColor.a > 0.01)\n"
            @"{\n"
                @"if (uInterpolate > 0.0) // Sample uHeightTex few times and interpolate\n"
                @"{\n"
                    @"vec2 x0 = vec2(cc_FragTexCoord1.x - uStep0, 0.0);\n"
                    @"vec2 x1 = vec2(cc_FragTexCoord1.x + uStep0, 0.0);\n"
                    
                    @"height = mix(texture2D(uHeightTex, x0).r,\n"
                                 @"texture2D(uHeightTex, x1).r,\n"
                                 @"0.5);\n"
                    
                    @"x0 = vec2(cc_FragTexCoord1.x - uStep1, 0.0);\n"
                    @"x1 = vec2(cc_FragTexCoord1.x + uStep1, 0.0);\n"
                    
                    @"height1 = mix(texture2D(uHeightTex, x0).r,\n"
                                  @"texture2D(uHeightTex, x1).r,\n"
                                  @"0.5);\n"
                    
                    @"x0 = vec2(cc_FragTexCoord1.x - uStep2, 0.0);\n"
                    @"x1 = vec2(cc_FragTexCoord1.x + uStep2, 0.0);\n"
                    
                    @"height2 = mix(texture2D(uHeightTex, x0).r,\n"
                                  @"texture2D(uHeightTex, x1).r,\n"
                                  @"0.5);"
                    
                    @"height = mix(mix(height1, height2, 0.5), height, 0.5);\n"
                @"}\n"
                @"else // Or don't\n"
                @"{\n"
                    @"height = texture2D(uHeightTex, vec2(cc_FragTexCoord1.x, 0.0)).r;\n"
                @"}\n"
                @"vec3 finalColor = vec3((cc_FragTexCoord1.y) / height + 0.3);\n"
                @"gl_FragColor = vec4(finalColor, uAlpha) * origColor * cc_FragColor;\n"
            @"}\n"
            @"else\n"
            @"{\n"
                @"gl_FragColor = cc_FragColor * origColor;\n"
            @"}\n"
                                        @"}\n"];

        _renderTexture.sprite.shaderUniforms[@"uHeightTex"] = _heightsRenderTex.texture;
        _renderTexture.sprite.shaderUniforms[@"uInterpolate"] = @0.0;
        _renderTexture.sprite.shaderUniforms[@"uAlpha"] = [NSNumber numberWithFloat: self.colorRGBA.alpha];
        _renderTexture.sprite.shaderUniforms[@"uStep0"] = [NSNumber numberWithFloat: 1.0 / (float)_numberOfColumns];
        _renderTexture.sprite.shaderUniforms[@"uStep1"] = [NSNumber numberWithFloat: 1.0 / (float)_numberOfColumns / 2.0];
        _renderTexture.sprite.shaderUniforms[@"uStep2"] = [NSNumber numberWithFloat: 1.0 / (float)_numberOfColumns / 3.0];
        
        
        // This shader makes metaballs out of particles
        _particlesRenderTex.sprite.shader = [[CCShader alloc] initWithFragmentShaderSource:
                                             @"uniform float uAlpha; \n"
                                             @"uniform float uAlphaThreshold; \n"
                                             @"void main() { \n"
                                                 @"vec4 textureColor = cc_FragColor * texture2D(cc_MainTexture, cc_FragTexCoord1); \n"
                                                 @"if (textureColor.a > uAlphaThreshold) gl_FragColor = vec4(textureColor.rgb, uAlpha); \n"
                                                 @"else gl_FragColor = vec4(0.0); \n"
                                             @"}"
                                             ];
        
        _particlesRenderTex.sprite.shaderUniforms[@"uAlphaThreshold"] = [NSNumber numberWithFloat: self.colorRGBA.alpha * 0.8];
        _particlesRenderTex.sprite.shaderUniforms[@"uAlpha"] = [NSNumber numberWithFloat: self.colorRGBA.alpha];
        
        [self addChild: _renderTexture];
        [self addChild: _particlesRenderTex];
        
        _waterColumns = [NSMutableArray arrayWithCapacity: _numberOfColumns];
        _lDeltas = [NSMutableArray arrayWithCapacity: _numberOfColumns];
        _rDeltas = [NSMutableArray arrayWithCapacity: _numberOfColumns];
        _physicsShapes = [NSMutableArray arrayWithCapacity: _numberOfColumns];
        _heights = [NSMutableArray arrayWithCapacity: _numberOfColumns];
        _particles = [NSMutableArray arrayWithCapacity: 10];
        
        for (int i = 0; i < _numberOfColumns; ++i) {
            [_lDeltas addObject: [NSNull null]];
            [_rDeltas addObject: [NSNull null]];
            [_waterColumns addObject: [[WaterColumn alloc] initWithHeight:self.contentSize.height / 2
                                                             targetHeight:self.contentSize.height / 2
                                                                    speed:0]];
        }
        
        for (int i = 0; i < _numberOfColumns - 1; ++i) {
            CGPoint verts[] =
            {
                ccp(i * _scaleFactor, 0),
                ccp(i * _scaleFactor, ((WaterColumn *)_waterColumns[i]).height),
                ccp((i + 1) * _scaleFactor, ((WaterColumn *)_waterColumns[i + 1]).height),
                ccp((i + 1) * _scaleFactor, 0)
            };
            [_physicsShapes addObject: [CCPhysicsShape polygonShapeWithPoints: &verts[0] count: 4 cornerRadius: 1]];
        }

        self.physicsBody = [CCPhysicsBody bodyWithShapes: _physicsShapes];
        self.physicsBody.type = CCPhysicsBodyTypeStatic;
        self.physicsBody.collisionType = @"Water";
    }
    return self;
}

/// ------------------------------------------------------- ///
#pragma mark Properties' setters
/// ------------------------------------------------------- ///

-(void)setInterpolated:(BOOL)interpolated
{
    _interpolated = interpolated;
    _renderTexture.sprite.shaderUniforms[@"uInterpolate"] = _interpolated ? @1.0 : @0.0;
}

-(void)setTension:(float)tension
{
    _tension = (tension < 0) ? 0 : ((tension > 1) ? 1 : tension);
}

-(void)setDampening:(float)dampening
{
    _dampening = (dampening < 0) ? 0 : ((dampening > 1) ? 1 : dampening);
}

-(void)setSpread:(float)spread
{
    _spread = (spread < 0) ? 0 : ((spread > 0.5) ? 0.5 : spread);
}

/// ------------------------------------------------------- ///
#pragma mark Update methods
/// ------------------------------------------------------- ///

-(void)splash:(float)xPosition radius:(float)radius speed:(float)speed
{
    // Adjusting xPosition in case WaterNode's xPosition isn't 0
    xPosition -= (self.positionInPoints.x - self.anchorPointInPoints.x);
    xPosition = clampf(xPosition, 0, self.contentSizeInPoints.width);
    int index = (int)xPosition / _scaleFactor;
    
    // Depending on content size of the body that hits water
    // we pull one or more water columns
    for (int i = MAX(0, index - radius / _scaleFactor); i < MIN(_waterColumns.count - 1, index + radius / _scaleFactor); i++)
        ((WaterColumn *)_waterColumns[i]).speed = speed / 5;
    
    // Create single splash
    [self createSplashParticlesWithPositionX: xPosition
                                       speed: speed / 10 * radius];
}

-(void)createSplashParticlesWithPositionX:(float)xPosition speed:(float)speed
{
    float y = ((WaterColumn *)_waterColumns[(int)xPosition / _scaleFactor]).height;
    
    // Invert speed, because it is negative
    speed *= -1;
    
    if (speed > 50)
    {
        for (int i = 0; i < speed / 4; i++)
        {
            CGPoint pos = ccpAdd(ccp(xPosition, y), RandomVector2(20));
            CGPoint vel = FromPolar(DegreesToRadians(RandomFloat(50, 130)), RandomFloat(0, 0.5 * sqrtf(speed)));
            Particle *p = [Particle particleWithPosition: pos
                                                velocity: vel
                                             orientation: 0
                                             spriteFrame: _splashDropFrame
                                                   color: self.colorRGBA];
            [_particles addObject: p];
        }
    }
}

-(void)update:(CCTime)delta
{
    for (WaterColumn *column in _waterColumns) {
        [column updateWithDampening: self.dampening tension: self.tension];
    }
    
    // do some passes where columns pull on their neighbours
    for (int j = 0; j < 8; j++)
    {
        for (int i = 0; i < _waterColumns.count; i++)
        {
            if (i > 0)
            {
                _lDeltas[i] = [NSNumber numberWithFloat:self.spread * (((WaterColumn *)_waterColumns[i]).height -
                                                                       ((WaterColumn *)_waterColumns[i - 1]).height)];
                ((WaterColumn *)_waterColumns[i - 1]).speed += ((NSNumber *)_lDeltas[i]).floatValue ;
            }
            if (i < _waterColumns.count - 1)
            {
                _rDeltas[i] = [NSNumber numberWithFloat:self.spread * (((WaterColumn *)_waterColumns[i]).height -
                                                                       ((WaterColumn *)_waterColumns[i + 1]).height)];
                ((WaterColumn *)_waterColumns[i + 1]).speed += ((NSNumber *)_rDeltas[i]).floatValue;
            }
        }
        
        for (int i = 0; i < _waterColumns.count; i++)
        {
            if (i > 0)
                ((WaterColumn *)_waterColumns[i - 1]).height += ((NSNumber *)_lDeltas[i]).floatValue;
            if (i < _waterColumns.count - 1)
                ((WaterColumn *)_waterColumns[i + 1]).height += ((NSNumber *)_rDeltas[i]).floatValue;
        }
    }
    
    // Manually update particles,
    // because they are not attached to any node
    // and standart update method is not called
    for (Particle *p in _particles) {
        [p update];
    }
    
    // TODO: I don't like this. Need to find something more efficient.
    // Recreate physics body with new shapes
    CCPhysicsBodyType t = self.physicsBody.type;
    NSArray *cCategory = self.physicsBody.collisionCategories;
    NSArray *cMask = self.physicsBody.collisionMask;
    NSString *cType = self.physicsBody.collisionType;
    id cGroup = self.physicsBody.collisionGroup;
    
    self.physicsBody = nil;
    self.physicsBody = [CCPhysicsBody bodyWithShapes: _physicsShapes];
    self.physicsBody.type = t;
    self.physicsBody.collisionCategories = cCategory;
    self.physicsBody.collisionGroup = cGroup;
    self.physicsBody.collisionMask = cMask;
    self.physicsBody.collisionType = cType;
    
    //
    [_heightsRenderTex beginWithClear:0.0 g:0.0 b:0.0 a:0.0];
    [_heightsDrawNode visit];
    [_heightsRenderTex end];
    
    [_particlesRenderTex beginWithClear:0.0 g:0.0 b:0.0 a:0.0];
    
    for (int i = _particles.count - 1; i >= 0; --i)
    {
        Particle *p = (Particle *)_particles[i];
        
        // Remove particle if it is out of bounds
        if (p.positionInPoints.x < 0 || p.positionInPoints.x > self.contentSizeInPoints.width) {
            [p removeFromParentAndCleanup: YES];
            [_particles removeObjectAtIndex: i];
        }
        else
        {
            WaterColumn *column = ((WaterColumn *)_waterColumns[(int)(p.positionInPoints.x / _scaleFactor)]);
            
            // If particle is under water
            if (p.positionInPoints.y <= column.height) [_particles removeObjectAtIndex: i];
            else [p visit];
        }
    }
    [_particlesRenderTex end];
    
    [_renderTexture beginWithClear:0.0 g:0.0 b:0.0 a:0.0];
    [_waterColumnsDrawNode visit];
    [_renderTexture end];
}

-(void)draw:(CCRenderer *)renderer transform:(const GLKMatrix4 *)transform
{
    [_waterColumnsDrawNode clear];
    [_heightsDrawNode clear];

    float height;
    
    for (int i = 0; i < _numberOfColumns - 1; ++i)
    {
        // Drawing water columns with _waterColumnsDrawNode
        CGPoint verts[] =
        {
            ccp(i * _scaleFactor, 0),
            ccp(i * _scaleFactor, ((WaterColumn *)_waterColumns[i]).height),
            ccp((i + 1) * _scaleFactor, ((WaterColumn *)_waterColumns[i + 1]).height),
            ccp((i + 1) * _scaleFactor, 0)
        };
        CCColor *c = [CCColor colorWithRed:self.colorRGBA.red
                                     green:self.colorRGBA.green
                                      blue:self.colorRGBA.blue
                                     alpha:1.0];
        [_waterColumnsDrawNode drawPolyWithVerts: verts
                                           count: 4
                                       fillColor: c
                                     borderWidth: 0.4
                                     borderColor: c];
        
        // Drawing height values with _heightsDrawNode
        height = ((WaterColumn *)_waterColumns[i]).height / self.contentSizeInPoints.height;
        [_heightsDrawNode drawDot: ccp(i, 0)
                            radius: 1.0
                             color: [CCColor colorWithRed:height
                                                    green:height
                                                     blue:height ]];
        
        // Update physics shapes
        CCPhysicsShape *s = ((CCPhysicsShape *)_physicsShapes[i]);
        cpPolyShapeSetVertsRaw(s.shape.shape, 4, &verts[0]);
    }
    
    // Drawing value of the last water column's height
    height = ((WaterColumn *)_waterColumns[_numberOfColumns - 1]).height / self.contentSizeInPoints.height;
    [_heightsDrawNode drawDot: ccp(_numberOfColumns - 1, 0)
                        radius: 1.0
                         color: [CCColor colorWithRed:height
                                                green:height
                                                 blue:height ]];
}

@end
