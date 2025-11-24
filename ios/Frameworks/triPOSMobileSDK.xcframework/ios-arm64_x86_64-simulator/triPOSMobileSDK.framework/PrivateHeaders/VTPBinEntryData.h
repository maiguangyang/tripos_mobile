//
//  VTPBinEntryData.h
//  triPOSMobileSDK
//
//  Created on 29/02/24.
//  Copyright © 2024 Worldpay from FIS. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifndef VTPBinEntryData_h
#define VTPBinEntryData_h

#import <Realm/Realm.h>

@interface VTPBinEntryData : RLMObject

@property (nonatomic) long int binId;

@property (retain, nonatomic) NSDate *createTime;

@property (retain, nonatomic) NSString *bin;

@property (nonatomic) double panLength;

@property (nonatomic) double binLength;

@property (retain, nonatomic) NSString *network;

@property (nonatomic) NSString *binFlags;

+(VTPBinEntryData *)storeBinDataWithBinId:(NSInteger)binId binLength:(NSInteger)binLength panLength:(NSInteger )panLength bin:(NSString *)bin network:(NSString *)network binFlags:(NSString *)binFlags;
@end

RLM_ARRAY_TYPE(VTPBinEntryData)

#endif /* VTPBinEntryData_h */


