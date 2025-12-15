//
//  VTPTextIdentifier.h
//  triPOSMobileSDK
//
//  Created on 27/01/25.
//  Copyright © 2025 Worldpay from FIS. All rights reserved.
//

#ifndef VTPTextIdentifier_h
#define VTPTextIdentifier_h

typedef enum _VTPTextIdentifier
{
    /// InsertSwipeTapCard
    VTPTextIdentifierInsertSwipeTapCard,
    /// InsertSwipeCard
    VTPTextIdentifierInsertSwipeCard,
    /// SwipeTapCard
    VTPTextIdentifierSwipeTapCard,
    /// SwipeCard
    VTPTextIdentifierSwipeCard,
    /// InsertSwipeTryAnotherCard
    VTPTextIdentifierInsertSwipeTryAnotherCard,
    /// UseChipReader
    VTPTextIdentifierUseChipReader,
    /// CardReadError
    VTPTextIdentifierCardReadError,
    /// CardReadFailedRemoveCard
    VTPTextIdentifierCardReadFailedRemoveCard,
    /// PleaseWait
    VTPTextIdentifierPleaseWait,
    /// MultipleCardsDetected
    VTPTextIdentifierMultipleCardsDetected,
    /// ChipReadError
    VTPTextIdentifierChipReadError,
} VTPTextIdentifier;

#endif /* VTPTextIdentifier_h */
