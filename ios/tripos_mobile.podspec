#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint tripos_mobile.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'tripos_mobile'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for Worldpay triPOS Mobile SDK'
  s.description      = <<-DESC
Flutter plugin for payment processing using Worldpay triPOS Mobile SDK.
Supports Ingenico Moby/RBA devices via Bluetooth.
                       DESC
  s.homepage         = 'https://github.com/example/tripos_mobile'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # triPOS Mobile SDK framework
  s.vendored_frameworks = 'Frameworks/triPOSMobileSDK.xcframework'
  
  # Build settings
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-ObjC'
  }
  s.swift_version = '5.0'

  # Privacy manifest if needed
  # s.resource_bundles = {'tripos_mobile_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
