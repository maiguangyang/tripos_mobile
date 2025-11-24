#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint tripos_mobile.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'tripos_mobile'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project for triPOS.'
  s.description      = <<-DESC
A new Flutter plugin project integrating Worldpay triPOS Mobile SDK.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  
  # 修改 1: 提高最低 iOS 版本要求
  # 根据 triPOS SDK 文档 (Overview 章节)，支持 iOS 14+
  s.platform = :ios, '14.0'

  # Swift 版本
  s.swift_version = '5.0'

  # ----------------------------------------------------------
  # ↓↓↓↓↓↓ 核心配置区域 (根据你的文件结构) ↓↓↓↓↓↓
  # ----------------------------------------------------------

  # 修改 2: 引入 XCFramework
  # 注意：你截图里是 .xcframework，不是 .framework
  # 路径基于：ios/Frameworks/triPOSMobileSDK.xcframework
  s.vendored_frameworks = 'Frameworks/triPOSMobileSDK.xcframework'

  # 修改 3: 引入固件资源文件
  # 路径基于：ios/Resources/ (你需要把固件 .OGZ/.uns 文件放进去)
  # 这些文件会被复制到 App 的 Main Bundle，SDK 初始化时需要读取
  s.resources = 'Resources/**/*'

  # 修改 4: 保持路径防止被 CocoaPods 清理
  s.preserve_paths = 'Frameworks/triPOSMobileSDK.xcframework'

  # 修改 5: 链接设置
  # 确保 Xcode 知道要链接 triPOSMobileSDK
  s.xcconfig = { 
    'OTHER_LDFLAGS' => '-framework triPOSMobileSDK'
  }

  # ----------------------------------------------------------
  # ↑↑↑↑↑↑ 结束配置 ↑↑↑↑↑↑
  # ----------------------------------------------------------

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end