// i would not recommend looking at the contents of this file
// proceed with caution

#include <Accelerate/Accelerate.h>
#include <iostream>
#include <vector>
#include <AVFoundation/AVFoundation.h>
#include <arpa/inet.h>
#include <cmath>
#include <UIKit/UIKit.h>
#include <mach/mach.h>
#include "colour.mm"
#include <string.h>
#include <errno.h>
#include <MRYIPCCenter.h>
#include "drm.mm"

inline float clamp(float v, float l, float u) {
    return std::min(u, std::max(l, v));
}

float mem_usage_mib() {
    struct task_basic_info info;
    mach_msg_type_number_t size = TASK_BASIC_INFO_COUNT;
    kern_return_t kerr = task_info(mach_task_self(),
                                   TASK_BASIC_INFO,
                                   (task_info_t)&info,
                                   &size);

    if(kerr == KERN_SUCCESS) {
        return (float)info.resident_size / 1048576.f;
    }

    return -1.f;
}

// who needs a doctor when you got a frequency consultant
// ####/
// o-o/
//  -/
// well sir it seems you are not frequent enough

struct frequency_consultant {
private:
    float *outReal = nullptr;
    float *outImaginary = nullptr;
    DSPSplitComplex splitOutput {};
    int bufferLog2 {};
    FFTSetup fft {};
    float *hannWindow = nullptr;
public:
    int allocatedSize {};

    void allocate(int size) {
        os_log(OS_LOG_DEFAULT, "[BB] set size");
        allocatedSize = size;

        os_log(OS_LOG_DEFAULT, "[BB] alloc real");
        outReal = (float *)std::malloc(sizeof(float) * size);//new float[size];

        os_log(OS_LOG_DEFAULT, "[BB] alloc imaginary");
        outImaginary = (float *)std::malloc(sizeof(float) * size);

        os_log(OS_LOG_DEFAULT, "[BB] create split");
        splitOutput = {
            .realp = outReal,
            .imagp = outImaginary
        };

        os_log(OS_LOG_DEFAULT, "[BB] create BL2");
        bufferLog2 = std::floor(std::log2(size * 2));

        os_log(OS_LOG_DEFAULT, "[BB] set up fft");
        fft = vDSP_create_fftsetup(bufferLog2, kFFTRadix2);

        os_log(OS_LOG_DEFAULT, "[BB] create window buf");
        hannWindow = (float *)std::malloc(sizeof(float) * size);

        os_log(OS_LOG_DEFAULT, "[BB] init window");
        vDSP_hann_window(hannWindow, size, vDSP_HANN_NORM);
    }

    void release() {
        vDSP_destroy_fftsetup(fft);

        splitOutput = {};

        allocatedSize = bufferLog2 = 0;

        // delete[] outReal;
        // delete[] outImaginary;
        // delete[] hannWindow;

        std::free(outReal);
        std::free(outImaginary);
        std::free(hannWindow);

        outReal = outImaginary = hannWindow = nullptr;
    }

    void reallocate(int size) {
        allocatedSize = size;

        vDSP_destroy_fftsetup(fft);

        outReal      = (float *)std::realloc(outReal,      sizeof(float) * size);
        outImaginary = (float *)std::realloc(outImaginary, sizeof(float) * size);
        hannWindow   = (float *)std::realloc(hannWindow,   sizeof(float) * size);

        splitOutput.realp = outReal;
        splitOutput.imagp = outImaginary;

        bufferLog2 = std::floor(std::log2(size * 2));
        fft = vDSP_create_fftsetup(bufferLog2, kFFTRadix2);

        vDSP_hann_window(hannWindow, size, vDSP_HANN_NORM);
    }

    frequency_consultant(int initialSize) { 
        allocate(initialSize);
    }

    bool consult(float *inBuf, int inLen, float *outBuf, int outLen) {
        if(inLen != allocatedSize) {
            os_log(OS_LOG_DEFAULT, "[BB] frequency consultant does not understand, reallocating");
            
            reallocate(inLen);
            return false;
        }

        vDSP_vmul(inBuf, 1, hannWindow, 1, inBuf, 1, inLen);
        vDSP_ctoz((COMPLEX *)inBuf, 2, &splitOutput, 1, inLen);
        vDSP_fft_zrip(fft, &splitOutput, 1, bufferLog2, FFT_FORWARD);

        vDSP_zvmags(&splitOutput, 1, outBuf, 1, inLen);

        return true;
    }
};

bool extractFrequencyMagnitudes(float *inBuf, int inLen, float *outBuf, int outLen) {
    static frequency_consultant consultant = frequency_consultant(inLen);
    return consultant.consult(inBuf, inLen, outBuf, outLen);
}

template <typename T>
void quantize(std::vector<T> &v1, std::vector<T> &v2, int binCount, float multiplier = 1.f) {
    int binSize = int(v1.size() / binCount);
    v2.reserve(binCount);

    T curTotal = 0;
    int curSize = 0;
    for(T val : v1) {
        curTotal += (val * multiplier);

        if(++curSize == binSize) {

            v2.push_back(curTotal / T(curSize));

            curTotal = 0;
            curSize = 0;
        }
    }
}

// 'var' is faster to type
// idc what you think
#define var auto

float lerp(float a, float b, float f) {
    return a + f * (b - a);
}

static var audioEngine = [AVAudioEngine new];

template <typename T>
T multiplyForRange(T value, T lower, T upper) {
    T orig = value;

    for(int i = 0; value < lower or value > upper; ++i) {
        value = orig * i;

        if(value > upper) break;
    }

    return value;
}

// Information that is only valid for the current song.
// Used to give the best visualisation for the current music.
// Should be reset when the music changes.
struct vis_state_info {
    // Metadata; this is the size of each of the two contained arrays.
    int numPoints = 0;

    // The value that frequency magnitudes are measured against.
    // Decreases over time so that quieter parts of music are still seen.
    float referenceMax = FLT_MIN;

    // The actual maximum magnitude we have seen so far.
    // Used to determine how much the whole circle should grow/shrink.
    // Doesn't decrease over time.
    float unmodifiedMax = FLT_MIN;

    // The highest magnitude seen since last checked.
    // When referenceMax is lowered, its new value is the average of referenceMax
    //  and maxSinceLastUpdate (with a certain bias).
    float maxSinceLastUpdate = FLT_MIN;

    // Used to determine when to reset referenceMax.
    int noUpdateCounter = 0;

    // The multipliers used for the radii of sections of the circle when last rendered.
    float *lastMultipliers = nullptr;

    // The maximum magnitude for each of the frequency ranges.
    // Modulated as referenceMax.
    float *perRangePeaks = nullptr;

    vis_state_info() {}

    vis_state_info(int pointCount) {
        numPoints = pointCount;

        lastMultipliers = new float[pointCount];
        std::fill_n(lastMultipliers, pointCount, 1.f);

        perRangePeaks = new float[pointCount];
    }

    void reset() {
        if(lastMultipliers) std::fill_n(lastMultipliers, numPoints, 1.f);
        if(perRangePeaks) std::fill_n(perRangePeaks, numPoints, 0.f);

        referenceMax = unmodifiedMax = maxSinceLastUpdate = FLT_MIN;
        noUpdateCounter = 0;
    }

    ~vis_state_info() {
        delete[] lastMultipliers;
        delete[] perRangePeaks;
    }
};

@interface SQSpikyVisualizerLayer : CAShapeLayer
// For calculating animation times.
@property float targetFPS;
@end

@implementation SQSpikyVisualizerLayer

