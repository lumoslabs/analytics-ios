// GoogleAnalyticsIntegration.m
// Copyright (c) 2014 Segment.io. All rights reserved.


#import <GoogleAnalytics/GAIDictionaryBuilder.h>
#import <GoogleAnalytics/GAIFields.h>
#import <GoogleAnalytics/GAI.h>
#import "SEGAnalyticsUtils.h"
#import "SEGAnalytics.h"
#import "SEGGoogleAnalyticsIntegration.h"


@interface SEGGoogleAnalyticsIntegration ()

@property (nonatomic, copy) NSDictionary *traits;
@property (nonatomic, copy) id<GAITracker> tracker;

@end


@implementation SEGGoogleAnalyticsIntegration

#pragma mark - Initialization

+ (void)load
{
    [SEGAnalytics registerIntegration:self withIdentifier:@"Google Analytics"];
}

- (id)init
{
    if (self = [super init]) {
        self.name = @"Google Analytics";
        self.valid = NO;
        self.initialized = NO;
    }
    return self;
}

- (void)start
{
    // Google Analytics needs to be initialized on the main thread, but
    // dispatch-ing to the main queue when already on the main thread
    // causes the initialization to happen async. After first startup
    // we need the initialization to be synchronous.
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:YES];
        return;
    }

    NSString *trackingId = [self.settings objectForKey:@"mobileTrackingId"];
    self.tracker = [[GAI sharedInstance] trackerWithTrackingId:trackingId];
    [[GAI sharedInstance] setDefaultTracker:self.tracker];

    if ([(NSNumber *)[self.settings objectForKey:@"reportUncaughtExceptions"] boolValue]) {
        [GAI sharedInstance].trackUncaughtExceptions = YES;
    }

    if ([(NSNumber *)[self.settings objectForKey:@"doubleClick"] boolValue]) {
        [self.tracker setAllowIDFACollection:YES];
    }

    SEGLog(@"GoogleAnalyticsIntegration initialized.");

    [super start];
}


#pragma mark - Settings

- (void)validate
{
    BOOL hasTrackingId = [self.settings objectForKey:@"mobileTrackingId"] != nil;
    self.valid = hasTrackingId;
}


#pragma mark - Analytics API

- (void)identify:(NSString *)userId traits:(NSDictionary *)traits options:(NSDictionary *)options
{
    if ([self shouldSendUserId]) {
        [self.tracker set:@"&uid" value:userId];
    }

    NSDictionary *customDimensions = self.settings[@"dimensions"];
    NSDictionary *customMetrics = self.settings[@"metrics"];

    [traits enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
      NSString *dimension = [customDimensions objectForKey:key];
      if (dimension != nil) {
          int index = [[dimension substringFromIndex:8] intValue];
          NSString *value = [[traits objectForKey:key] description];
          [self.tracker set:[GAIFields customDimensionForIndex:index]
                      value:value];
      }

      NSString *metric = [customMetrics objectForKey:key];
      if (metric != nil) {
          int index = [[metric substringFromIndex:6] intValue];
          NSString *value = [[traits objectForKey:key] description];
          [self.tracker set:[GAIFields customMetricForIndex:index]
                      value:value];
      }
    }];
}

- (void)track:(NSString *)event properties:(NSDictionary *)properties options:(NSDictionary *)options
{
    [super track:event properties:properties options:options];

    NSString *category = @"All"; // default
    NSString *categoryProperty = [properties objectForKey:@"category"];
    if (categoryProperty) {
        category = categoryProperty;
    }

    NSNumber *value = [SEGAnalyticsIntegration extractRevenue:properties];
    NSNumber *valueFallback = [SEGAnalyticsIntegration extractRevenue:properties withKey:@"value"];
    if (!value && valueFallback) {
        value = valueFallback;
    }

    NSString *label = [properties objectForKey:@"label"];

    SEGLog(@"Sending to Google Analytics: category %@, action %@, label %@, value %@", category, event, label, value);

    GAIDictionaryBuilder *hit =
        [GAIDictionaryBuilder createEventWithCategory:category
                                               action:event
                                                label:label
                                                value:value];

    [self setCustomDimensionsAndMetrics:properties onHit:hit];

    [self.tracker send:[hit build]];
}

- (void)screen:(NSString *)screenTitle properties:(NSDictionary *)properties options:(NSDictionary *)options
{
    [self.tracker set:kGAIScreenName value:screenTitle];
    GAIDictionaryBuilder *view = [GAIDictionaryBuilder createScreenView];
    [self setCustomDimensionsAndMetrics:properties onHit:view];
    [self.tracker send:[view build]];
}

#pragma mark - Ecommerce

- (void)completedOrder:(NSDictionary *)properties
{
    NSString *orderId = properties[@"orderId"];
    NSString *currency = properties[@"currency"] ?: @"USD";

    SEGLog(@"Tracking completed order to Google Analytics with properties: %@", properties);

    [self.tracker send:[[GAIDictionaryBuilder createTransactionWithId:orderId
                                                          affiliation:properties[@"affiliation"]
                                                              revenue:[self.class extractRevenue:properties]
                                                                  tax:properties[@"tax"]
                                                             shipping:properties[@"shipping"]
                                                         currencyCode:currency] build]];

    [self.tracker send:[[GAIDictionaryBuilder createItemWithTransactionId:orderId
                                                                     name:properties[@"name"]
                                                                      sku:properties[@"sku"]
                                                                 category:properties[@"category"]
                                                                    price:properties[@"price"]
                                                                 quantity:properties[@"quantity"]
                                                             currencyCode:currency] build]];
}

- (void)reset
{
    [super reset];

    [self.tracker set:@"&uid" value:nil];
}


- (void)flush
{
    [[GAI sharedInstance] dispatch];
}

#pragma mark - Private

// event and screen properties are generall hit-scoped dimensions, so we want
// to set them on the hits, not the tracker
- (void)setCustomDimensionsAndMetrics:(NSDictionary *)properties onHit:(GAIDictionaryBuilder *)hit
{
    NSDictionary *customDimensions = self.settings[@"dimensions"];
    NSDictionary *customMetrics = self.settings[@"metrics"];

    for (NSString *key in properties) {
        NSString *metric = [customMetrics objectForKey:key];
        NSString *dimension = [customDimensions objectForKey:key];

        if (dimension != nil) {
            int index = [[dimension substringFromIndex:8] intValue];
            NSString *value = [[properties objectForKey:key] description];
            [hit set:value forKey:[GAIFields customDimensionForIndex:index]];
        }
        if (metric != nil) {
            int index = [[metric substringFromIndex:6] intValue];
            NSString *value = [[properties objectForKey:key] description];
            [hit set:value forKey:[GAIFields customMetricForIndex:index]];
        }
    }
}

- (BOOL)shouldSendUserId
{
    return [[self.settings objectForKey:@"sendUserId"] boolValue];
}

@end
