//
//  SKMicrophone.m
//  SensingKit
//
//  Copyright (c) 2014. Queen Mary University of London
//  Kleomenis Katevas, k.katevas@qmul.ac.uk
//
//  This file is part of SensingKit-iOS library.
//  For more information, please visit http://www.sensingkit.org
//
//  SensingKit-iOS is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Lesser General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  SensingKit-iOS is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Lesser General Public License for more details.
//
//  You should have received a copy of the GNU Lesser General Public License
//  along with SensingKit-iOS.  If not, see <http://www.gnu.org/licenses/>.
//

#import "SKMicrophone.h"
@import AVFoundation;
#import "SKMicrophoneData.h"


@interface SKMicrophone () <AVAudioRecorderDelegate>

@property (nonatomic, strong) AVAudioRecorder *recorder;

@end


@implementation SKMicrophone

- (instancetype)initWithConfiguration:(SKMicrophoneConfiguration *)configuration
{
    if (self = [super init])
    {
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        
        NSError *error;
        [audioSession setCategory:AVAudioSessionCategoryRecord error:&error];
        
        if (error)
        {
            NSLog(@"Error: %@", error.localizedDescription);
        }
        
        [audioSession setActive:YES error:&error];
        
        if (error)
        {
            NSLog(@"Error: %@", error.localizedDescription);
        }
        
        // Request authorization. Only WhenInUse is required for proximity scanning.
        if ([audioSession respondsToSelector:@selector(requestRecordPermission:)])
        {
            [audioSession requestRecordPermission:^(BOOL granted) {
                if (!granted)
                {
                    NSLog(@"Permission for using Microphone sensor was not granted.");
                    // TODO: In the future, report this as NSError.
                }
            }];
        }
        
        self.configuration = configuration;
    }
    return self;
}

#pragma mark Configuration

- (void)setConfiguration:(SKConfiguration *)configuration
{
    // Check if the correct configuration type provided
    if (configuration.class != SKMicrophoneConfiguration.class)
    {
        NSLog(@"Wrong SKConfiguration class provided (%@) for sensor Microphone.", configuration.class);
        abort();
    }
    
    super.configuration = configuration;
    
    // Cast the configuration instance
    SKMicrophoneConfiguration *microphoneConfiguration = (SKMicrophoneConfiguration *)configuration;
    
    NSDictionary *recordSettings = [SKMicrophone recordingSettingsForConfiguration:microphoneConfiguration];
    
    NSError *error;
    self.recorder = [[AVAudioRecorder alloc] initWithURL:microphoneConfiguration.recordingPath
                                                settings:recordSettings
                                                   error:&error];
    
    if (error)
    {
        NSLog(@"Error: %@", error.localizedDescription);
    }
    
#if !TARGET_IPHONE_SIMULATOR
    if (![self.recorder prepareToRecord])
    {
        NSLog(@"Recording using Microphone sensor could not be initialized.");
        // TODO: In the future, report this as NSError.
    }
#endif
}

+ (NSDictionary *)recordingSettingsForConfiguration:(SKMicrophoneConfiguration *)configuration
{
    NSDictionary *recordingSettings;
    
    // Convert SKMicrophoneRecordingQuality to AVAudioQuality
    AVAudioQuality audioQuality = [SKMicrophone audioQualityForMicrophoneRecordingQuality:configuration.recordingQuality];
    
    switch (configuration.recordingFormat)
    {
        case SKMicrophoneRecordingFormatLinearPCM:
            recordingSettings = @{AVFormatIDKey: @(kAudioFormatLinearPCM),
                                  AVEncoderAudioQualityKey: @(audioQuality),
                                  AVNumberOfChannelsKey: @(1),
                                  AVSampleRateKey:@(configuration.sampleRate),
                                  AVLinearPCMBitDepthKey: @(16),
                                  AVLinearPCMIsBigEndianKey: @(NO),
                                  AVLinearPCMIsFloatKey: @(NO)};
            break;
    
        case SKMicrophoneRecordingFormatMPEG4AAC:
            recordingSettings = @{AVFormatIDKey: @(kAudioFormatMPEG4AAC),
                                  AVEncoderAudioQualityKey: @(audioQuality),
                                  AVNumberOfChannelsKey: @(1),
                                  AVSampleRateKey:@(configuration.sampleRate)};
            break;
            
        default:
            NSLog(@"Unknown SKMicrophoneRecordingFormat: %lu", (unsigned long)configuration.recordingFormat);
            abort();
    }
    
    return recordingSettings;
}

+ (AVAudioQuality)audioQualityForMicrophoneRecordingQuality:(SKMicrophoneRecordingQuality)microphoneRecordingQuality
{
    switch (microphoneRecordingQuality)
    {
        case SKMicrophoneRecordingQualityMin:
            return AVAudioQualityMin;
            
        case SKMicrophoneRecordingQualityLow:
            return AVAudioQualityLow;
            
        case SKMicrophoneRecordingQualityMedium:
            return AVAudioQualityMedium;
            
        case SKMicrophoneRecordingQualityHigh:
            return AVAudioQualityHigh;
            
        case SKMicrophoneRecordingQualityMax:
            return AVAudioQualityMax;
            
        default:
            NSLog(@"Unknown SKMicrophoneRecordingQuality: %lu", (unsigned long)microphoneRecordingQuality);
            abort();
    }
}

#pragma mark Sensing

+ (BOOL)isSensorAvailable
{
    // Always available
    return YES;
}

- (void)startSensing
{
    [super startSensing];
    
    // Start recording (maximum 4 hours)
    if (![self.recorder recordForDuration:14400])
    {
        NSLog(@"Recording using Microphone sensor could not be started.");
        // TODO: In the future, report this as NSError.
    }
    else
    {
        NSTimeInterval startTime = [NSProcessInfo processInfo].systemUptime;
        
        SKMicrophoneData *data = [[SKMicrophoneData alloc] initWithState:@"Started" withTimeInterval:startTime];
        [self submitSensorData:data];
    }
}

- (void)stopSensing
{
    // Stop recording
    if (self.recorder.recording)
    {
        // Pause instead of stop, in order to continue on the same file.
        [self.recorder pause];
        
        NSTimeInterval endTime = [NSProcessInfo processInfo].systemUptime;
        
        SKMicrophoneData *data = [[SKMicrophoneData alloc] initWithState:@"Stopped" withTimeInterval:endTime];
        [self submitSensorData:data];
    }
    
    [super stopSensing];
}

- (void)dealloc
{
    // Stop recording on dealloc
    if (self.recorder.recording)
    {
        [self.recorder stop];
    }
}

@end