- (id<CAAction>)actionForKey:(NSString *)event {
    // Animation is only really required if we're aiming below ~40fps.
    // Anything above this looks smooth with lerped values.
    if (self.targetFPS < 40.f and [event isEqualToString:@"path"]) {
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:event];
        animation.duration = 1.f / self.targetFPS;

        return animation;
    }

    return [super actionForKey:event];
}

@end

static bool automaticPause = true;

@interface SBMediaController : NSObject
+(id)sharedInstance;
-(BOOL)isPlaying;
@end

@interface SQLockscreenDisplayLink : CADisplayLink
@end

// Just so we don't waste battery/CPU power updating when not visible.
%subclass SQLockscreenDisplayLink : CADisplayLink

-(BOOL)isPaused {
    BOOL original = %orig;
    return original or (automaticPause and ((not [[[UIApplication sharedApplication] keyWindow] isKindOfClass:%c(SBCoverSheetWindow)]) or (not [[%c(SBMediaController) sharedInstance] isPlaying])));
}

%end

enum coloring_mode {
    automatic,
    custom
};

#define CAT(x, y) CAT_(x, y)
#define CAT_(x, y) x ## y

#define FOR_KEY_SEL ForKey
#define TYP_VALUE Value
#define VALUE_GETTER(typ, nme) -(typ)CAT(nme, FOR_KEY_SEL):(NSString *)k { \
    id vk = _values ? _values[k] : nullptr; \
    if(not vk or not k) { \
        _err = 1; \
        return typ {}; \
    } \
    return [_values[k] CAT(nme, TYP_VALUE)];\
}\
-(typ)CAT(nme, FOR_KEY_SEL):(NSString *)k withDefault:(typ)def {\
    _err = 0;\
    if(not _values) return def;\
    typ val = [self CAT(nme, FOR_KEY_SEL):k];\
    if(_err) return def;\
    return val;\
}

using uchar = unsigned char;
using ullong = unsigned long long;
using ulong = unsigned long;
using llong = long long;

#define VALUE_GETTER_INTERFACE(typ, nme) -(typ)CAT(nme, FOR_KEY_SEL):(NSString *)k;\
-(typ)CAT(nme, FOR_KEY_SEL):(NSString *)k withDefault:(typ)def;

static id bbpmgr = nil;

// Basically just NSUserDefaults because I forgot that existed...
@interface BBPreferenceManager : NSObject {
    int _err;
    NSDictionary *_values;
}

+(BBPreferenceManager *)managerWithPlist:(NSString *)plistPath;
VALUE_GETTER_INTERFACE(bool, bool);
VALUE_GETTER_INTERFACE(int, int);
VALUE_GETTER_INTERFACE(float, float);
VALUE_GETTER_INTERFACE(llong, longLong);
VALUE_GETTER_INTERFACE(double, double);
VALUE_GETTER_INTERFACE(long, long);
VALUE_GETTER_INTERFACE(short, short);
VALUE_GETTER_INTERFACE(uchar, unsignedChar);
VALUE_GETTER_INTERFACE(unsigned, unsignedInt);
VALUE_GETTER_INTERFACE(ullong, unsignedLongLong);
VALUE_GETTER_INTERFACE(ulong, unsignedLong);
VALUE_GETTER_INTERFACE(ushort, unsignedShort);

-(UIColor *)colorForKey:(NSString *)key;
-(UIColor *)colorForKey:(NSString *)key withDefault:(UIColor *)col;
-(void)reloadWithPath:(NSString *)plistPath;

@property (class, nonatomic, assign) BBPreferenceManager *currentManager;
+(BBPreferenceManager *)currentManager;
+(void)setCurrentManager:(BBPreferenceManager *)mgr;
@end

@implementation BBPreferenceManager

+(BBPreferenceManager *)currentManager {
    return bbpmgr;
}

+(void)setCurrentManager:(BBPreferenceManager *)mgr {
    bbpmgr = mgr;
}

-(bool)loadFromPlist:(NSString *)plistPath {
    if(not plistPath) return false;

    NSError *err;
    _values = [NSDictionary dictionaryWithContentsOfURL:[NSURL fileURLWithPath:plistPath] error:&err];

    if(err) _values = [NSDictionary dictionary];

    return not err;
}

+(BBPreferenceManager *)managerWithPlist:(NSString *)plistPath {
    BBPreferenceManager *mgr = [BBPreferenceManager new];
    [mgr loadFromPlist:plistPath];

    return mgr;
}

-(void)reloadWithPath:(NSString *)plistPath {
    [self loadFromPlist:plistPath];
}

VALUE_GETTER(bool, bool);
VALUE_GETTER(int, int);
VALUE_GETTER(float, float);
VALUE_GETTER(llong, longLong);
VALUE_GETTER(double, double);
VALUE_GETTER(long, long);
VALUE_GETTER(short, short);
VALUE_GETTER(uchar, unsignedChar);
VALUE_GETTER(unsigned, unsignedInt);
VALUE_GETTER(ullong, unsignedLongLong);
VALUE_GETTER(ulong, unsignedLong);
VALUE_GETTER(ushort, unsignedShort);

-(UIColor *)colorForKey:(NSString *)key {
    _err = 0;
    unsigned colorInt = [self unsignedIntForKey:key];
    if(_err) return nullptr;

    const unsigned r = colorInt >> 24 & 0xFF,
                   g = colorInt >> 16 & 0xFF,
                   b = colorInt >> 8 & 0xFF,
                   a = colorInt >> 0 & 0xFF;

    return [UIColor colorWithRed:float(r) / 255.0f green:float(g) / 255.0f blue:float(b) / 255.0f alpha:float(a) / 100.0f];
}

-(UIColor *)colorForKey:(NSString *)key withDefault:(UIColor *)col {
    UIColor *c = [self colorForKey:key];
    return c ? c : col;
}

@end

@interface SQSpikyVisualizerView : UIView {
    //int _connfd;
    @public SQLockscreenDisplayLink *_link;
    @public bool _needsStateReset;
    @public int _unansweredRequests;
    @public SQSpikyVisualizerLayer *circleLayer;
    @public MRYIPCCenter *_ipccenter;
}

// Basic stuff
@property float baseRadius;
@property int pointCount;
@property int smoothingFactor;

// Bounciness (growing/shrinking with audio loudness)
@property float maxExpansionRadius;
@property bool shouldExpand;
@property float radiusAttackLerpFactor;
@property float radiusDecayLerpFactor;

// Things
@property (nonatomic, copy) UIColor *ringColor;
@property int targetFPS;
@property bool fillCircle;

// Responsiveness
@property float freqAttackLerpFactor;
@property float freqDecayLerpFactor;
@property int peakLowerFrequency;

@property float rawMultiplier;

@property bool isOnLSBackground;

@property coloring_mode coloringMode;

@property (nonatomic, readwrite, assign) id colorTarget;
@property (nonatomic, assign) SEL colorSelector;

@end

inline void postNotification(const char *name, id object = nil) {
    [[NSNotificationCenter defaultCenter] postNotificationName:@(name) object:object];
}

inline void addObserver(id obj, const char *name, SEL action, id whatDoICareAbout = nil) {
    [[NSNotificationCenter defaultCenter] addObserver:obj selector:action name:@(name) object:whatDoICareAbout];
}

static bool safeToRemove = false;
static int unansweredRequests = 0;
static bool updatePlease = false;
static bool wantsQuit = false;
static bool currentlyProcessing = false;
static int connectionsOpen = 0;
static bool needsUIRefresh = true;
static bool isGoingAfterComplete = false;
static bool isComingBack = false;

