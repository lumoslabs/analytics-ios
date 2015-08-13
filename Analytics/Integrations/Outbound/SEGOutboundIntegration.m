//
//  SEGOutboundIntegration.m
//  Analytics
//
//  Created by Dhruv Mehta on 8/12/15.
//  Copyright (c) 2015 Segment.io. All rights reserved.
//

#import "SEGOutboundIntegration.h"
#import <Outbound/Outbound.h>
#import "SEGAnalytics.h"
#import "SEGAnalyticsUtils.h"

@implementation SEGOutboundIntegration

+ (void)load
{
  [SEGAnalytics registerIntegration:self withIdentifier:@"Outbound"];
}

- (id)init
{
  if (self = [super init]) {
    self.name = @"Outbound";
    self.valid = NO;
    self.initialized = NO;
  }
  return self;
}

- (void)start
{
  NSString *apiKey = [self.settings objectForKey:@"apiKey"];
  [Outbound initWithPrivateKey:apiKey];
  SEGLog(@"OutboundIntegration initialized.");
  self.initialized = YES;
  [super start];
}

- (void) validate
{
  BOOL hasAPIKey = [self.settings objectForKey:@"apiKey"] != nil;
  self.valid = hasAPIKey;
}

- (void)identify:(NSString *)userId traits:(NSDictionary *)traits options:(NSDictionary *)options
{
  NSMutableDictionary* attrs = [[NSMutableDictionary alloc] init];
  NSMutableDictionary* customAttrs = [[NSMutableDictionary alloc] init];
  
  for (NSString* key in traits) {
    id value = [traits objectForKey:key];
    if ([key isEqualToString:@"first_name"] || [key isEqualToString:@"firstName"]){
      [attrs setObject:value forKey:@"first_name"];
    } else if ([key isEqualToString:@"last_name"] || [key isEqualToString:@"lastName"]){
      [attrs setObject:value forKey:@"last_name"];
    } else if ([key isEqualToString:@"name"]){
      NSString* name = (NSString*) value;
      [attrs setObject:[name componentsSeparatedByString:@" "][0] forKey:@"first_name"];
      [attrs setObject:[name componentsSeparatedByString:@" "][1] forKey:@"last_name"];
    } else if ([key isEqualToString:@"email"]){
      [attrs setObject:value forKey:@"email"];
    } else if ([key isEqualToString:@"phone"]){
      // TODO(Dhruv): Update http://docs.outbound.io/v2/docs/ios phone_number part.
      [attrs setObject:value forKey:@"phone_number"];
    } else {
      [customAttrs setObject:value forKey:key];
    }
  }
  
  // TODO(Dhruv): How do I handle anonymous ids? We need to know if it is anonymous.
  [attrs setObject:customAttrs forKey:@"attributes"];
  
  [Outbound identifyUserWithId:userId attributes:attrs];
}

- (void) track:(NSString *)event properties:(NSDictionary *)properties options:(NSDictionary *)options
{
  [Outbound trackEvent:event withProperties:properties];
}

- (void)screen:(NSString *)screenTitle properties:(NSDictionary *)properties options:(NSDictionary *)options
{
  [Outbound trackEvent:SEGEventNameForScreenTitle(screenTitle) withProperties:properties];
}

- (void) alias:(NSString *)newId options:(NSDictionary *)options
{
  // TODO(Dhruv): We are going to need to implement this once you understand
  // how anonymousId can be accessed
}

- (void) registerForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken options:(NSDictionary *)options
{
  [Outbound registerDeviceToken:deviceToken];
}

- (void) reset
{
  [Outbound logout];
}

// TODO(Dhruv): If I don't handle group() here, will it be syndicated from the server?
@end