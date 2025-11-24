//
//  VTPBinEntryDatabase.h
//  triPOSMobileSDK
//
//  Created on 29/02/24.
//  Copyright © 2024 Worldpay from FIS. All rights reserved.
//

#ifndef VTPBinEntryDatabase_h
#define VTPBinEntryDatabase_h

#import "VTPBinEntryData.h"

@protocol VTPBinEntryDatabase

@required

-(BOOL)openWithName:(NSString *)name error:(NSError **)error;

-(BOOL)close:(NSError **)error;

-(BOOL)deleteAllBINEntries:(NSError **)error;

@end

#endif /* VTPBinEntryDatabase_h */