static bool reconnectWhenPossible = false;

#include "paths.mm"

#include <libproc.h>
pid_t get_mediaserverd_pid() {
    pid_t pids[2048];
    int bytes = proc_listpids(PROC_ALL_PIDS, 0, pids, sizeof(pids));
    int proc_count = bytes / sizeof(pids[0]);

    char proc_path_buf[PROC_PIDPATHINFO_MAXSIZE];

    for(int i = 0; i < proc_count; ++i) {
        pid_t pid = pids[i];

        int len = proc_pidpath(pid, proc_path_buf, sizeof(proc_path_buf));

        std::string full_path(proc_path_buf, proc_path_buf + len);
        if(full_path == "/usr/sbin/mediaserverd") {
            return pid;
        }
    }

    return 0;
}

/*
SBCoverSheetDidPresentNotification
SBCoverSheetDidDismissNotification

_MRMediaRemotePlayerPlaybackStateDidChangeNotification
SBMediaNowPlayingChangedNotification

SBAudioRoutesChangedNotification
*/

static bool waitingForResponse = false;
static bool needsPrefReload = true;
#include <notify.h>
#import <MediaRemote/MediaRemote.h>
@implementation SQSpikyVisualizerView

-(instancetype)initWithFrame:(CGRect)f {
    if(self = [super initWithFrame:f]) {
        self.isOnLSBackground = false;

        _ipccenter = [MRYIPCCenter centerNamed:[NSString stringWithFormat:@"squ1dd13's disco server %d", get_mediaserverd_pid()]];

        needsPrefReload = true;

        self.baseRadius = 110.f;
        self.pointCount = [[BBPreferenceManager currentManager] intForKey:@"number o' points" withDefault:50];
        self.smoothingFactor = 5;

        self.maxExpansionRadius = 130.f;
        self.shouldExpand = true;
        self.radiusAttackLerpFactor = .5f;
        self.radiusDecayLerpFactor = .6f;

        self.ringColor = [[BBPreferenceManager currentManager] colorForKey:@"defaultcolour" withDefault:[UIColor colorWithWhite:0.8f alpha:1.f]];//[UIColor redColor];//colorFromDefaults(@"defaultcolour", @"com.squ1dd13.bb_pref_ting.plist", [UIColor whiteColor]);
        self.targetFPS = 25;
        self.coloringMode = (coloring_mode)[[BBPreferenceManager currentManager] intForKey:@"colourmode" withDefault:0];

        self.freqAttackLerpFactor = .5f;
        self.freqDecayLerpFactor = .6f;
        self.peakLowerFrequency = 8;

        self.rawMultiplier = 1.f;

        self.alpha = 0.8f;

        self.fillCircle = [[BBPreferenceManager currentManager] boolForKey:@"fillCircle" withDefault:true];

        _needsStateReset = false;
        unansweredRequests = 0;

        addObserver(self, "SBCoverSheetDidPresentNotification", @selector(resumeDancing:));
        addObserver(self, "SBCoverSheetDidDismissNotification", @selector(pauseDancing:));
        addObserver(self, "_MRMediaRemotePlayerPlaybackStateDidChangeNotification", @selector(respondToNowPlayingChanged:));
        
        addObserver(self, [(__bridge NSString *)kMRMediaRemoteNowPlayingInfoDidChangeNotification UTF8String], @selector(nowPlayingInfoDidChange:));
        addObserver(self, "SBAudioRoutesChangedNotification", @selector(updateIPC:));
    }

    return self;
}

-(UIColor *)ringColor {
    static UIColor *lastColor = nullptr;//[[BBPreferenceManager currentManager] colorForKey:@"defaultcolour" withDefault:[UIColor colorWithWhite:0.8f alpha:1.f]];
    static int colorUpdateCounter = 50;
    if(++colorUpdateCounter > 50 or not lastColor) {
        colorUpdateCounter = 0;

        if(self.coloringMode == custom or (not self.colorTarget or not self.colorSelector) or not [self.colorTarget respondsToSelector:self.colorSelector]) {
            return self.ringColor = lastColor = [[BBPreferenceManager currentManager] colorForKey:@"defaultcolour" withDefault:[UIColor colorWithWhite:0.8f alpha:1.f]];
        }

        return self.ringColor = lastColor = [self.colorTarget performSelector:self.colorSelector];
    }

    return lastColor;
}

-(void)updateIPC:(NSNotification *)note {
    // We need to set up a new connection when mediaserverd gets killed. To make sure we have the right
    //  connection name, we can use the mediaserverd PID to differentiate between old and new connections.
    // This works because each end will have the same value for the PID.

    // mediaserverd is killed when the audio route changes.

    static pid_t pid = 0;

    pid_t thisMSDPID = get_mediaserverd_pid();
    if(pid == thisMSDPID) return;
    pid = thisMSDPID;

    os_log(OS_LOG_DEFAULT, "[BB] updating centre name");

    _ipccenter = [MRYIPCCenter centerNamed:[NSString stringWithFormat:@"squ1dd13's disco server %d", thisMSDPID]];
    waitingForResponse = false;
}

-(void)shrinkAway {
    return;
    dispatch_async(dispatch_get_main_queue(), ^{
        var basicAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];//CABasicAnimation(keyPath: "strokeEnd")
        basicAnimation.fromValue = @(1.f);
        basicAnimation.toValue = @0.f;
        basicAnimation.duration = .5f;
        basicAnimation.fillMode = kCAFillModeBackwards;
        basicAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

        circleLayer.strokeEnd = 0.f;

        [circleLayer addAnimation:basicAnimation forKey:@"undrawanim"];
    });
}

-(void)growBack {
    return;
    dispatch_async(dispatch_get_main_queue(), ^{
        var basicAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];//CABasicAnimation(keyPath: "strokeEnd")
        basicAnimation.fromValue = @(0.f);
        basicAnimation.toValue = @1.f;
        basicAnimation.duration = .5f;
        basicAnimation.fillMode = kCAFillModeForwards;
        basicAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

        circleLayer.strokeEnd = 1.f;

        [circleLayer addAnimation:basicAnimation forKey:@"drawanim"];
    });
}

- (void)nowPlayingInfoDidChange:(NSNotification *)notif {
    os_log(OS_LOG_DEFAULT, "[BB] yes");
    if(self.isOnLSBackground) {
        MRMediaRemoteGetNowPlayingInfo(dispatch_get_main_queue(), ^(CFDictionaryRef information) {
            NSDictionary *infoDictionary = (__bridge NSDictionary *)information;

            static NSString *key = (__bridge NSString *)kMRMediaRemoteNowPlayingApplicationIsPlayingUserInfoKey;
            NSNumber *isPlaying = infoDictionary[key];

            //self.hidden = [isPlaying boolValue];
            os_log(OS_LOG_DEFAULT, "[BB] hidden? %d", self.hidden);
        });
    } else {
        os_log(OS_LOG_DEFAULT, "[BB] not on ls");
    }
}

-(void)respondToNowPlayingChanged:(NSNotification *)notif {
    //return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if(not self.isOnLSBackground) return;
        if([notif userInfo]) {
            NSNumber *number = [notif userInfo][@"kMRMediaRemoteNowPlayingApplicationIsPlayingUserInfoKey"];
            if(number) {
                os_log(OS_LOG_DEFAULT, "[BB] state changed");

                [UIView animateWithDuration:.5f animations:^{
                    [self setAlpha:float([number boolValue])];
                } completion:nil];
                //self.hidden = not [number boolValue];
            }
        }
    });

    
}

-(void)resumeDancing:(id)obj {
    _link.paused = false;
}

