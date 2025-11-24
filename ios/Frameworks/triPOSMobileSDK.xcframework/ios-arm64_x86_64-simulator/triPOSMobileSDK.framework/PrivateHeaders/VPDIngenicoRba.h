///
/// \file VPDIngenicoRba.h
///

#ifndef VPDIngenicoRba_h
#define VPDIngenicoRba_h

#ifndef DOXYGEN_SHOULD_SKIP_THIS

#import "VPDBarcodeInput.h"
#import "VPDDevicePrivate.h"
#import "VPDVersionNumber.h"
#import "VTCTlvUtility.h"
#import "VPDCardInput.h"
#import "VPDIngenicoRbaWrapper.h"

extern NSString * const ConfigIdUserVariableFormsVersion;
extern NSString * const ConfigIdUserVariableCustomPromptsVersion;
extern NSString * const ActivateAndRebootOnFirmwareUpdate;
extern NSString * const ConfigIdUserVarCurrentConfiguration;
extern NSString * const ConfigIdUserVariablePatchVersion;
extern NSString * const ConfigIdUserVariableP2peVersion;

@interface VPDIngenicoRba : VPDDevicePrivate <VPDDevicePrivate>
{
    //BOOL isRbaSdkConnected;
    
}

@property (nonatomic) BOOL stopConnectionCalled;

@property (retain, nonatomic) NSString *idleForm;

@property (retain, nonatomic) NSString * cardDataEncryptionMethod;

@property (nonatomic) BOOL ignoreConnectDisconnectNotifications;

@property (nonatomic) BOOL heartbeatCheckInProgress;

@property (nonatomic) BOOL pingInProgress;

@property (nonatomic) BOOL pingTimerRunning;

@property (nonatomic) BOOL isRbaSdkConnected;

@property (copy, nonatomic) VPDBarcodeInputCompletionHandler barcodeCompletionHandler;

@property (copy, nonatomic) VPDErrorHandler barcodeErrorHandler;

@property(nonatomic) BOOL canStopConnection;

@property (nonatomic, strong) VPDQuickChipCardInputSelectCashbackHandler selectQuickChipCashbackHandler;

-(BOOL)getModelAndSerialNumber;

///
/// \brief Checks if the device is connected and calls the error handler if not
///
/// This method checks of the device is connected and calls the handler if not.
///
/// \return YES if not connected, NO otherwise.
///
-(BOOL)errorIfNotConnected:(VPDErrorHandler)errorHandler;

///
/// \brief Checks if the device is initialized and calls the error handler if not
///
/// This method checks of the device is initialized and calls the handler if not.
///
/// \return YES if not initialized, NO otherwise.
///
-(BOOL)errorIfNotInitialized:(VPDErrorHandler)errorHandler;

-(BOOL)startRbaTcpIpConnection:(NSString *)ipAddress port:(NSUInteger)port error:(NSError **)error;

typedef void (^VPDIngenicoRbaMessageHandler)(NSInteger messageId);

typedef void (^VPDIngenicoRbaEmvResponseWithTagsCompletionHandler)(NSInteger messageId, VTCTlvCollection tags);

@property (copy, nonatomic) VPDIngenicoRbaMessageHandler messageHandler;
@property (copy, nonatomic) VPDIngenicoRbaMessageHandler messageHandlerFor33_05Message;

@property (strong, nonatomic) VTCTlvCollection tagsWith33_02EmvTransactionPreparationResponseMessage;
@property (strong, nonatomic) VTCTlvCollection tagsWith33_03EmvTransactionAuthorizatinRequestMessage;
@property (strong, nonatomic) VTCTlvCollection tagsWith33_05EmvTransactionAuthorizationConfirmationMessage;
@property (atomic) BOOL emvFlowStepSetPaymentTypeReached;
@property (atomic) BOOL emvFlowStepSetCompletionStatusReached;

@property (strong, nonatomic) VPDIngenicoRbaWrapper *ingenicoRbaWrapper;

typedef enum _VPDIngenicoRbaWhatIsEnabled
{
    VPDIngenicoRbaWhatIsEnabledNothing,
    VPDIngenicoRbaWhatIsEnabledCardInput,
    VPDIngenicoRbaWhatIsEnabledChoiceInput,
    VPDIngenicoRbaWhatIsEnabledYesNoInput,
    VPDIngenicoRbaWhatIsEnabledPinInput,
    VPDIngenicoRbaWhatIsEnabledKeyboardNumericInput,
    VPDIngenicoRbaWhatIsEnabledDccInput,
}   VPDIngenicoRbaWhatIsEnabled;

@property (nonatomic) VPDIngenicoRbaWhatIsEnabled whatIsEnabled;

@property (nonatomic) BOOL quickChipEnabled;

@property (atomic) BOOL authorizationResponseMessageWasSent;
@property (atomic) BOOL authorizationConfirmationMessageWasReceived;
@property (atomic) BOOL authorizationRequestMessageWasReceived;
@property (atomic) BOOL cardReadAsQuickChip;
@property (atomic, strong) NSDecimalNumber*  placeHolderAmount;

-(void)setUserInputTimer:(NSInteger) inputTimeout errorHandler:(VPDErrorHandler)errorHandler;

-(void)setNonUserInputTimer:(VPDErrorHandler)errorHandler;

-(void)startInputTimer;

-(void)stopInputTimer;

-(void)setupHeartbeatTimer:(VPDErrorHandler)errorHandler;
-(void)setupPingTimer:(VPDErrorHandler)errorHandler;
@property (atomic, strong) NSArray<NSString*> * availableAids;
@property (atomic, strong) NSArray<NSString*> * availableLanguages;
@property (nonatomic, strong) VPDInitializationParameters * initializationParameters; 
@property (atomic) BOOL fileWriteInProgress;
@property (atomic) VTPInitializationStatus initializationStatus;
@property (atomic, strong) NSString * initializationProgressDescription;
@property (nonatomic) double lastFileUploadProgress;
@property (nonatomic) NSString * paymentProcessorName;
@property (atomic, strong) NSString * bluetoothIdentifier;
@property (nonatomic) BOOL isBluetoothConnection;
@property (nonatomic) NSString * ipAddress;
@property (nonatomic) NSUInteger port;

@end

#endif /* !DOXYGEN_SHOULD_SKIP_THIS */

#endif /* VPDIngenicoRba_h */
