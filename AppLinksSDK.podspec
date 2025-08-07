Pod::Spec.new do |spec|
  spec.name             = 'AppLinksSDK'
  spec.version          = '1.0.8'
  spec.summary          = 'iOS SDK for deferred deep linking using clipboard-based attribution'
  spec.description      = <<-DESC
    AppLinksSDK provides deferred deep linking functionality for iOS apps.
    It handles universal links, custom URL schemes, and retrieves deferred
    deep links when users install the app from a link using clipboard-based
    attribution.
  DESC
  
  spec.homepage         = 'https://github.com/ApplinksDev/applinks-sdk-ios'
  spec.license          = { :type => 'MIT', :file => 'LICENSE' }
  spec.author           = { 'Maxence Henneron' => 'maxence@appsent.com' }
  spec.source           = { :git => 'https://github.com/ApplinksDev/applinks-sdk-ios.git', :tag => spec.version.to_s }

  spec.ios.deployment_target = '14.0'
  spec.swift_version = '5.7'
  
  spec.source_files = 'AppLinksSDK/Sources/AppLinksSDK/**/*.swift'
  
  spec.frameworks = 'UIKit', 'Foundation'
  
  spec.requires_arc = true
end