-(void)pauseDancing:(id)obj {
    _link.paused = true;
}

-(void)connect {//WithDataAction:(void (^)(float *data, bool))block {
    return;
}

-(void)disconnect {
    return;
}

-(BOOL)isAnyAudioPlaying {
    return [[AVAudioSession sharedInstance] isOtherAudioPlaying];
}

-(void)initLayer {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.ringColor = [[BBPreferenceManager currentManager] colorForKey:@"defaultcolour" withDefault:[UIColor colorWithWhite:0.8f alpha:1.f]];
        if(not circleLayer) {
            circleLayer = [SQSpikyVisualizerLayer layer];
            [self.layer addSublayer:circleLayer];
        }

        [circleLayer setStrokeColor:self.ringColor ? (self.ringColor.CGColor) : ([UIColor redColor].CGColor)];

        if(not self.fillCircle) {
            [circleLayer setFillColor:[UIColor clearColor].CGColor];
        } else {
            [circleLayer setFillColor:circleLayer.strokeColor];
        }

        [circleLayer setBackgroundColor:[UIColor clearColor].CGColor];
        [circleLayer setLineWidth:2.f];
        circleLayer.lineCap = kCALineCapRound;
        circleLayer.lineJoin = kCALineJoinRound;
        circleLayer.targetFPS = self.targetFPS;
        circleLayer.miterLimit = -10.f;

        circleLayer.zPosition = 2.f;
        self.layer.zPosition = 1.f;

        //self.alpha = [[BBPreferenceManager currentManager] floatForKey:@"see-able-ness" withDefault:100.f] / 100.f;
    });
}

-(void)configureDisplayLink{
    _link = [%c(SQLockscreenDisplayLink) displayLinkWithTarget:self selector:@selector(refresh)];

    [_link addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [_link setPaused:false];

    _link.preferredFramesPerSecond = 25;
}

-(void)lostAllHope {
    postNotification("pls replace me");
    wantsQuit = true;
}

-(void)refresh {
    static CGPoint normalCenter = self.center;
    if(needsUIRefresh) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            bool useCustom = [[BBPreferenceManager currentManager] boolForKey:@"special xy treatment" withDefault:false];

            // Set position.
            static float lastXOffsetFraction = 0;
            static float lastYOffsetFraction = 0;

            float xOffsetFraction = useCustom ? ([[BBPreferenceManager currentManager] floatForKey:@"special x" withDefault:0] / 100.f) : 0;
            float yOffsetFraction = useCustom ? ([[BBPreferenceManager currentManager] floatForKey:@"special y" withDefault:0] / 100.f) : 0;

            if(lastXOffsetFraction != xOffsetFraction or lastYOffsetFraction != yOffsetFraction) {
                lastXOffsetFraction = xOffsetFraction;
                lastYOffsetFraction = yOffsetFraction;

                dispatch_async(dispatch_get_main_queue(), ^{
                    self.center = CGPointMake(normalCenter.x * (1.f + xOffsetFraction), normalCenter.y * (1.f + yOffsetFraction));
                });
            }
        });
    }

    if((not [self isAnyAudioPlaying]) or (self.hidden) or (self.alpha == 0)) {
        waitingForResponse = false;
        return;
    }

    if(waitingForResponse) return;

    waitingForResponse = true;
    [_ipccenter callExternalMethod:@selector(PCMAudioBuffer:) withArguments:@{} completion:^(NSData *data) {
        float *rawData = ([data length] > 0) ? const_cast<float *>(reinterpret_cast<const float *>([data bytes])) : nullptr;

        if(not rawData) return;

        [self handleData:rawData ofLength:[data length] / sizeof(float)];
        waitingForResponse = false;
    }];
}

static float *precalculatedTrig = nullptr;

-(void)dealloc {
    if(precalculatedTrig) delete[] precalculatedTrig;
}

