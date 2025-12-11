/// Configuration models for triPOS Mobile SDK

import 'enums.dart';

/// Host configuration with credentials and processor settings
class HostConfiguration {
  /// Acceptor ID from Worldpay
  final String acceptorId;

  /// Account ID from Worldpay
  final String accountId;

  /// Account token for authentication
  final String accountToken;

  /// Application ID
  final String applicationId;

  /// Application name
  final String applicationName;

  /// Application version
  final String applicationVersion;

  /// Payment processor
  final PaymentProcessor paymentProcessor;

  /// Store card ID (optional)
  final String? storeCardId;

  /// Store card password (optional)
  final String? storeCardPassword;

  /// Vault ID (optional)
  final String? vaultId;

  const HostConfiguration({
    required this.acceptorId,
    required this.accountId,
    required this.accountToken,
    this.applicationId = '8414',
    this.applicationName = 'triPOS Flutter',
    this.applicationVersion = '1.0.0',
    this.paymentProcessor = PaymentProcessor.worldpay,
    this.storeCardId,
    this.storeCardPassword,
    this.vaultId,
  });

  Map<String, dynamic> toMap() => {
    'acceptorId': acceptorId,
    'accountId': accountId,
    'accountToken': accountToken,
    'applicationId': applicationId,
    'applicationName': applicationName,
    'applicationVersion': applicationVersion,
    'paymentProcessor': paymentProcessor.name,
    'storeCardId': storeCardId,
    'storeCardPassword': storeCardPassword,
    'vaultId': vaultId,
  };
}

/// Device configuration for terminal settings
class DeviceConfiguration {
  /// Device type (e.g., Moby 5500)
  final DeviceType deviceType;

  /// Terminal ID
  final String terminalId;

  /// Terminal type
  final TerminalType terminalType;

  /// Bluetooth device identifier (e.g., "MOB55-12345")
  final String? identifier;

  /// Allow contactless transactions
  final bool contactlessAllowed;

  /// Allow keyed entry
  final bool keyedEntryAllowed;

  /// Enable heartbeat monitoring
  final bool heartbeatEnabled;

  /// Enable barcode reader
  final bool barcodeReaderEnabled;

  /// Sleep timeout in seconds
  final int sleepTimeoutSeconds;

  const DeviceConfiguration({
    this.deviceType = DeviceType.ingenicoMoby5500,
    this.terminalId = '1234',
    this.terminalType = TerminalType.mobile,
    this.identifier,
    this.contactlessAllowed = true,
    this.keyedEntryAllowed = true,
    this.heartbeatEnabled = true,
    this.barcodeReaderEnabled = true,
    this.sleepTimeoutSeconds = 300,
  });

  DeviceConfiguration copyWith({
    DeviceType? deviceType,
    String? terminalId,
    TerminalType? terminalType,
    String? identifier,
    bool? contactlessAllowed,
    bool? keyedEntryAllowed,
    bool? heartbeatEnabled,
    bool? barcodeReaderEnabled,
    int? sleepTimeoutSeconds,
  }) => DeviceConfiguration(
    deviceType: deviceType ?? this.deviceType,
    terminalId: terminalId ?? this.terminalId,
    terminalType: terminalType ?? this.terminalType,
    identifier: identifier ?? this.identifier,
    contactlessAllowed: contactlessAllowed ?? this.contactlessAllowed,
    keyedEntryAllowed: keyedEntryAllowed ?? this.keyedEntryAllowed,
    heartbeatEnabled: heartbeatEnabled ?? this.heartbeatEnabled,
    barcodeReaderEnabled: barcodeReaderEnabled ?? this.barcodeReaderEnabled,
    sleepTimeoutSeconds: sleepTimeoutSeconds ?? this.sleepTimeoutSeconds,
  );

  Map<String, dynamic> toMap() => {
    'deviceType': deviceType.name,
    'terminalId': terminalId,
    'terminalType': terminalType.name,
    'identifier': identifier,
    'contactlessAllowed': contactlessAllowed,
    'keyedEntryAllowed': keyedEntryAllowed,
    'heartbeatEnabled': heartbeatEnabled,
    'barcodeReaderEnabled': barcodeReaderEnabled,
    'sleepTimeoutSeconds': sleepTimeoutSeconds,
  };
}

/// Transaction configuration for payment settings
class TransactionConfiguration {
  /// Allow EMV transactions
  final bool emvAllowed;

  /// Allow tips
  final bool tipAllowed;

  /// Allow tip entry
  final bool tipEntryAllowed;

  /// Tip selection type
  final TipSelectionType tipSelectionType;

  /// Tip options (amounts or percentages)
  final List<double> tipOptions;

  /// Allow debit transactions
  final bool debitAllowed;

  /// Allow cashback
  final bool cashbackAllowed;

  /// Allow cashback entry
  final bool cashbackEntryAllowed;

  /// Cashback entry increment
  final int cashbackEntryIncrement;

  /// Maximum cashback amount
  final int cashbackEntryMaximum;

  /// Cashback options
  final List<double> cashbackOptions;

  /// Allow gift card transactions
  final bool giftCardAllowed;

  /// Allow Quick Chip
  final bool quickChipAllowed;

  /// Enable amount confirmation
  final bool amountConfirmationEnabled;

  /// Enable duplicate transaction check
  final bool duplicateTransactionsAllowed;

  /// Allow partial approval
  final bool partialApprovalAllowed;

  /// Currency code
  final CurrencyCode currencyCode;

  /// Address verification condition
  final AddressVerificationCondition addressVerificationCondition;

