/// triPOS Mobile SDK 枚举定义

/// 设备类型枚举
enum DeviceType {
  /// 无设备（无物理设备）
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

/// 应用模式（环境）
enum ApplicationMode {
  /// 生产环境
  production,

  /// 测试/认证环境
  testCertification,
}

/// 货币代码
enum CurrencyCode {
  /// 美元
  usd,

  /// 加元
  cad,
}

/// 持卡人在场代码
enum CardHolderPresentCode {
  /// 持卡人在场
  present,

  /// 持卡人不在场
  notPresent,

  /// 邮购订单
  mailOrder,

  /// 电话订单
  telephoneOrder,

  /// 电子商务
  ecommerce,
}

/// 终端类型
enum TerminalType {
  /// 销售点
  pointOfSale,

  /// 移动终端
  mobile,

  /// 电子商务
  ecommerce,

  /// 邮购/电话订单
  moto,
}

/// 礼品卡程序类型
enum GiftProgramType {
  /// 礼品卡
  gift,

  /// 会员卡
  loyalty,
}

/// 市场代码
enum MarketCode {
  /// 零售
  retail,

  /// 餐饮
  restaurant,

  /// 酒店/住宿
  hotelLodging,

  /// 汽车租赁
  autoRental,
}

/// 交易状态（匹配 VTPTransactionStatus）
enum TransactionStatus {
  /// 未知状态
  unknown,

  /// 已批准（在线）
  approved,

  /// 部分批准
  partiallyApproved,

  /// 已批准（现金返还除外）
  approvedExceptCashback,

  /// 商户批准（离线/Store-and-Forward）
  approvedByMerchant,

  /// 需联系发卡行
  callIssuer,

  /// 已拒绝
  declined,

  /// 需要撤销
  needsToBeReversed,

  /// DCC 请求（动态货币转换）
  dccRequested,

  /// 错误（插件特有，非 SDK）
  error,
}

/// 支付处理器
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

/// 地址验证条件
enum AddressVerificationCondition {
  /// 仅手动输入时
  keyed,

  /// 始终验证
  always,

  /// 从不验证
  never,
}

/// 小费选择类型
enum TipSelectionType {
  /// 按金额
  amount,

  /// 按百分比
  percentage,
}

/// 卡片输入方式
enum EntryMode {
  /// 磁条刷卡
  magStripe,

  /// 接触式 EMV 芯片
  contactEmv,

  /// 非接触式 EMV 芯片
  contactlessEmv,

  /// 手动输入
  keyed,

  /// 条形码
  barcode,
}

/// 卡类型
enum CardType {
  /// 信用卡
  credit,

  /// 借记卡
  debit,

  /// 礼品卡
  gift,

  /// EBT 卡
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