-(void)handleData:(float *)data ofLength:(int)length {
    // os_log(OS_LOG_DEFAULT, "[BB] length is %d", length);

    static float *fftOut = new float[length / 2];

    static int knownLength = length;
    if(length != knownLength) {
        updatePlease = true;
        delete[] fftOut;
        fftOut = new float[(knownLength = length) / 2];

        knownLength = length;
    }

    if(isComingBack) {
        [self growBack];
        isComingBack = false;
    }

    // If we're receiving data, there's nothing wrong.
    unansweredRequests = 0;

    //const int pointCount = 50;

    static vis_state_info _stateInfo = vis_state_info(self.pointCount);
    static int staticPointCount = self.pointCount;
    static float &referenceMax = _stateInfo.referenceMax;
    static float &unmodifiedMax = _stateInfo.unmodifiedMax;

    static float &maxSinceLastUpdate = _stateInfo.maxSinceLastUpdate;
    static int &noUpdateCounter = _stateInfo.noUpdateCounter;

    //[512];

    static auto &lastMultipliers = _stateInfo.lastMultipliers;
    static auto &perRangePeaks = _stateInfo.perRangePeaks;

    CGPoint center = { self.frame.size.width / 2.f, self.frame.size.height / 2.f };

    if(needsUIRefresh) {
        [self initLayer];
        needsUIRefresh = false;
    }

    //static float precalculatedTrig[pointCount * 2];
    if(not precalculatedTrig) {
        precalculatedTrig = new float[staticPointCount * 2];

        for(int i = 0; i < staticPointCount; ++i) {
            float deg = ((360.f / float(staticPointCount)) * float(i)) - 90;
            float rad = deg * M_PI / 180.f;

            precalculatedTrig[i * 2] = std::cos(rad);
            precalculatedTrig[i * 2 + 1] = std::sin(rad);
        }
    }

    static bool &nsr = self->_needsStateReset;

    CGRect thisFrame = self.frame;
    float expansionLimit = (std::min(thisFrame.size.width, thisFrame.size.height) / 2.f) * 0.95f;

    // Lower framerates stop the lerped values reaching their eventual targets, so we need to make up for this fact.
    static float velocityMultiplier = 1.f - std::min(circleLayer.targetFPS / 60.f, 1.f);//bool shouldLerp = circleLayer.targetFPS >= 40.f;

    static BBPreferenceManager *mgr = [BBPreferenceManager currentManager];
    static bool bounceAllowed = true;
    static float bounceAttackMultiplier = 1.f;
    static float bounceDecayMultiplier = 1.f;
    static float attackMultiplier = 1.f;
    static float decayMultiplier = 1.f;
    static int peakUpdateFrequency = 6;
    static float peakHighlightMultiplier = 1.f;
    static float totalFrequencyRange = 68.f;
    static int framerate = 25;
    static bool smoothPath = true;
    static bool extraSplodge = false;
    static float baseRadiusFraction = 35.f;

//ExtraSplodge Technology
    if(needsPrefReload) {
        smoothPath = [mgr boolForKey:@"smooth dat path" withDefault:true];

        bounceAllowed = [mgr boolForKey:@"bounceallowed" withDefault:true];
        bounceAttackMultiplier = [mgr floatForKey:@"bounceattackmultiplier" withDefault:1.f];
        bounceDecayMultiplier = [mgr floatForKey:@"bouncedecaymultiplier" withDefault:1.f];

        attackMultiplier = [mgr floatForKey:@"attackmultiplier" withDefault:1.f];
        decayMultiplier = [mgr floatForKey:@"decaymultiplier" withDefault:1.f];

        peakUpdateFrequency = [mgr intForKey:@"peakupdatefrequency" withDefault:6];
        peakHighlightMultiplier = [mgr floatForKey:@"peakhighlightmultiplier" withDefault:1.f];

        totalFrequencyRange = [mgr floatForKey:@"totalfrequencyrange" withDefault:68.f];
        framerate = [mgr intForKey:@"framerate" withDefault:25];

        extraSplodge = [mgr boolForKey:@"ExtraSplodge Technology" withDefault:false];
        baseRadiusFraction = [mgr floatForKey:@"base radius fraction" withDefault:35.f];

        self.rawMultiplier = [mgr floatForKey:@"oi turn it up" withDefault:1.f];

        _link.preferredFramesPerSecond = framerate;
        self.targetFPS = framerate;
        self.peakLowerFrequency = peakUpdateFrequency;

        needsPrefReload = false;
    }

#pragma mark Action

    --unansweredRequests;

        //os_log(OS_LOG_DEFAULT, "[BB] ===================================");
    if(updatePlease) {
        _stateInfo.reset();
        updatePlease = false;
        NSLog(@"[BB] reset state data");
        os_log(OS_LOG_DEFAULT, "[BB] RSDe!");
        std::cout << "[BB] eeee\n";
    }


    //os_log(OS_LOG_DEFAULT, "[BB] FFT");

    if(not extractFrequencyMagnitudes(data, length / 2, fftOut, length / 2)) {
        return;
    }

    int endOffset = std::round((totalFrequencyRange / 100.f) * float(length / 2));
    std::vector<float> inVec(fftOut, fftOut + endOffset);
    std::vector<float> outVec;

    //os_log(OS_LOG_DEFAULT, "[BB] Quantising");
    quantize(inVec, outVec, staticPointCount);

    //os_log(OS_LOG_DEFAULT, "[BB] Pre-path");
    float thisMax = *std::max_element(outVec.begin(), outVec.end());
    referenceMax = std::max(thisMax, referenceMax);
    unmodifiedMax = std::max(thisMax, unmodifiedMax);

    maxSinceLastUpdate = std::max(thisMax, maxSinceLastUpdate);

    bool shouldUpdate = noUpdateCounter++ == peakUpdateFrequency;
    if(shouldUpdate) {
        referenceMax = (referenceMax + maxSinceLastUpdate * 2) / 3.f;
        maxSinceLastUpdate = FLT_MIN;
        noUpdateCounter = 0;
    }

    //os_log(OS_LOG_DEFAULT, "[BB] Init path");
    __block UIBezierPath *path = [UIBezierPath bezierPath];

    //os_log(OS_LOG_DEFAULT, "[BB] Bounce");
    float baseRadius = (baseRadiusFraction / 100.f) * std::min(thisFrame.size.width, thisFrame.size.height);//110.f;
    static float lastBR = baseRadius;

    float unlerpedBR = std::min(baseRadius + 5.f * (thisMax / unmodifiedMax), baseRadius + 5.f);

    if(bounceAllowed) baseRadius = lerp(lastBR, unlerpedBR, unlerpedBR > lastBR ? std::min(1.f, 0.8f * bounceAttackMultiplier) : (0.6f * bounceDecayMultiplier));

    lastBR = baseRadius;

/*

    ***** WELCOME TO USELESS MATHS LAND *****

    Here you will find all sorts of clever-looking numerical operations,
    none of which have any real science behind them.

    My methods are very complex: if the circle doesn't look right, 
    add more magic numbers. As you can see, that happened a lot.

*/

    CGPoint firstPoint {};
    //            [path moveToPoint:{ center.x + baseRadius, center.y }];
    //os_log(OS_LOG_DEFAULT, "[BB] Start loop");
    for(int i = 0; i < staticPointCount; ++i) {
       // os_log(OS_LOG_DEFAULT, "[BB] Loop maths stuff %d", i);
        perRangePeaks[i] = std::max(perRangePeaks[i], outVec[i]);
        if(perRangePeaks[i] == 0) {
            os_log_error(OS_LOG_DEFAULT, "[BB] PRP[%d] == 0", i);
        }

        bool didRestrictPeakHeight = false;
        if(shouldUpdate) {
            if(outVec[i] >= (1.4f * perRangePeaks[i])) {
                didRestrictPeakHeight = true;

                // Don't make the peak too high, because we can expect a drop in volume after this.
                perRangePeaks[i] - (perRangePeaks[i] * 2.f + outVec[i]) / 3.f;
            } else {
                perRangePeaks[i] = (perRangePeaks[i] + outVec[i]) / 2.f;
            }
        }

        //os_log(OS_LOG_DEFAULT, "[BB]    A");
        float frequencyRelative = float(i) / float(staticPointCount);
        float multiplier = 1.f + (outVec[i] / (perRangePeaks[i] + referenceMax / 100) * 0.7f * ((.8f * (0.5f + frequencyRelative)) + frequencyRelative));

        float basicMul = 1.3f * peakHighlightMultiplier;
        if(i > 0 and outVec[i] > perRangePeaks[i] and outVec[i - 1] <= perRangePeaks[i - 1]) {
            // Increase multiplier so this point stands out.
            multiplier *= basicMul;
            if(i < staticPointCount - 1) {
                lastMultipliers[i + 1] *= (.85f * basicMul);
            }
        } else {
            multiplier *= .692f * basicMul;
        }

        //os_log(OS_LOG_DEFAULT, "[BB]    B");
        float lastMultiplier = lastMultipliers[i];

        static float maxAllowedMultiplier = expansionLimit / baseRadius;

        if(lastMultipliers[i] > 0.f) multiplier = (2 * (extraSplodge ? multiplier : std::min(multiplier, maxAllowedMultiplier)) + lastMultipliers[i]) / 3.f;
        float attackLerpFactor = .7f * (1.f - (lastMultiplier / maxAllowedMultiplier));
        if(didRestrictPeakHeight) {
            attackLerpFactor *= 0.7f;
        }

        // Fast attack, slow(er) decay.
        float lerped = lerp(lastMultiplier, multiplier, multiplier > lastMultiplier ? std::min(1.f, clamp(velocityMultiplier * 1.5f, .7f, 1.f) * attackMultiplier) : (.3f * decayMultiplier));

        // We don't want the circle smaller than it should be.
        float modifiedRadius = std::max(lerped * baseRadius, baseRadius);
        static float maxAllowedRadius = expansionLimit;

        if(i == 0) modifiedRadius = std::max(baseRadius * ((lastMultipliers[1] + lastMultipliers[staticPointCount - 1]) / 2.f), baseRadius);

        // Work out the point given the modified radius and centre of the circle.
        CGPoint p { center.x + (modifiedRadius * precalculatedTrig[i * 2]), center.y + (modifiedRadius * precalculatedTrig[i * 2 + 1]) };

        if(not std::isfinite(p.x)) {
            p.x = center.x + (baseRadius * precalculatedTrig[i * 2]);
        }

        if(not std::isfinite(p.y)) {
            p.y = center.y + (baseRadius * precalculatedTrig[i * 2 + 1]);
        }

        // Fix broken points.
        // yeh lol duznt work
        if(not std::isfinite(p.x) or not std::isfinite(p.y)) {
            if(not std::isfinite(perRangePeaks[i])) {
                perRangePeaks[i] = outVec[i];
            }

            lerped = lastMultipliers[(i > 0) ? (i - 1) : (i + 1)];
            modifiedRadius = std::max(lerped * baseRadius, baseRadius);

            p.x = center.x + (modifiedRadius * precalculatedTrig[i * 2]);
            p.y = center.y + (modifiedRadius * precalculatedTrig[i * 2 + 1]);
        }

        if(i == 0) {
            firstPoint = p;
            //os_log(OS_LOG_DEFAULT, "[BB]    F1");
            [path moveToPoint:p];
            continue;
        }

        //os_log(OS_LOG_DEFAULT, "[BB]    F2 (%f, %f)", p.x, p.y);
        [path addLineToPoint:p];

        lastMultipliers[i] = lerped;
    }

    //[path addLineToPoint:firstPoint];

    dispatch_async(dispatch_get_main_queue(), ^{
        [path closePath];
        //float beforeMem = mem_usage_mib();
        if(smoothPath) {
            path = [path properSmoothedPath:7];
            path.flatness = 0.f;
        }

        //float afterMem = mem_usage_mib();
        //totalMemChange += (afterMem - beforeMem);

        //os_log(OS_LOG_DEFAULT, "[BB] path smoothing responsible for %f of memory", totalMemChange);

        CGPathRef cgp = [path CGPath];
        if(not cgp) {
            os_log(OS_LOG_DEFAULT, "[BB] no CGPath!");
        } else {
            try {
                //os_log(OS_LOG_DEFAULT, "[BB] before copy");
                var cgpath = CGPathCreateCopy(cgp);
                [circleLayer setPath:cgpath];
                CGPathRelease(cgpath);
                //os_log(OS_LOG_DEFAULT, "[BB] after copy");
            } catch (std::exception &e) {
                os_log(OS_LOG_DEFAULT, "[BB] f1");
            } catch(...) {
                os_log(OS_LOG_DEFAULT, "[BB] fucc");
            }
        }
        //CGPathRelease(cgp);

        [circleLayer setStrokeColor:self.ringColor ? (self.ringColor.CGColor) : ([UIColor redColor].CGColor)];
        if(self.fillCircle) {
            [circleLayer setFillColor:[circleLayer strokeColor]];
        }
    });

    //safeToRemove = true;
    //postNotification("safe to remove");

    //if(quitNow) {
    //    os_log(OS_LOG_DEFAULT, "[BB] safe now");
    //}

    //currentlyProcessing = false;

    if(self.alpha != 0.f and isGoingAfterComplete) {
        _link.paused = true;
        [self shrinkAway];
    }

    isGoingAfterComplete = false;
}

