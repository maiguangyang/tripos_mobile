//
//  VPDBarcodeTypeEnum.m
//  PoiDevice
//
//  Created by Chance Ulrich on 3/19/16.
//  Copyright © 2018 Worldpay, LLC. and/or its affiliates. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "VPDBarcodeTypeEnum.h"
#import "VPDBarcodeType.h"
#import "NSDictionary+Ordered.h"

@implementation VPDBarcodeTypeEnum

static NSDictionary<NSNumber *, NSString *> *names;

+(void)initialize
{
    names = [NSDictionary orderedDictionaryWithObjectsAndKeys:
             @"Unknown", [NSNumber numberWithInt: VPDBarcodeTypeUnknown],
             @"EAN 8", [NSNumber numberWithInt: VPDBarcodeTypeEan8],
             @"EAN 8 2", [NSNumber numberWithInt: VPDBarcodeTypeEan8_2],
             @"EAN 8 5", [NSNumber numberWithInt: VPDBarcodeTypeEan8_5],
             @"EAN 8 composite CC-A", [NSNumber numberWithInt: VPDBarcodeTypeEan8CompositeCcA],
             @"EAN 8 composite CC-B", [NSNumber numberWithInt: VPDBarcodeTypeEan8CompositeCcB],
             @"EAN 13", [NSNumber numberWithInt: VPDBarcodeTypeEan13],
             @"EAN 13 2", [NSNumber numberWithInt: VPDBarcodeTypeEan13_2],
             @"EAN 13 5", [NSNumber numberWithInt: VPDBarcodeTypeEan13_5],
             @"EAN 13 composite CC-A", [NSNumber numberWithInt: VPDBarcodeTypeEan13CompositeCcA],
             @"EAN 12 composite CC-B", [NSNumber numberWithInt: VPDBarcodeTypeEan13CompositeCcB],
             @"UPC-A", [NSNumber numberWithInt: VPDBarcodeTypeUpcA],
             @"UPC-A 2", [NSNumber numberWithInt: VPDBarcodeTypeUpcA_2],
             @"UPC-A 5", [NSNumber numberWithInt: VPDBarcodeTypeUpcA_5],
             @"UPC-A composite CC-A", [NSNumber numberWithInt: VPDBarcodeTypeUpcACcA],
             @"UPC-A composite CC-B", [NSNumber numberWithInt: VPDBarcodeTypeUpcACcB],
             @"UPC-E", [NSNumber numberWithInt: VPDBarcodeTypeUpcE],
             @"UPC-E 2", [NSNumber numberWithInt: VPDBarcodeTypeUpcE_2],
             @"UPC-E 5", [NSNumber numberWithInt: VPDBarcodeTypeUpcE_5],
             @"UPC-E composite CC-A", [NSNumber numberWithInt: VPDBarcodeTypeUpcECcA],
             @"UPC-E composite CC-B", [NSNumber numberWithInt: VPDBarcodeTypeUpcECcB],
             @"Code 39", [NSNumber numberWithInt: VPDBarcodeTypeCode39],
             @"Code 39 Italian CPI", [NSNumber numberWithInt: VPDBarcodeTypeCode39ItalianCpi],
             @"Interleaved 2 of 5", [NSNumber numberWithInt: VPDBarcodeTypeInterleaved2Of5],
             @"Standard 2 of 5", [NSNumber numberWithInt: VPDBarcodeTypeStandard2Of5],
             @"Matrix 2 of 5", [NSNumber numberWithInt: VPDBarcodeTypeMatrix2Of5],
             @"Codabar", [NSNumber numberWithInt: VPDBarcodeTypeCodabar],
             @"Ames code", [NSNumber numberWithInt: VPDBarcodeTypeAmesCode],
             @"MSI", [NSNumber numberWithInt: VPDBarcodeTypeMsi],
             @"Plessy", [NSNumber numberWithInt: VPDBarcodeTypePlessy],
             @"Code 128", [NSNumber numberWithInt: VPDBarcodeTypeCode128],
             @"Code 16K", [NSNumber numberWithInt: VPDBarcodeTypeCode16K],
             @"Code 93", [NSNumber numberWithInt: VPDBarcodeTypeCode93],
             @"Code 11", [NSNumber numberWithInt: VPDBarcodeTypeCode11],
             @"Telepen", [NSNumber numberWithInt: VPDBarcodeTypeTelepen],
             @"Code 49", [NSNumber numberWithInt: VPDBarcodeTypeCode49],
             @"Code 25", [NSNumber numberWithInt: VPDBarcodeTypeCode25],
             @"CodaBlock A", [NSNumber numberWithInt: VPDBarcodeTypeCodaBlockA],
             @"CodaBlock F", [NSNumber numberWithInt: VPDBarcodeTypeCodaBlockF],
             @"CodaBlock 256", [NSNumber numberWithInt: VPDBarcodeTypeCodaBlock256],
             @"PDF417", [NSNumber numberWithInt: VPDBarcodeTypePdf417],
             @"GS1 128", [NSNumber numberWithInt: VPDBarcodeTypeGs1_128],
             @"GS1 128 composite CC-A", [NSNumber numberWithInt: VPDBarcodeTypeGs1_128CompositeCcA],
             @"GS1 128 composite CC-B", [NSNumber numberWithInt: VPDBarcodeTypeGs1_128CompositeCcB],
             @"GS1 128 composite CC-C", [NSNumber numberWithInt: VPDBarcodeTypeGs1_128CompositeCcC],
             @"GS1 DataBar", [NSNumber numberWithInt: VPDBarcodeTypeGs1DataBar],
             @"GS1 DataBar omnidirectional", [NSNumber numberWithInt: VPDBarcodeTypeGs1DataBarOmnidirectional],
             @"GS1 DataBar omnidirectional composite CC-A", [NSNumber numberWithInt: VPDBarcodeTypeGs1DataBarOmnidirectionalCompositeCcA],
             @"GS1 DataBar omnidirectional composite CC-B", [NSNumber numberWithInt: VPDBarcodeTypeGs1DataBarOmnidirectionalCompositeCcB],
             @"GS1 DataBar limited", [NSNumber numberWithInt: VPDBarcodeTypeGs1DataBarLimited],
             @"GS1 DataBar limited composite CC-B", [NSNumber numberWithInt: VPDBarcodeTypeGs1DataBarLimitedCcB],
             @"GS1 DataBar expanded", [NSNumber numberWithInt: VPDBarcodeTypeGs1DataBarExpanded],
             @"GS1 DataBar expanded composite CC-A", [NSNumber numberWithInt: VPDBarcodeTypeGs1DataBarExpandedCompositeCcA],
             @"GS1 DataBar expanded composite CC-B", [NSNumber numberWithInt: VPDBarcodeTypeGs1DataBarExpandedCompositeCcB],
             @"ISBT 128", [NSNumber numberWithInt: VPDBarcodeTypeIsbt128],
             @"Micro PDF", [NSNumber numberWithInt: VPDBarcodeTypeMicroPdf],
             @"Data Matrix", [NSNumber numberWithInt: VPDBarcodeTypeDataMatrix],
             @"QR Code", [NSNumber numberWithInt: VPDBarcodeTypeQrCode],
             @"ISBN", [NSNumber numberWithInt: VPDBarcodeTypeIsbn],
             @"POSTNET", [NSNumber numberWithInt: VPDBarcodeTypePostnet],
             @"PLANET", [NSNumber numberWithInt: VPDBarcodeTypePlanet],
             @"BPI", [NSNumber numberWithInt: VPDBarcodeTypeBpo],
             @"Canada Postal", [NSNumber numberWithInt: VPDBarcodeTypeCanadaPostal],
             @"Japan Postal", [NSNumber numberWithInt: VPDBarcodeTypeJapanPostal],
             @"Australia Postal", [NSNumber numberWithInt: VPDBarcodeTypeAustraliaPostal],
             @"Dutch Postal", [NSNumber numberWithInt: VPDBarcodeTypeDutchPostal],
             @"China Postal", [NSNumber numberWithInt: VPDBarcodeTypeChinaPostal],
             @"Korea Postal", [NSNumber numberWithInt: VPDBarcodeTypeKoreaPostal],
             @"Sweden Postal", [NSNumber numberWithInt: VPDBarcodeTypeSwedenPostal],
             @"Infomail", [NSNumber numberWithInt: VPDBarcodeTypeInfomail],
             @"TLC-39", [NSNumber numberWithInt: VPDBarcodeTypeTlc39],
             @"Trioptic", [NSNumber numberWithInt: VPDBarcodeTypeTrioptic],
             @"ISMN", [NSNumber numberWithInt: VPDBarcodeTypeIsmn],
             @"ISSN", [NSNumber numberWithInt: VPDBarcodeTypeIssn],
             @"Aztec", [NSNumber numberWithInt: VPDBarcodeTypeAztec],
             @"Multicode", [NSNumber numberWithInt: VPDBarcodeTypeMulticode],
             @"Incomplete Multicode", [NSNumber numberWithInt: VPDBarcodeTypeIncompleteMulticode],
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
