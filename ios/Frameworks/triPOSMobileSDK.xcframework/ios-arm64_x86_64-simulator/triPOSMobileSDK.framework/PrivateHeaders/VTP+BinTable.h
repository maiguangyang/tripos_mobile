//
//  VTP+BinTable.h
//  triPOSMobileSDK
//
//  Created on 28/02/24.
//  Copyright © 2024 Worldpay from FIS. All rights reserved.
//

#import "VTP.h"
#import "triPOSMobileSDK.h"

@interface VTP(BinTable)

typedef void (^VTPBINApiCompletionHandler)(NSURLResponse *response, NSData *data, NSError *error);

-(void)getBinFile:(NSString *)accountId acceptorId:(NSString *)acceptorId accountToken:(NSString *)accountToken applicationMode:(VTPApplicationMode)mode completionHandler:(VTPBINApiCompletionHandler)completionHandler;

+(BOOL)isFileModifiedThisWeek;

@end
