/// Enums for triPOS Mobile SDK

/// Device type enumeration
enum DeviceType {
  /// Null device (no physical device)
  none,

  /// BBPOS Chipper 2X BT
  bbposChipper2XBT,

  /// Ingenico Moby 5500
  ingenicoMoby5500,

  /// Ingenico Moby 8500
  ingenicoMoby8500,

  /// Lane 3000
  lane3000,

  /// Lane 5000
  lane5000,

  /// Lane 7000
  lane7000,

  /// Lane 8000
  lane8000,
}

/// Application mode (environment)
enum ApplicationMode {
  /// Production environment
  production,

  /// Test/Certification environment
  testCertification,
}

/// Currency code
enum CurrencyCode {
  /// US Dollar
  usd,

  /// Canadian Dollar
  cad,
}

/// Cardholder present code
enum CardHolderPresentCode {
  /// Cardholder is present
  present,

  /// Cardholder is not present
  notPresent,

  /// Mail order
  mailOrder,

  /// Telephone order
  telephoneOrder,

  /// Ecommerce
  ecommerce,
}

/// Terminal type
enum TerminalType {
  /// Point of sale
  pointOfSale,

  /// Mobile
  mobile,

  /// Ecommerce
  ecommerce,

  /// MOTO
  moto,
}

/// Gift program type
enum GiftProgramType {
  /// Gift
  gift,

  /// Loyalty
  loyalty,
}

/// Market code
enum MarketCode {
  /// Retail
  retail,

  /// Restaurant
  restaurant,

  /// Hotel/Lodging
  hotelLodging,

  /// Auto rental
  autoRental,
}

/// Transaction status from SDK
enum TransactionStatus {
  /// Approved (online)
  approved,

  /// Approved by merchant (offline/Store-and-Forward)
  approvedByMerchant,

  /// Declined
  declined,

  /// Error
  error,

  /// Duplicate
  duplicate,

  /// Partial approval
  partialApproval,
}

/// Payment processor
enum PaymentProcessor {
  /// Worldpay
  worldpay,

  /// Elavon
  elavon,
}

/// VTP Status for transaction progress
enum VtpStatus {
  /// Unknown status
  unknown,

  /// Idle
  idle,

  /// Card inserted
  cardInserted,

  /// Card removed
  cardRemoved,

  /// Card swipe detected
  cardSwipeDetected,

  /// Contact card type
  contactCardType,

  /// Contactless card type
  contactlessCardType,

  /// Mag stripe card type
  magStripeCardType,

  /// Transaction cancelled
  transactionCancelled,

  /// Waiting for card
  waitingForCard,

  /// Reading card
  readingCard,

  /// Card read complete
  cardReadComplete,

  /// Processing transaction
  processingTransaction,

  /// Transaction complete
  transactionComplete,

  /// Waiting for PIN
  waitingForPin,

  /// PIN entry complete
  pinEntryComplete,

  /// Waiting for signature
  waitingForSignature,

  /// Signature complete
  signatureComplete,

  /// Waiting for amount confirmation
  waitingForAmountConfirmation,

  /// Amount confirmation complete
  amountConfirmationComplete,

  /// Waiting for tip
  waitingForTip,

  /// Tip entry complete
  tipEntryComplete,

  /// Connecting to device
  connectingToDevice,

  /// Connected to device
  connectedToDevice,

  /// Disconnected from device
  disconnectedFromDevice,

  /// Device error
  deviceError,
}

/// Address verification condition
enum AddressVerificationCondition {
  /// Keyed entries only
  keyed,

  /// Always verify
  always,

  /// Never verify
  never,
}

/// Tip selection type
enum TipSelectionType {
  /// Amount-based tips
  amount,

  /// Percentage-based tips
  percentage,
}

/// Entry mode for card input
enum EntryMode {
  /// Magnetic stripe
  magStripe,

  /// Contact EMV
  contactEmv,

  /// Contactless EMV
  contactlessEmv,

  /// Keyed entry
  keyed,

  /// Barcode
  barcode,
}

/// Card type
enum CardType {
  /// Credit card
  credit,

  /// Debit card
  debit,

  /// Gift card
  gift,

  /// EBT card
  ebt,
}