  const TransactionConfiguration({
    this.emvAllowed = true,
    this.tipAllowed = true,
    this.tipEntryAllowed = true,
    this.tipSelectionType = TipSelectionType.amount,
    this.tipOptions = const [1.0, 2.0, 3.0],
    this.debitAllowed = true,
    this.cashbackAllowed = true,
    this.cashbackEntryAllowed = true,
    this.cashbackEntryIncrement = 5,
    this.cashbackEntryMaximum = 100,
    this.cashbackOptions = const [5.0, 10.0, 15.0],
    this.giftCardAllowed = true,
    this.quickChipAllowed = true,
    this.amountConfirmationEnabled = true,
    this.duplicateTransactionsAllowed = true,
    this.partialApprovalAllowed = false,
    this.currencyCode = CurrencyCode.usd,
    this.addressVerificationCondition = AddressVerificationCondition.keyed,
  });

  Map<String, dynamic> toMap() => {
    'emvAllowed': emvAllowed,
    'tipAllowed': tipAllowed,
    'tipEntryAllowed': tipEntryAllowed,
    'tipSelectionType': tipSelectionType.name,
    'tipOptions': tipOptions,
    'debitAllowed': debitAllowed,
    'cashbackAllowed': cashbackAllowed,
    'cashbackEntryAllowed': cashbackEntryAllowed,
    'cashbackEntryIncrement': cashbackEntryIncrement,
    'cashbackEntryMaximum': cashbackEntryMaximum,
    'cashbackOptions': cashbackOptions,
    'giftCardAllowed': giftCardAllowed,
    'quickChipAllowed': quickChipAllowed,
    'amountConfirmationEnabled': amountConfirmationEnabled,
    'duplicateTransactionsAllowed': duplicateTransactionsAllowed,
    'partialApprovalAllowed': partialApprovalAllowed,
    'currencyCode': currencyCode.name,
    'addressVerificationCondition': addressVerificationCondition.name,
  };
}

/// Application configuration
class ApplicationConfiguration {
  /// Application mode (production or test)
  final ApplicationMode applicationMode;

  /// Idle prompt text displayed on device
  final String idlePrompt;

  const ApplicationConfiguration({
    this.applicationMode = ApplicationMode.testCertification,
    this.idlePrompt = 'triPOS Flutter',
  });

  Map<String, dynamic> toMap() => {
    'applicationMode': applicationMode.name,
    'idlePrompt': idlePrompt,
  };
}

/// Store and forward configuration
class StoreAndForwardConfiguration {
  /// Number of days to retain processed transactions
  final int numberOfDaysToRetainProcessedTransactions;

  /// Auto-forward stored transactions
  final bool shouldTransactionsBeAutomaticallyForwarded;

  /// Allow storing transactions
  final bool storingTransactionsAllowed;

  /// Maximum transaction amount for store and forward
  final int transactionAmountLimit;

  /// Maximum total amount for unprocessed transactions
  final int unprocessedTotalAmountLimit;

  const StoreAndForwardConfiguration({
    this.numberOfDaysToRetainProcessedTransactions = 1,
    this.shouldTransactionsBeAutomaticallyForwarded = false,
    this.storingTransactionsAllowed = true,
    this.transactionAmountLimit = 50,
    this.unprocessedTotalAmountLimit = 100,
  });

  Map<String, dynamic> toMap() => {
    'numberOfDaysToRetainProcessedTransactions':
        numberOfDaysToRetainProcessedTransactions,
    'shouldTransactionsBeAutomaticallyForwarded':
        shouldTransactionsBeAutomaticallyForwarded,
    'storingTransactionsAllowed': storingTransactionsAllowed,
    'transactionAmountLimit': transactionAmountLimit,
    'unprocessedTotalAmountLimit': unprocessedTotalAmountLimit,
  };
}

/// Main SDK configuration combining all settings
class TriposConfiguration {
  /// Host configuration with credentials
  final HostConfiguration hostConfiguration;

  /// Device configuration
  final DeviceConfiguration deviceConfiguration;

  /// Transaction configuration
  final TransactionConfiguration transactionConfiguration;

  /// Application configuration
  final ApplicationConfiguration applicationConfiguration;

  /// Store and forward configuration
  final StoreAndForwardConfiguration storeAndForwardConfiguration;

  const TriposConfiguration({
    required this.hostConfiguration,
    this.deviceConfiguration = const DeviceConfiguration(),
    this.transactionConfiguration = const TransactionConfiguration(),
    this.applicationConfiguration = const ApplicationConfiguration(),
    this.storeAndForwardConfiguration = const StoreAndForwardConfiguration(),
  });

  TriposConfiguration copyWith({
    HostConfiguration? hostConfiguration,
    DeviceConfiguration? deviceConfiguration,
    TransactionConfiguration? transactionConfiguration,
    ApplicationConfiguration? applicationConfiguration,
    StoreAndForwardConfiguration? storeAndForwardConfiguration,
  }) => TriposConfiguration(
    hostConfiguration: hostConfiguration ?? this.hostConfiguration,
    deviceConfiguration: deviceConfiguration ?? this.deviceConfiguration,
    transactionConfiguration:
        transactionConfiguration ?? this.transactionConfiguration,
    applicationConfiguration:
        applicationConfiguration ?? this.applicationConfiguration,
    storeAndForwardConfiguration:
        storeAndForwardConfiguration ?? this.storeAndForwardConfiguration,
  );

  Map<String, dynamic> toMap() => {
    'hostConfiguration': hostConfiguration.toMap(),
    'deviceConfiguration': deviceConfiguration.toMap(),
    'transactionConfiguration': transactionConfiguration.toMap(),
    'applicationConfiguration': applicationConfiguration.toMap(),
    'storeAndForwardConfiguration': storeAndForwardConfiguration.toMap(),
  };
}
