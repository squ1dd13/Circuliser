#import <AudioToolbox/AudioToolbox.h>
#import <arpa/inet.h>
#import <sys/time.h>
#include <sys/types.h>
#include <unistd.h>
#include <Foundation/Foundation.h>
#import <MRYIPCCenter.h>
#include "funcs.hpp"
#include <mach/mach.h>
#include <sys/time.h>
#include <chrono>

struct cpu_util {
    template <typename A, typename B>
    static constexpr void time_value_to_timeval(A a, B r) {
        do {
            r->tv_sec = a->seconds;
            r->tv_usec = a->microseconds;
        } while(0);
    }
    
    static bool get_task_info(task_basic_info_64 *info) {
        mach_msg_type_number_t size = TASK_BASIC_INFO_64_COUNT;
        kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO_64, reinterpret_cast<task_info_t>(info), &size);

        return kerr == KERN_SUCCESS;
    }

    static mach_port_t task_from_pid(pid_t pid) {
        mach_port_t task_port;
        
        task_for_pid(mach_task_self(), pid, &task_port);
        return task_port;
    }
    
    static long long get_cpu_usage(pid_t pid) {
        task_thread_times_info thread_info_data;
        mach_msg_type_number_t thread_info_count = TASK_THREAD_TIMES_INFO_COUNT;
        kern_return_t kr = task_info(mach_task_self(), TASK_THREAD_TIMES_INFO, reinterpret_cast<task_info_t>(&thread_info_data), &thread_info_count);
        
        if(kr != KERN_SUCCESS) {
            return -2;
        }

        task_basic_info_64 task_info_data;
        if(not get_task_info(&task_info_data)) {
            return -3;
        }

        struct timeval user_timeval, system_timeval, task_timeval;
        time_value_to_timeval(&thread_info_data.user_time, &user_timeval);
        time_value_to_timeval(&thread_info_data.system_time, &system_timeval);
        timeradd(&user_timeval, &system_timeval, &task_timeval);
        
        time_value_to_timeval(&task_info_data.user_time, &user_timeval);
        time_value_to_timeval(&task_info_data.system_time, &system_timeval);
        timeradd(&user_timeval, &task_timeval, &task_timeval);
        timeradd(&system_timeval, &task_timeval, &task_timeval);
        
        return 1000000 * task_timeval.tv_sec + task_timeval.tv_usec;
    }
    
    static double get_cpu_percent(pid_t pid) {
        static long long last_cpu_usage = 0;
        static std::chrono::microseconds last_cpu_time;
        
        long long cumulative_cpu = get_cpu_usage(pid);
        os_log(OS_LOG_DEFAULT, "[BB] ccpu = %lld", cumulative_cpu);
        std::chrono::microseconds time = std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::system_clock::now().time_since_epoch());
        
        if (last_cpu_usage == 0) {
            // First call, so setup for subsequent ones.
            last_cpu_usage = cumulative_cpu;
            last_cpu_time = time;
            
            return -1;
        }
        
        long long system_time_delta = cumulative_cpu - last_cpu_usage;
        long long time_delta = (time - last_cpu_time).count();
        
        if(not time_delta) {
            return -1;
        }
        
        last_cpu_usage = cumulative_cpu;
        last_cpu_time = time;
        
        return 100.0 * float(system_time_delta) / double(time_delta);
    }
};
AudioBufferList *p_bufferlist = NULL;
float *empty = NULL;

%hookf(OSStatus, AudioUnitRender, AudioUnit unit, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inOutputBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {

    AudioComponentDescription unitDescription = {0};
    AudioComponentGetDescription(AudioComponentInstanceGetComponent(unit), &unitDescription);
    
    if(unitDescription.componentSubType == 'mcmx') {
        if (inNumberFrames > 0) {
            p_bufferlist = ioData;
        } else {
            p_bufferlist = NULL;
        }
    }

    return %orig;
}

@interface SQDiscoServer : NSObject
+(NSData *)PCMAudioBuffer:(NSDictionary *)dict;
@end

// disco time
// boots and cats and boots and cats and boots and cats and boots and cats and boots and cats and boots and cats and boots and cats and boots and cats and idiocy
@implementation SQDiscoServer

+(NSData *)PCMAudioBuffer:(NSDictionary *)dict {
    static std::chrono::milliseconds lastTime = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch());
    std::chrono::milliseconds time = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch());

    if((time - lastTime).count() >= 1000) {
        // >= 1 sec since last update.
        double cpu_percent = cpu_util::get_cpu_percent(getpid());
        if(cpu_percent != -1) {
            os_log(OS_LOG_DEFAULT, "[BB] mediaserverd cpu = %lf%%", cpu_percent);
        }

        lastTime = time;
    }

    float *data = NULL;
    size_t len = 0;

    if(p_bufferlist) {
        len = p_bufferlist->mBuffers[0].mDataByteSize;
        data = (float *)(p_bufferlist->mBuffers[0].mData);
    } else {
        return [NSData data];
    }

    return [NSData dataWithBytesNoCopy:data length:len freeWhenDone:false];
}

@end

static MRYIPCCenter *center;
void runServer() {
    os_log(OS_LOG_DEFAULT, "[BB] creating IPC server");
    center = [MRYIPCCenter centerNamed:[NSString stringWithFormat:@"squ1dd13's disco server %d", getpid()]];
    [center addTarget:[SQDiscoServer class] action:@selector(PCMAudioBuffer:)];
}

%ctor {
    NSString *processName = [[NSProcessInfo processInfo] processName];
    if(not [processName isEqualToString:@"mediaserverd"]) {
        os_log(OS_LOG_DEFAULT, "[BB] not mediaserverd!");
        return;
    }


    os_log(OS_LOG_DEFAULT, "[BB] mediaserverd");

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        runServer();
        sleep(0);
    });
    %init;
}

%dtor {
    os_log(OS_LOG_DEFAULT, "[BB] mediaserverd exiting, server being unloaded");
}