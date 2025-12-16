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
/// 交易状态枚举，同时支持 Android 和 iOS 平台
/// - Android: 从 triposmobilesdk-release.aar 中的 VtpStatus 枚举提取
/// - iOS: 从 triPOSMobileSDK.xcframework/Headers/VTPStatus.h 中提取
/// 注意：某些状态可能仅在特定平台上使用
enum VtpStatus {
  /// 无状态
  none,

  /// 正在初始化
  initializing,

  /// 正在反初始化
  deinitializing,

  /// 交易完成
  done,

  /// 未知状态
  unknown,

  /// 正在执行健康检查
  runningHealthCheck,

  /// 正在执行销售交易
  runningSale,

  /// 正在执行退款交易
  runningRefund,

  /// 正在执行授权交易
  runningAuthorization,

  /// 正在执行令牌授权交易
  runningAuthorizationWithToken,

  /// 正在激活礼品卡
  runningGiftCardActivate,

  /// 正在查询礼品卡余额
  runningGiftCardBalanceInquiry,

  /// 正在充值礼品卡
  runningGiftCardReload,

  /// 正在创建令牌
  runningCreateToken,

  /// 正在使用交易ID创建令牌
  runningCreateTokenWithTransactionId,

  /// 正在执行令牌销售交易
  runningSaleWithToken,

  /// 正在手动转发交易
  runningManuallyForward,

  /// 正在查询 EBT 余额
  runningEbtBalanceInquiry,

  /// 正在处理 EBT 凭证
  runningEbtVoucher,

  /// 正在执行撤销交易
  runningReversal,

  /// 正在执行退货交易
  runningReturn,

  /// 正在执行增量授权
  runningIncrementalAuthorization,

  /// 正在执行作废交易
  runningVoid,

  /// 正在执行令牌退款交易
  runningRefundWithToken,

  /// 正在调整信用卡交易
  runningCreditCardAdjustment,

  /// 正在完成授权交易
  runningAuthorizationCompletion,

  /// 正在执行托管支付销售
  runningHostedPaymentSale,

  /// 正在执行托管支付授权
  runningHostedPaymentAuthorization,

  /// 正在关闭礼品卡
  runningGiftCardClose,

  /// 正在请求礼品卡余额转账
  runningGiftCardBalanceTransferRequest,

  /// 正在请求卸载礼品卡
  runningGiftCardUnloadRequest,

  /// 正在执行礼品卡余额转账
  runningGiftCardBalanceTransfer,

  /// 等待刷卡/插卡输入
  gettingCardInput,

  /// 等待刷卡/插卡/NFC输入
  gettingCardInputTapInsertSwipe,

  /// 等待插卡/刷卡输入
  gettingCardInputInsertSwipe,

  /// 等待NFC/刷卡输入
  gettingCardInputTapSwipe,

  /// 等待刷卡输入
  gettingCardInputSwipe,

  /// 等待选择支付方式
  gettingPaymentType,

  /// 等待选择 EBT 类型
  gettingEbtType,

  /// 等待确认手续费金额
  gettingConvenienceFeeAmountConfirmation,

  /// 询问是否添加小费
  gettingWantTip,

  /// 等待选择小费金额
  gettingTipSelection,

  /// 等待输入小费金额
  gettingTipEntry,

  /// 等待确认附加费金额
  gettingSurchargeFeeAmountConfirmation,

  /// 询问是否需要现金返还
  gettingWantCashback,

  /// 等待选择现金返还金额
  gettingCashbackSelection,

  /// 等待输入现金返还金额
  gettingCashbackEntry,

  /// 等待输入邮政编码
  gettingPostalCode,

  /// 等待确认总金额
  gettingTotalAmountConfirmation,

  /// 等待输入 PIN 码
  gettingPin,

  /// 继续 EMV 交易处理
  gettingContinuingEmvTransaction,

  /// 正在完成 EMV 交易
  gettingFinalizingEmvTransaction,