-(void)setup {
    [self configureDisplayLink];

    //[self connect];
}

-(void)removeFromSuperview {
    [super removeFromSuperview];
}

//-(void)resetVisStateInfo {
//    _stateInfo.reset();
//}

@end

#import <mach/mach.h>

void report_memory(void) {
  struct task_basic_info info;
  mach_msg_type_number_t size = TASK_BASIC_INFO_COUNT;
  kern_return_t kerr = task_info(mach_task_self(),
                                 TASK_BASIC_INFO,
                                 (task_info_t)&info,
                                 &size);
  if(kerr == KERN_SUCCESS) {
    os_log(OS_LOG_DEFAULT, "[BB] Memory in use (in bytes): %lu", info.resident_size);
    os_log(OS_LOG_DEFAULT, "[BB] Memory in use (in MiB): %f", ((CGFloat)info.resident_size / 1048576));
  } else {
    os_log(OS_LOG_DEFAULT, "[BB] Error with task_info(): %s", mach_error_string(kerr));
  }
}

@interface MRPlatterViewController : UIViewController
@property (nonatomic, retain) SQSpikyVisualizerView *vis;
@property (nonatomic,readonly) UIView *effectiveHeaderView;
@end

%group WithColorFlow

%hook MRPlatterViewController
%property (nonatomic, retain) SQSpikyVisualizerView *vis;

-(void)viewDidAppear:(BOOL)animated {
    %orig;

    UIColor *color = [self valueForKeyPath:@"volumeContainerView.volumeSlider.minimumTrackTintColor"];
    UIImageView *artworkView = [self valueForKeyPath:@"effectiveHeaderView.placeholderArtworkView"];

    if(not self.vis) {
        if(artworkView) {
            self.vis = [[SQSpikyVisualizerView alloc] initWithFrame:artworkView.frame];
            self.vis.colorTarget = self;
            self.vis.colorSelector = @selector(ringColor);
            if(color) self.vis.ringColor = color;
            [self.effectiveHeaderView addSubview:self.vis];

            [self.vis setup];
        }
    }

    os_log(OS_LOG_DEFAULT, "[BB] hi");
    self.vis->_link.paused = false;
}

%new
-(UIColor *)ringColor {
    UIColor *color = [self valueForKeyPath:@"volumeContainerView.volumeSlider.minimumTrackTintColor"];
    if(not color) return [UIColor whiteColor];

    if([foregroundColor(color) isEqual:[UIColor blackColor]]) {
        return [color darkerColor];
    }
    return [color lighterColor];
}

-(void)viewDidDisappear:(BOOL)animated {
    %orig;

    os_log(OS_LOG_DEFAULT, "[BB] bye");
    self.vis->_link.paused = true;
}

-(void)cfw_colorize:(id)s {
    %orig;

    if(self.vis) {
        UIColor *color = [self valueForKeyPath:@"volumeContainerView.volumeSlider.minimumTrackTintColor"];
        //if(color) self.vis.ringColor = color;
    }
}

-(void)viewDidLayoutSubviews {
    %orig;

    static UIColor *lastColor = nullptr;
    if(self.vis) {
        self.vis->_link.paused = false;

        UIColor *color = [self valueForKeyPath:@"volumeContainerView.volumeSlider.minimumTrackTintColor"];
        if(color) {
            self.vis.ringColor = [self performSelector:@selector(ringColor)];

            if(lastColor and not [color isEqual:lastColor]) {
                updatePlease = true;
            }
        }
    }

    UIImageView *artworkView = [self valueForKeyPath:@"effectiveHeaderView.artworkView"];
    if(artworkView) {
        artworkView.alpha = 0.5f;
    }

    lastColor = self.vis.ringColor;
}

%end
%end

static bool CF5ColoringLS = false;

@interface CSMediaControlsViewController : UIViewController
@property (nonatomic, retain) SQSpikyVisualizerView *vis;
-(void)observeVisNotifications;
@end

%group StockSetup_iOS13

%hook CSMediaControlsViewController
%property (nonatomic, retain) SQSpikyVisualizerView *vis;

-(void)viewDidAppear:(BOOL)animated {
    %orig;

    if(not self.vis and [self.view.subviews count]) {
        self.vis = [[SQSpikyVisualizerView alloc] initWithFrame:self.view.subviews[0].frame];
        self.vis.colorTarget = self;
        self.vis.colorSelector = @selector(ringColor);
        [self.view insertSubview:self.vis atIndex:0];
        [self.vis setup];


    } else if(self.vis) {
        [self.vis connect];
    }

    self.vis->_link.paused = false;
}

%new
-(UIColor *)ringColor {
    UIColor *color = [self valueForKeyPath:!CF5ColoringLS ? @"_platterViewController.volumeContainerView.volumeSlider.minimumTrackTintColor"
                                                             : @"_platterViewController.volumeContainerView.volumeSlider.maximumTrackTintColor"];
    if(not color) return [UIColor whiteColor];

    if([foregroundColor(color) isEqual:[UIColor blackColor]]) {
        return [color darkerColor];
    }
    return [color lighterColor];
}

%new
-(void)observeVisNotifications {
    addObserver(self, "pls replace me", @selector(replaceVisualizer:));
}

%new
-(void)replaceVisualizer:(NSNotification *)notif {
    os_log(OS_LOG_DEFAULT, "[BB] conn died");

    [self.vis disconnect];
    [self.vis connect];
    unansweredRequests = 0;
}

