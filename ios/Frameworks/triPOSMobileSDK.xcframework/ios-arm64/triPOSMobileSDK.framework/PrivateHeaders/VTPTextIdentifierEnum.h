//
//  VTPTextIdentifierEnum.h
//  triPOSMobileSDK
//
//  Created on 27/01/25.
//  Copyright © 2025 Worldpay from FIS. All rights reserved.
//

#ifndef VTPTextIdentifierEnum_h
#define VTPTextIdentifierEnum_h

#import "VTCEnum.h"

@interface VTPTextIdentifierEnum : NSObject <VTCEnum>
+(NSString *)getNameForValue:(int)value;
@end

#endif /* VTPTextIdentifierEnum_h */
