# triPOS Mobile Flutter Plugin

[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green.svg)](https://developer.android.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.3.0+-blue.svg)](https://flutter.dev)

基于 Worldpay triPOS Mobile SDK 的 Flutter 插件，支持 Android 和 iOS 平台通过 Ingenico 蓝牙读卡器进行移动支付。

## ✨ 功能特性

- 🔍 蓝牙设备扫描与连接
- 💳 销售交易 (Sale)
- ↩️ 退款交易 (Refund)
- 🔗 关联退款 - 无需刷卡 (Linked Refund)
- ❌ 作废交易 (Void)
- 📡 Store-and-Forward 离线交易支持
- 📊 实时交易状态更新

### 📱 平台支持

| 功能 | Android | iOS | 说明 |
|------|---------|-----|------|
| 蓝牙扫描 | ✅ | ✅ | 完全支持 |
| 设备连接 | ✅ | ✅ | 完全支持 |
| 销售 (Sale) | ✅ | ✅ | 完全支持 |
| 退款 (Refund) | ✅ | ✅ | 完全支持 |
| 关联退款 | ✅ | ✅ | 完全支持 |
| 作废 (Void) | ✅ | ✅ | 完全支持 |
| 离线模式 (S&F) | ✅ | ✅ | 完全支持 |
| 状态监听 | ✅ | ✅ | 完全支持 |

## 📦 安装

### 1. 添加依赖

在你的 `pubspec.yaml` 中添加：
```
flutter pub add tripos_mobile
```

添加 `permission_handler` 处理运行时权限

```
flutter pub add permission_handler
```

### 2. Android 配置

#### 2.1 修改 `android/app/build.gradle.kts`

```kotlin
android {
    defaultConfig {
        minSdk = 29  // triPOS SDK 要求最低 Android 10
    }
    
    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/*.kotlin_module"
            )
        }
        jniLibs {
            pickFirsts += "lib/*/libtlvtree.so"
            pickFirsts += "lib/*/libpcltools.so"
        }
    }
}

dependencies {
    // 必须：AppCompat 主题支持（triPOS SDK 需要）
    implementation("androidx.appcompat:appcompat:1.6.1")
    
    // triPOS SDK AAR - 插件已包含这些文件，通过 flatDir 仓库自动解析
    implementation(mapOf("name" to "triposmobilesdk-release", "ext" to "aar"))
    implementation(mapOf("name" to "rba_sdk", "ext" to "aar"))
    implementation(mapOf("name" to "roamreaderunifiedapi-2.5.3.100-release", "ext" to "aar"))
    implementation(mapOf("name" to "retail-types-release-22.01.06.01-0010", "ext" to "aar"))
    implementation(mapOf("name" to "ux-server-release-22.01.06.01-0010", "ext" to "aar"))
    implementation(mapOf("name" to "PclServiceLib_2.21.02", "ext" to "aar"))
    implementation(mapOf("name" to "PclUtilities_2.21.02", "ext" to "aar"))
    implementation(mapOf("name" to "iPclBridge", "ext" to "aar"))
}
```


> **💡 说明**
> 
> - AAR 文件已包含在插件的 `android/libs/` 目录中
> - 插件会自动配置 `flatDir` 仓库，用户无需手动复制 AAR 文件
> - 用户只需在 `build.gradle.kts` 中声明依赖即可

#### 2.2 修改 `android/app/src/main/AndroidManifest.xml`

添加蓝牙权限和 `tools:replace` 配置：

> ⚠️ **重要**：必须添加 `tools:replace="android:label"`，否则会出现 Manifest 合并冲突错误！

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <!-- 👆 修改1：添加了 xmlns:tools -->

    <!-- 修改2：蓝牙权限 -->
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

    <application
        tools:replace="android:label">
        <!-- 👆 修改3：添加了 tools:replace="android:label" -->

    </application>
</manifest>
```

---

### 3. iOS 配置

#### 3.1 系统要求

- iOS 13.0 或更高版本
- Xcode 14.0 或更高版本

#### 3.2 triPOS SDK Framework

> **✅ SDK 已包含在插件中**
> 
> `triPOSMobileSDK.xcframework` 已打包在插件的 `ios/Frameworks/` 目录中，用户无需单独获取。
> 使用 `flutter pub add` 或添加依赖后，运行 `pod install` 即可自动链接。

**安装步骤：**

```bash
# 在你的 Flutter 项目根目录执行
cd ios && pod install
```

> **💡 如需最新版 SDK**
> 
> 如果需要更新 SDK 版本，请联系 [Worldpay](https://www.worldpay.com/) 获取最新的 `triPOSMobileSDK.xcframework`，
> 然后替换插件 `ios/Frameworks/` 目录中的文件。


#### 3.3 修改 `ios/Runner/Info.plist`

添加蓝牙权限说明：

```xml
<dict>
    <!-- 蓝牙权限 -->
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>需要蓝牙权限来连接支付设备</string>
    <key>NSBluetoothPeripheralUsageDescription</key>
    <string>需要蓝牙权限来连接支付设备</string>
    
    <!-- 后台模式（可选：允许后台蓝牙连接）-->
    <key>UIBackgroundModes</key>
    <array>
        <string>bluetooth-central</string>
        <string>bluetooth-peripheral</string>
    </array>
</dict>
```

#### 3.4 Podfile 配置

确保你的 `ios/Podfile` 设置了正确的最低版本：

```ruby
platform :ios, '13.0'

# 如果使用 use_frameworks!，确保添加以下配置
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end
```

## 🚀 快速开始

### 基础使用流程

```dart
import 'package:tripos_mobile/tripos_mobile.dart';

// 1. 创建插件实例
final tripos = TriposMobile();

// 2. 配置 SDK
final config = TriposConfiguration(
  hostConfiguration: HostConfiguration(
    acceptorId: 'your_acceptor_id',     // Worldpay 分配
    accountId: 'your_account_id',        // Worldpay 分配
    accountToken: 'your_account_token',  // Worldpay 分配
  ),
  deviceConfiguration: DeviceConfiguration(
    deviceType: DeviceType.ingenicoMoby5500,
  ),
  applicationConfiguration: ApplicationConfiguration(
    applicationMode: ApplicationMode.testCertification, // 测试环境
    // applicationMode: ApplicationMode.production,     // 生产环境
  ),
);

// 3. 请求蓝牙权限（Android 需要）
await [
  Permission.bluetooth,
  Permission.bluetoothScan,
  Permission.bluetoothConnect,
  Permission.location,
].request();

// 4. 扫描蓝牙设备
final devices = await tripos.scanBluetoothDevices(config);
print('找到设备: $devices');  // 如 ['MOB55-12345']

// 5. 初始化 SDK（连接设备）
final initConfig = config.copyWith(
  deviceConfiguration: config.deviceConfiguration.copyWith(
    identifier: devices.first,  // 选择要连接的设备
  ),
);
await tripos.initialize(initConfig);

// 6. 处理销售
final response = await tripos.processSale(
  SaleRequest(transactionAmount: 10.00),
);

if (response.isApproved) {
  print('交易成功! ID: ${response.host?.transactionId}');
} else {
  print('交易失败: ${response.errorMessage}');
}
```

## 📖 API 文档

### TriposMobile 类

| 方法 | 说明 | 返回值 |
|------|------|--------|
| `scanBluetoothDevices(config)` | 扫描附近的蓝牙支付设备 | `Future<List<String>>` |
| `initialize(config)` | 初始化 SDK 并连接设备 | `Future<bool>` |
| `deinitialize()` | 断开设备并释放资源 | `Future<void>` |
| `isInitialized()` | 检查 SDK 是否已初始化 | `Future<bool>` |
| `processSale(request)` | 处理销售交易 | `Future<SaleResponse>` |
| `processRefund(request)` | 处理退款交易（需刷卡） | `Future<RefundResponse>` |
| `processLinkedRefund(request)` | 处理关联退款（无需刷卡） | `Future<RefundResponse>` |
| `processVoid(request)` | 作废交易 | `Future<VoidResponse>` |
| `cancelTransaction()` | 取消当前进行中的交易 | `Future<void>` |
| `getDeviceInfo()` | 获取已连接设备信息 | `Future<DeviceInfo?>` |
| `statusStream` | 交易状态实时更新 | `Stream<VtpStatus>` |
| `deviceEventStream` | 设备连接事件 | `Stream<DeviceEvent>` |

---

## 📋 配置类详细说明

### TriposConfiguration (主配置)

SDK 的主配置类，组合所有子配置。

| 属性 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `hostConfiguration` | `HostConfiguration` | ✅ | 商户凭证配置 |
| `deviceConfiguration` | `DeviceConfiguration` | ❌ | 设备设置 |
| `transactionConfiguration` | `TransactionConfiguration` | ❌ | 交易设置 |
| `applicationConfiguration` | `ApplicationConfiguration` | ❌ | 应用设置 |
| `storeAndForwardConfiguration` | `StoreAndForwardConfiguration` | ❌ | 离线交易设置 |

---

### HostConfiguration (商户凭证)

商户身份验证相关配置。

| 属性 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `acceptorId` | `String` | ✅ | - | 商户接收方 ID (Worldpay 分配) |
| `accountId` | `String` | ✅ | - | 账户 ID (Worldpay 分配) |
| `accountToken` | `String` | ✅ | - | 账户令牌 (Worldpay 分配) |
| `applicationId` | `String` | ❌ | `'8414'` | 应用 ID |
| `applicationName` | `String` | ❌ | `'triPOS Flutter'` | 应用名称 |
| `applicationVersion` | `String` | ❌ | `'1.0.0'` | 应用版本 |
| `paymentProcessor` | `PaymentProcessor` | ❌ | `worldpay` | 支付处理器 |
| `storeCardId` | `String?` | ❌ | `null` | 卡片存储 ID |
| `storeCardPassword` | `String?` | ❌ | `null` | 卡片存储密码 |
| `vaultId` | `String?` | ❌ | `null` | Vault ID |

---

### DeviceConfiguration (设备设置)

蓝牙支付设备相关配置。

| 属性 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `deviceType` | `DeviceType` | ❌ | `ingenicoMoby5500` | 设备型号 |
| `identifier` | `String?` | ❌ | `null` | 蓝牙设备标识 (如 `'MOB55-12345'`) |
| `terminalId` | `String` | ❌ | `'1234'` | 终端 ID |
| `terminalType` | `TerminalType` | ❌ | `mobile` | 终端类型 |
| `contactlessAllowed` | `bool` | ❌ | `true` | 允许 NFC 非接触式支付 |
| `keyedEntryAllowed` | `bool` | ❌ | `true` | 允许手动输入卡号 |
| `heartbeatEnabled` | `bool` | ❌ | `true` | 启用心跳监测 |
| `barcodeReaderEnabled` | `bool` | ❌ | `true` | 启用条码扫描 |
| `sleepTimeoutSeconds` | `int` | ❌ | `300` | 休眠超时 (秒) |

**DeviceType 枚举值：**
- `ingenicoMoby5500` - Ingenico Moby 5500
- `ingenicoMoby8500` - Ingenico Moby 8500
- `ingenicoLink2500` - Ingenico Link 2500

---

### ApplicationConfiguration (应用设置)

应用运行模式配置。

| 属性 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `applicationMode` | `ApplicationMode` | ❌ | `testCertification` | 运行环境 |
| `idlePrompt` | `String` | ❌ | `'triPOS Flutter'` | 设备空闲时显示文字 |

**ApplicationMode 枚举值：**
- `testCertification` - 测试/认证环境 (不产生真实交易)
- `production` - 生产环境 (⚠️ 真实交易，会扣款!)

---

### TransactionConfiguration (交易设置)

交易处理相关配置。

| 属性 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `emvAllowed` | `bool` | ❌ | `true` | 允许 EMV 芯片卡 |
| `tipAllowed` | `bool` | ❌ | `true` | 允许小费 |
| `tipEntryAllowed` | `bool` | ❌ | `true` | 允许输入小费金额 |
| `tipSelectionType` | `TipSelectionType` | ❌ | `amount` | 小费选择类型 |
| `tipOptions` | `List<double>` | ❌ | `[1.0, 2.0, 3.0]` | 小费选项 |
| `debitAllowed` | `bool` | ❌ | `true` | 允许借记卡 |
| `cashbackAllowed` | `bool` | ❌ | `true` | 允许现金返还 |
| `cashbackEntryAllowed` | `bool` | ❌ | `true` | 允许输入返现金额 |
| `cashbackEntryIncrement` | `int` | ❌ | `5` | 返现增量 |
| `cashbackEntryMaximum` | `int` | ❌ | `100` | 最大返现金额 |
| `cashbackOptions` | `List<double>` | ❌ | `[5.0, 10.0, 15.0]` | 返现选项 |
| `giftCardAllowed` | `bool` | ❌ | `true` | 允许礼品卡 |
| `quickChipAllowed` | `bool` | ❌ | `true` | 允许快速芯片读取 |
| `amountConfirmationEnabled` | `bool` | ❌ | `true` | 需要确认金额 |
| `duplicateTransactionsAllowed` | `bool` | ❌ | `true` | 允许重复交易 |
| `partialApprovalAllowed` | `bool` | ❌ | `false` | 允许部分批准 |
| `currencyCode` | `CurrencyCode` | ❌ | `usd` | 货币代码 |
| `addressVerificationCondition` | `AddressVerificationCondition` | ❌ | `keyed` | 地址验证条件 |

---

### StoreAndForwardConfiguration (离线交易)

Store-and-Forward 离线交易配置。

| 属性 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `storingTransactionsAllowed` | `bool` | ❌ | `true` | 允许存储离线交易 |
| `shouldTransactionsBeAutomaticallyForwarded` | `bool` | ❌ | `true` | 网络恢复后自动转发 |
| `numberOfDaysToRetainProcessedTransactions` | `int` | ❌ | `7` | 已处理交易保留天数 |
| `transactionAmountLimit` | `int` | ❌ | `100` | 单笔离线交易限额 |
| `unprocessedTotalAmountLimit` | `int` | ❌ | `1000` | 未处理交易总限额 |

---

## 📝 请求类详细说明

### SaleRequest (销售请求)

| 属性 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `transactionAmount` | `double` | ✅ | - | 交易金额 |
| `laneNumber` | `String` | ❌ | `'1'` | 收银通道号 |
| `referenceNumber` | `String` | ❌ | `''` | 参考号 (用于追踪) |
| `cardholderPresentCode` | `CardHolderPresentCode` | ❌ | `present` | 持卡人在场状态 |
| `clerkNumber` | `String?` | ❌ | `null` | 收银员编号 |
| `shiftId` | `String?` | ❌ | `null` | 班次 ID |
| `ticketNumber` | `String?` | ❌ | `null` | 小票号 |
| `tipAmount` | `double?` | ❌ | `null` | 小费金额 |
| `salesTaxAmount` | `double?` | ❌ | `null` | 税费金额 |
| `convenienceFeeAmount` | `double?` | ❌ | `null` | 便利费 |
| `surchargeFeeAmount` | `double?` | ❌ | `null` | 附加费 |
| `giftProgramType` | `GiftProgramType?` | ❌ | `null` | 礼品卡类型 |
| `keyedOnly` | `bool` | ❌ | `false` | 仅允许手动输入 |

---

### RefundRequest (退款请求)

需要刷卡/插卡的退款。

| 属性 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `transactionAmount` | `double` | ✅ | - | 退款金额 |
| `laneNumber` | `String` | ❌ | `'1'` | 收银通道号 |
| `referenceNumber` | `String` | ❌ | `''` | 参考号 |
| `cardholderPresentCode` | `CardHolderPresentCode` | ❌ | `present` | 持卡人在场状态 |
| `clerkNumber` | `String?` | ❌ | `null` | 收银员编号 |
| `shiftId` | `String?` | ❌ | `null` | 班次 ID |
| `ticketNumber` | `String?` | ❌ | `null` | 小票号 |
| `salesTaxAmount` | `double?` | ❌ | `null` | 税费金额 |
| `convenienceFeeAmount` | `double?` | ❌ | `null` | 便利费 |
| `giftProgramType` | `GiftProgramType?` | ❌ | `null` | 礼品卡类型 |

---

### LinkedRefundRequest (关联退款)

使用原交易 ID 退款，**无需刷卡**。

| 属性 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `transactionId` | `String` | ✅ | - | 原销售交易 ID |
| `transactionAmount` | `double` | ✅ | - | 退款金额 (可部分退款) |
| `laneNumber` | `String` | ❌ | `'1'` | 收银通道号 |
| `referenceNumber` | `String` | ❌ | `''` | 参考号 |
| `clerkNumber` | `String?` | ❌ | `null` | 收银员编号 |
| `shiftId` | `String?` | ❌ | `null` | 班次 ID |

---

### VoidRequest (作废请求)

取消/作废已完成的交易。

| 属性 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `transactionId` | `String` | ✅ | - | 要作废的交易 ID |
| `transactionAmount` | `double` | ✅ | - | 交易金额 |
| `laneNumber` | `String` | ❌ | `'1'` | 收银通道号 |
| `referenceNumber` | `String` | ❌ | `''` | 参考号 |
| `marketCode` | `MarketCode` | ❌ | `retail` | 市场代码 |
| `clerkNumber` | `String?` | ❌ | `null` | 收银员编号 |
| `shiftId` | `String?` | ❌ | `null` | 班次 ID |
| `ticketNumber` | `String?` | ❌ | `null` | 小票号 |
| `cardholderPresentCode` | `CardHolderPresentCode` | ❌ | `present` | 持卡人状态 |

---

## 📤 响应类详细说明

### SaleResponse / RefundResponse

| 属性 | 类型 | 说明 |
|------|------|------|
| `isApproved` | `bool` | 交易是否批准 |
| `transactionStatus` | `TransactionStatus` | 交易状态枚举 |
| `approvedAmount` | `double?` | 批准金额 |
| `errorMessage` | `String?` | 错误信息 |
| `referenceNumber` | `String?` | 参考号 |
| `storedTransactionId` | `String?` | 存储的离线交易 ID |
| `isStoredTransaction` | `bool` | 是否为离线存储交易 |
| `host` | `HostResponse?` | 主机响应信息 |
| `card` | `CardInfo?` | 卡片信息 |
| `emv` | `EmvInfo?` | EMV 芯片卡信息 |

### HostResponse

| 属性 | 类型 | 说明 |
|------|------|------|
| `transactionId` | `String?` | 交易 ID (用于退款/作废) |
| `authCode` | `String?` | 授权码 |
| `responseCode` | `String?` | 响应代码 |
| `responseMessage` | `String?` | 响应消息 |

### CardInfo

| 属性 | 类型 | 说明 |
|------|------|------|
| `maskedCardNumber` | `String?` | 脱敏卡号 (如 `****1234`) |
| `cardType` | `CardType?` | 卡片类型 (Visa/Mastercard 等) |
| `entryMode` | `EntryMode?` | 输入方式 (刷卡/插卡/NFC) |

---

## 📡 监听交易状态

### VtpStatus 枚举

`statusStream` 返回 `VtpStatus` 枚举，可以使用 `switch` 语句处理不同状态：

```dart
// 监听交易进度 (使用 VtpStatus 枚举)
tripos.statusStream.listen((status) {
  switch (status) {
    case VtpStatus.gettingCardInputTapInsertSwipe:
      print('请刷卡/插卡/NFC');
    case VtpStatus.processingCardInput:
      print('正在处理卡片...');
    case VtpStatus.sendingToHost:
      print('正在发送到主机...');
    case VtpStatus.transactionProcessing:
      print('交易处理中...');
    case VtpStatus.finalizing:
      print('正在最终处理...');
    default:
      print('状态: ${status.name}');
  }
});
```

### VtpStatus 常用枚举值

#### 交易运行状态
| 枚举值 | 说明 |
|--------|------|
| `runningSale` | 正在执行销售交易 |
| `runningRefund` | 正在执行退款交易 |
| `runningVoid` | 正在执行作废交易 |
| `runningAuthorization` | 正在执行授权交易 |
| `runningReturn` | 正在执行退货交易 |

#### 卡片输入状态
| 枚举值 | 说明 |
|--------|------|
| `gettingCardInput` | 等待刷卡/插卡 |
| `gettingCardInputTapInsertSwipe` | 等待刷卡/插卡/NFC |
| `gettingCardInputSwipe` | 等待刷卡 |
| `processingCardInput` | 正在处理卡片输入 |

#### 交易处理状态
| 枚举值 | 说明 |
|--------|------|
| `sendingToHost` | 正在发送到主机 |
| `transactionProcessing` | 交易处理中 |
| `gettingContinuingEmvTransaction` | 继续 EMV 交易 |
| `gettingFinalizingEmvTransaction` | 正在完成 EMV 交易 |
| `finalizing` | 正在最终处理 |

#### PIN 码状态
| 枚举值 | 说明 |
|--------|------|
| `gettingPin` | 等待输入 PIN 码 |
| `pinOK` | PIN 码正确 |
| `reEnterPin` | 请重新输入 PIN 码 |
| `pinEnteredSuccessfully` | PIN 码输入成功 |
| `pinEntryCancelled` | PIN 码输入已取消 |

#### 卡片状态
| 枚举值 | 说明 |
|--------|------|
| `removeCard` | 请移除卡片 |
| `cardRemoved` | 卡片已移除 |
| `chipReadFailed` | 芯片读取失败 |
| `swipeReadFailed` | 刷卡读取失败 |

#### 交易结果状态
| 枚举值 | 说明 |
|--------|------|
| `transactionCancelled` | 交易已取消 |
| `none` | 无状态/空闲 |

> 完整枚举列表请参考 [lib/models/enums.dart](lib/models/enums.dart) 中的 `VtpStatus` 定义。

### 监听设备连接事件

```dart
// 监听设备连接（类型安全的枚举方式）
tripos.deviceEventStream.listen((event) {
  switch (event.type) {
    case DeviceEventType.connecting:
      print('正在连接设备...');
    case DeviceEventType.connected:
      print('设备已连接: ${event.model}');
    case DeviceEventType.disconnected:
      print('设备已断开');
    case DeviceEventType.error:
      print('设备错误: ${event.message}');
    case DeviceEventType.ready:
      print('设备已就绪');
    case DeviceEventType.unknown:
      break;
  }
});
```

**DeviceEventType 枚举值：**

| 枚举值 | 说明 |
|--------|------|
| `connecting` | 正在连接设备 |
| `connected` | 设备已连接 |
| `disconnected` | 设备已断开 |
| `error` | 设备发生错误 |
| `ready` | 设备已就绪（可以进行交易） |
| `unknown` | 未知事件类型 |

**DeviceEvent 属性：**

| 属性 | 类型 | 说明 |
|------|------|------|
| `type` | `DeviceEventType` | 事件类型枚举 |
| `model` | `String?` | 设备型号 |
| `serialNumber` | `String?` | 设备序列号 |
| `firmwareVersion` | `String?` | 固件版本 |
| `message` | `String?` | 错误信息 |

## 💡 完整示例

查看 [example/lib/main.dart](example/lib/main.dart) 获取完整的示例应用。

示例应用包含：
- 设备扫描和连接界面
- 销售、退款、作废操作
- 交易结果展示
- 错误处理

## 🔧 故障排除

### Android

#### 1. 设备扫描找不到设备

- 确保设备已开机并处于可发现状态
- 检查蓝牙和位置权限是否已授予
- Android 10+ 需要位置权限才能扫描蓝牙

#### 2. 初始化失败

- 确认 `identifier` 已正确设置为扫描到的设备名称
- 检查 `minSdk` 是否设置为 29 或更高
- 查看 Logcat 中 `TriposMobilePlugin` 标签的日志

#### 3. 交易失败返回 "Invalid AccountToken"

- 确认 `applicationMode` 与凭证环境匹配：
  - 测试凭证 → `ApplicationMode.testCertification`
  - 生产凭证 → `ApplicationMode.production`

#### 4. 首次刷卡无响应

- SDK 初始化后设备需要稳定时间
- 插件已内置 2 秒延迟，如仍有问题可稍等后重试

---

### iOS

#### 1. 设备扫描找不到设备

- 确保 `Info.plist` 中已添加蓝牙权限说明
- 在 iOS 设置中确认 App 已获得蓝牙权限
- 确保设备已开机并在可发现模式

#### 2. 编译错误：找不到 triPOSMobileSDK

- 运行 `cd ios && pod install --repo-update`
- 确认 `triPOSMobileSDK.xcframework` 在 `ios/Frameworks/` 目录中
- 检查 Podspec 中 `vendored_frameworks` 路径是否正确

#### 3. 离线交易显示 DECLINED

- 确认 Store-and-Forward 配置正确：
  ```dart
  storeAndForwardConfiguration: StoreAndForwardConfiguration(
    storingTransactionsAllowed: true,
  ),
  ```
- 离线交易会返回 `transactionStatus: approvedByMerchant`
- 检查 `isApproved` 应为 `true`

#### 4. 连接设备后交易超时

- 确保蓝牙连接稳定
- 检查设备电量
- 尝试重新初始化 SDK

#### 5. 签名问题 (Code Signing)

- 确保 `triPOSMobileSDK.xcframework` 设置为 "Embed & Sign"
- 检查 Build Settings 中 `CODE_SIGN_IDENTITY` 设置


## 📄 许可证

本插件基于 Worldpay triPOS Mobile SDK 开发，使用需遵守 Worldpay 的许可协议。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！
