//
//  VPDBarcodeLightingModeEnum.m
//  Configuration
//
//  Created by Chance Ulrich on 3/9/16.
//  Copyright © 2018 Worldpay, LLC. and/or its affiliates. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "VPDBarcodeLightingMode.h"
#import "VPDBarcodeLightingModeEnum.h"
#import "NSDictionary+Ordered.h"

@implementation VPDBarcodeLightingModeEnum

static NSDictionary<NSNumber *, NSString *> *names;

+(void)initialize
{
    names = [NSDictionary orderedDictionaryWithObjectsAndKeys:
             @"Shorter exposure", [NSNumber numberWithInt: VPDBarcodeLightingModeShorterExposure],
             @"Longer exposure", [NSNumber numberWithInt: VPDBarcodeLightingModeLongerExposure],
             nil];
}

+(NSArray<NSString *> *)getNames;
{
    return names.allOrderedValues;
}

+(NSArray<NSNumber *> *)getValues
{
    return names.allOrderedKeys;
}

+(NSString *)getNameForValue:(int)value
{
    NSNumber *key = [NSNumber numberWithInt: value];
    
    return [names objectForKey: key];
}

+(int)getValueForName:(NSString *)name
{
    NSArray *keys = [names allKeysForObject: name];
    
    if (keys.count == 0)
    {
        return INT_MIN;
    }
    
    return [[keys objectAtIndex: 0] intValue];
}

@end