  /// 正在处理卡片输入
  processingCardInput,

  /// 正在发送到主机
  sendingToHost,

  /// 交易处理中
  transactionProcessing,

  /// 正在最终处理交易
  finalizing,

  /// 芯片读取失败
  chipReadFailed,

  /// 刷卡读取失败
  swipeReadFailed,

  /// 芯片卡刷卡读取失败（应插卡）
  chipCardSwipedReadFailed,

  /// 无法获取卡片数据
  failedToRetrieveCardData,

  /// 卡片数据读取超时
  cardDataRetrievalTimeOut,

  /// 启用仅手动输入卡号模式
  enableCardKeyedOnlyInput,

  /// PIN 码正确
  pinOK,

  /// 请重新输入 PIN 码
  reEnterPin,

  /// 最后一次 PIN 码尝试
  lastPinTry,

  /// PIN 码输入成功
  pinEnteredSuccessfully,

  /// PIN 码输入已取消
  pinEntryCancelled,

  /// 请移除卡片
  removeCard,

  /// 卡片已移除
  cardRemoved,

  /// 交易已取消
  transactionCancelled,

  /// 请选择应用程序
  selectApplication,

  /// 卡片不支持非接触式读取
  contactlessReadNotSupportedByCard,

  /// 金额超过非接触式交易限额
  contactlessAmountMaxLimitExceeded,

  /// 检测到多张卡片，请重试
  multipleCardsTappedError,

  /// 非接触式读取失败
  contactlessReadFailed,

  /// 非接触式刷卡次数超过限制
  contactlessTapsMaxNumberExceeded,

  /// 卡片不支持（无匹配AID）
  contactlessCardNotSupportedNoMatchingAID,

  /// 卡片要求更换读卡接口
  contactlessCardRequestsInterfaceSwitch,

  /// 正在显示 DCC 信息
  showingDccInfo,

  /// 请查看手机
  pleaseSeePhone,

  /// 金额已确认
  amountConfirmed,

  /// 附加费已确认
  surchargeFeeAmountConfirmed,

  /// 附加费已拒绝
  surchargeFeeAmountDeclined,

  /// 附加费确认超时
  surchargeFeeAmountTimedOut,

  /// 卡片不支持现金返还
  cashbackUnsupportedCard,
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

/// 设备事件类型枚举
enum DeviceEventType {
  /// 正在连接设备
  connecting,

  /// 设备已连接
  connected,

  /// 设备已断开
  disconnected,

  /// 设备发生错误
  error,

  /// 设备已就绪（可以进行交易）
  ready,

  /// 未知事件类型
  unknown,
}

/// 设备事件数据模型
class DeviceEvent {
  /// 事件类型
  final DeviceEventType type;

  /// 设备型号（连接时可用）
  final String? model;

  /// 设备序列号（连接时可用）
  final String? serialNumber;

  /// 固件版本（连接时可用）
  final String? firmwareVersion;

  /// 错误信息（发生错误时可用）
  final String? message;

  /// 原始事件数据
  final Map<String, dynamic> rawData;

  const DeviceEvent({
    required this.type,
    this.model,
    this.serialNumber,
    this.firmwareVersion,
    this.message,
    this.rawData = const {},
  });

  /// 从原始 Map 创建 DeviceEvent
  factory DeviceEvent.fromMap(Map<String, dynamic> map) {
    final eventString = map['event'] as String? ?? 'unknown';
    final type = DeviceEventType.values.firstWhere(
      (e) => e.name == eventString,
      orElse: () => DeviceEventType.unknown,
    );

    return DeviceEvent(
      type: type,
      model: map['model'] as String?,
      serialNumber: map['serialNumber'] as String?,
      firmwareVersion: map['firmwareVersion'] as String?,
      message: map['message'] as String?,
      rawData: map,
    );
  }

  @override
  String toString() =>
      'DeviceEvent(type: $type, model: $model, message: $message)';
}