-(void)viewDidDisappear:(BOOL)animated {
    %orig;

    self.vis->_link.paused = true;
    [self.vis disconnect];
}


-(void)viewDidLayoutSubviews {
    %orig;

    static UIColor *lastColor = nullptr;
    if(self.vis) {
        UIColor *color = [[BBPreferenceManager currentManager] colorForKey:@"defaultcolour" withDefault:[UIColor colorWithWhite:0.8f alpha:1.f]];

        if(color) {
            self.vis->_link.paused = false;

            if(lastColor and not [color isEqual:lastColor]) {
                updatePlease = true;
            }
        }

        lastColor = color;
    }
}

%end

%end

@interface MMArtworkView : UIView
@end

@interface MMScrollView : UIView
@property (nonatomic, retain) SQSpikyVisualizerView *vis;
-(void)observeVisNotifications;
-(UIView *)artworkViewForCurrentSong;
@end

@interface MMServer : NSObject
@property (nonatomic, readonly) NSArray *queue;
@property (nonatomic, retain) NSString *currentSongTitle;
@property (nonatomic, readonly) dispatch_queue_t musicQueue;
@property (nonatomic, readonly) NSDictionary *nowPlayingInfo;

+(instancetype)sharedInstance;
-(NSUInteger)findIndexOfSong:(NSString*)songTitle found:(BOOL *)found;
-(NSUInteger)findIndexOfSong:(NSString*)songTitle inQueue:(NSArray<NSDictionary *> *)queue found:(BOOL *)found;
@end

%group WithFlow

static bool forceReloadColor = true;

%hook MMScrollView
%property (nonatomic, retain) SQSpikyVisualizerView *vis;

%new
-(UIView *)artworkViewForCurrentSong {
    @try {
        var server = [%c(MMServer) sharedInstance];
        NSString *songTitle = [server currentSongTitle];
        if(not songTitle) {
            // Not playing.
            return nullptr;
        }

        bool found = false;
        var index = [server findIndexOfSong:songTitle found:&found];

        if(not found) {
            // tf?
            return nullptr;
        }

        UIView *theView = ((NSArray *)([self valueForKey:@"_artworkViews"]))[index];
        if(index > 0 and not [[theView valueForKey:@"songTitle"] isEqualToString:songTitle]) {
            return ((NSArray *)([self valueForKey:@"_artworkViews"]))[index - 1];
        }

        return theView;
    } @catch(NSException *e) {
        return nullptr;
    }
}

-(void)updateArtworks {
    %orig;

    if(self.vis) self.vis.layer.zPosition = 1.f;

    UIView *artworkView = [self artworkViewForCurrentSong];
    UIImageView *imageView = artworkView ? [artworkView valueForKey:@"_imgView"] : nullptr;

    static NSString *lastTitle = @"";
    if(imageView and self.vis) {
        if(![[artworkView valueForKey:@"songTitle"] isEqualToString:lastTitle]) {
            forceReloadColor = true;
        }
    }
}

%new
-(UIColor *)ringColor {
    static UIColor *lastColor = nullptr;
    if(forceReloadColor or not lastColor) {
        forceReloadColor = false;

        UIView *artworkView = [self artworkViewForCurrentSong];
        UIImageView *imageView = artworkView ? [artworkView valueForKey:@"_imgView"] : nullptr;
        if(not imageView) return [UIColor whiteColor];
        UIImage *img = imageView.image;
        return lastColor = dominantColor(img, 10, percent(5), true);
    }

    return lastColor;
}

-(void)layoutSubviews {
    %orig;

    if(not self.vis) {
        // The MMScrollView's height is the same as the height of the large artwork view.
        // Since the large artwork view is square, we can just use the height to work out the dimensions.
        // This way we don't actually need to find the artwork view.
        CGRect visualizerFrame = CGRectMake(0, 0, self.frame.size.height, self.frame.size.height);
        CGPoint visualizerCenter { self.frame.size.width / 2.f, self.frame.size.height / 2.f };

        self.vis = [[SQSpikyVisualizerView alloc] initWithFrame:visualizerFrame];
        self.vis.ringColor = [[BBPreferenceManager currentManager] colorForKey:@"defaultcolour" withDefault:[UIColor colorWithWhite:0.8f alpha:1.f]];
        self.vis.center = visualizerCenter;
        self.vis.userInteractionEnabled = false;
        self.vis.backgroundColor = [UIColor colorWithWhite:0.f alpha:0.2f];
        self.vis.colorTarget = self;
            self.vis.colorSelector = @selector(ringColor);
        [self.vis setup];
        self.vis.layer.zPosition = 1.f;

        //[self observeVisNotifications];

        [self addSubview:self.vis];
    }

    self.vis.layer.zPosition = 1.f;
    [self bringSubviewToFront:self.vis];
}

-(void)removeFromSuperview {
    %orig;

    self.vis->_link.paused = true;
    [self.vis disconnect];
}

%end

%end

%group StockSetup_iOS12_Maybe_Below

/*

The class of the view controller we need to hook seems to vary between iOS versions,
but is probably the only child view controller of SBDashBoardMediaControlsViewController
on all iOS versions (below 13). Let's try this then.

*/

@interface SBDashBoardMediaControlsViewController : UIViewController
@property (nonatomic, retain) SQSpikyVisualizerView *vis;
@end

%hook SBDashBoardMediaControlsViewController
%property (nonatomic, retain) SQSpikyVisualizerView *vis;

-(void)viewDidLoad {
    %orig;

    if([[self childViewControllers] count] > 0) {
        UIViewController *targetVC = [self childViewControllers][0];
        UIView *targetView = [targetVC viewIfLoaded];

        if(not targetView) return;

        if(not self.vis) {
            CGRect visualizerFrame = CGRectMake(0, 0, targetView.frame.size.height, targetView.frame.size.height);
            CGPoint visualizerCenter { targetView.frame.size.width / 2.f, targetView.frame.size.height / 2.f };

            self.vis = [[SQSpikyVisualizerView alloc] initWithFrame:visualizerFrame];
            self.vis.ringColor = [[BBPreferenceManager currentManager] colorForKey:@"defaultcolour" withDefault:[UIColor colorWithWhite:0.8f alpha:1.f]];//[UIColor colorWithWhite:.8f alpha:1.f];
            self.vis.center = visualizerCenter;
            self.vis.colorTarget = self;
            self.vis.colorSelector = @selector(ringColor);
            [self.vis setup];

            [targetView insertSubview:self.vis atIndex:0];
        }
    }
}

%new
-(UIColor *)ringColor {
    UIColor *color = [self valueForKeyPath:!CF5ColoringLS ? @"_platterViewController.volumeContainerView.volumeSlider.minimumTrackTintColor"
                                                             : @"_platterViewController.volumeContainerView.volumeSlider.maximumTrackTintColor"];//[self valueForKeyPath:@"_platterViewController.volumeContainerView.volumeSlider.maximumTrackTintColor"];
    if(not color) return [UIColor whiteColor];

    if([foregroundColor(color) isEqual:[UIColor blackColor]]) {
        return [color darkerColor];
    }
    return [color lighterColor];
}

