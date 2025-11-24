//
//  VPDIngenicoRba+Print.h
//  triPOSMobileSDK
//
//  Created on 09/07/24.
//  Copyright © 2024 Worldpay from FIS. All rights reserved.
//

#import "VPDIngenicoRba.h"
#import "VPDPrint.h"
#import "VPDBarcodeType.h"
#import "VPDBarcodeAlignment.h"
#import "VPDBarcodeOrientation.h"
#import "VTPReceiptData.h"

@interface VPDIngenicoRba (Print) <VPDPrint>

-(void)initialize;

-(VPDPrintDevice)getAsPrintDevice;

- (void)printReceipt;

-(void)printCustomText:(NSString *)textToPrint;

-(void) printReceiptWithData:(VTPReceiptData *)receiptData error:(NSError *)error;
 
-(void)startNewReceipt;
 
-(void)addSeparatorLine;
 
-(void)addStringArray:(NSArray<NSString *> *)arrayList withCenterAlignment:(BOOL)centerAlignmentFlag;

-(void)addAmountSeparatorLine;
 
-(void)forwardReceipt:(NSInteger)forwardMargin;

- (void)addSignatureLine;

- (void)addCenteredTextLineOnReceipt:(NSString *)textLine;

-(void)addLeftJustifiedTextWithRightJustifiedText:(NSString *)leftText rightText:(NSString *)rightText;

-(void)addThreeColumnsWithColumn1WidthPercentage:(double) column1WidthPercentage  column2WidthPercentage:(double) column2WidthPercentage col1Text:(NSString *)col1Text col2Text:(NSString *)col2Text col3Text:(NSString *)col3Text;

- (void)addNewLineOnReceipt;

- (void)addTextToReceipt:(NSString *)text;

-(void)sendCurrentJobToPrinter;

-(void)printBarcode:(NSString *)barcodeData barcodeType:(VPDBarcodeType)barcodeType barcodeHeight:(NSUInteger)barcodeHeight barcodeWidth:(NSUInteger)barcodeWidth barcodeAlignment:(VPDBarcodeAlignment)alignment barcodeOrientation:(VPDBarcodeOrientation)orientation;

@end