// All iOS versions seem to have _layoutMediaControls
-(void)_layoutMediaControls {
    %orig;

    if([[self childViewControllers] count] > 0) {
        UIViewController *targetVC = [self childViewControllers][0];
        UIView *targetView = [targetVC viewIfLoaded];

        if(not targetView) return;

        if(not self.vis) {
            CGRect visualizerFrame = CGRectMake(0, 0, targetView.frame.size.height, targetView.frame.size.height);
            CGPoint visualizerCenter { targetView.frame.size.width / 2.f, targetView.frame.size.height / 2.f };

            self.vis = [[SQSpikyVisualizerView alloc] initWithFrame:visualizerFrame];
            self.vis.ringColor = [UIColor colorWithWhite:.8f alpha:1.f];
            self.vis.center = visualizerCenter;
            [self.vis setup];

            [targetView insertSubview:self.vis atIndex:0];
        } else {
            CGRect visualizerFrame = CGRectMake(0, 0, targetView.frame.size.height, targetView.frame.size.height);
            CGPoint visualizerCenter { targetView.frame.size.width / 2.f, targetView.frame.size.height / 2.f };

            self.vis.frame = visualizerFrame;
            self.vis.center = visualizerCenter;
        }
    }


}

%end

%end

%group NSNCHook
%hook NSNotificationCenter

- (void)postNotification:(NSNotification *)notification {
    os_log(OS_LOG_DEFAULT, "[BB] [NSNC] %{public}s\n%{public}s", [[notification name] UTF8String], [[notification description] UTF8String]);
    %orig;
}

// luv dat formatting
- (void)postNotificationName:(NSNotificationName)aName
                      object:(id)anObject
                    userInfo:(NSDictionary *)aUserInfo {
                        os_log(OS_LOG_DEFAULT, "[BB] [NSNC] %{public}s\t\t{ %{public}s }", [aName UTF8String], aUserInfo ? [[aUserInfo description] UTF8String] : "no user info");
    %orig;
                    }

%end
%end

%group BackgroundTing

@interface BGTTargetView : UIView
@property (nonatomic, retain) SQSpikyVisualizerView *vis;
@property (nonatomic, retain) UIView *backgroundView;
@end

%hook BGTTargetView
%property (nonatomic, retain) SQSpikyVisualizerView *vis;

-(void)layoutSubviews {
    %orig;

// muireeyyyyy
#define self ((BGTTargetView *)self)

    if(not self.vis) {
        CGRect visualizerFrame = self.backgroundView.frame;
        CGPoint visualizerCenter { self.backgroundView.frame.size.width / 2.f, self.backgroundView.frame.size.height / 2.f };

        self.vis = [[SQSpikyVisualizerView alloc] initWithFrame:visualizerFrame];
        self.vis.isOnLSBackground = true;
        self.vis.ringColor = [[BBPreferenceManager currentManager] colorForKey:@"defaultcolour" withDefault:[UIColor colorWithWhite:0.8f alpha:1.f]];
        self.vis.center = visualizerCenter;
        self.vis.userInteractionEnabled = false;

        [self.vis setup];

        [self.backgroundView addSubview:self.vis];
    }

#undef self
}

%end

%end

static void reloadPrefs() {
    [[BBPreferenceManager currentManager] reloadWithPath:@"/var/mobile/Library/Preferences/com.squ1dd13.bb_pref_ting.plist"];

    // We don't really reload anything here, we just tell the circle to.
    needsUIRefresh = true;
    needsPrefReload = true;
}

Class coverSheetClass() {
    return %c(SBDashBoardView) ?: %c(CSCoverSheetView);
}

#include "funcs.hpp"

#import <dlfcn.h>

void runCommand_(NSString *command) {
    NSTask *task = [[NSTask alloc] init];

    [task setLaunchPath:@"/bin/bash"];
    [task setArguments:@[@"-c", command]];
    [task launch];
    [task waitUntilExit];
}

long fsize(const std::string &path) {
    struct stat stat_buf;
    int rc = stat(path.c_str(), &stat_buf);
    return rc == 0 ? stat_buf.st_size : -1;
}

%ctor {
    NSString *processName = [[NSProcessInfo processInfo] processName];

    os_log(OS_LOG_DEFAULT, "[BB] now in %{public}s", [[[NSBundle mainBundle] bundleIdentifier] UTF8String]);

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), nil, (CFNotificationCallback)reloadPrefs, CFSTR("com.squ1dd13.bb_pref_ting.prefschanged"), NULL, CFNotificationSuspensionBehaviorDrop);
    if(false) %init(NSNCHook);
    
    if([processName isEqualToString:@"mediaserverd"]) {
        // Only the server should load.
        os_log(OS_LOG_DEFAULT, "[BB] main tweak leaving mediaserverd");
        return;
    } else if(not [processName isEqualToString:@"SpringBoard"]) {
        return;
    }

    static BBPreferenceManager *settingsManager = [BBPreferenceManager managerWithPlist:@"/var/mobile/Library/Preferences/com.squ1dd13.bb_pref_ting.plist"];
    [BBPreferenceManager setCurrentManager:settingsManager];

    reloadPrefs();

    if(not [[BBPreferenceManager currentManager] boolForKey:@"tweakEnabled" withDefault:true]) {
        return;
    }

    %init(_ungrouped);

    automaticPause = not [[BBPreferenceManager currentManager] boolForKey:@"fix frezz" withDefault:false];

    if([[BBPreferenceManager currentManager] boolForKey:@"background ting" withDefault:false]) {
        %init(BackgroundTing, BGTTargetView = coverSheetClass());
        return;
    }

    bool flowFound = [[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/Flow.dylib"]
                  && [[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/Flow.plist"];

    if(flowFound) {
        NSError *flowPrefErr;
        NSDictionary *flowPrefs = [NSDictionary dictionaryWithContentsOfURL:[NSURL fileURLWithPath:@"/var/mobile/Library/Preferences/com.muirey03.flow.plist"] error:&flowPrefErr];

        if(flowPrefs and not flowPrefErr) {
            var enabled = flowPrefs[@"enabled"];

            if(enabled and [enabled boolValue]) {
                flowFound = true;
            } else {
                flowFound = false;
            }
        }
    }

    // CF is a fucking pain
    bool colorFlow5Found = [[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/ColorFlow5.dylib"]
                        && [[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/ColorFlow5.plist"];

    if(flowFound) {
        // Load Flow first.
        void *dylib = dlopen("/Library/MobileSubstrate/DynamicLibraries/Flow.dylib", RTLD_LAZY | RTLD_GLOBAL);
        if (dylib == NULL) {
            os_log(OS_LOG_DEFAULT, "[BB] Failed with error: %s", dlerror());
        }

        os_log(OS_LOG_DEFAULT, "[BB] flow mode");

        %init(WithFlow);
        return;
    } else if(colorFlow5Found) {
        NSError *prefErr;
        NSDictionary *CF5Prefs = [NSDictionary dictionaryWithContentsOfURL:[NSURL fileURLWithPath:@"/var/mobile/Library/Preferences/com.golddavid.colorflow5.plist"] error:&prefErr];

        var lsEnabled = CF5Prefs[@"LockScreenEnabled"];
        if(lsEnabled and [lsEnabled boolValue]) CF5ColoringLS = true;
        NSString *resizingMode = CF5Prefs[@"LockScreenResizingMode"];

        if(lsEnabled and [lsEnabled boolValue] and resizingMode and [resizingMode isEqualToString:@"FullScreen"]) {
            %init(WithColorFlow);
            return;
        }
    }

    os_log(OS_LOG_DEFAULT, "[BB] non-flow mode");

    // Flow not loaded.
    // Either this or check for UIActivityItemsConfiguration to find if iOS 13.
    if(NSClassFromString(@"UIActivityItemsConfiguration")) {
        %init(StockSetup_iOS13);
    } else {
        %init(StockSetup_iOS12_Maybe_Below);
    }
}
