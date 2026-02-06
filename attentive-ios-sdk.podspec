#
# Be sure to run `pod lib lint attentive-ios-sdk.podspec' to ensure this is a
# valid spec before submitting.

Pod::Spec.new do |s|
  s.name             = 'attentive-ios-sdk'
  s.version          = File.read(File.join(__dir__, '.version')).strip
  s.summary          = 'Attentive IOS SDK'

  s.description      = <<-DESC
The Attentive IOS SDK provides the functionality to render Attentive signup units in iOS mobile applications.
                       DESC

  s.homepage         = 'https://www.attentive.com/demo?utm_source=cocoapods.org'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Ivan Loughman-Pawelko' => 'iloughman@attentivemobile.com' }
  s.source           = { :git => 'https://github.com/attentive-mobile/attentive-ios-sdk.git', :tag => s.version.to_s }

  s.ios.deployment_target = File.read(File.join(__dir__, '.ios-deployment-target')).strip
  s.swift_versions = ['5']
  s.source_files = 'Sources/**/*.swift', 'Objc/**/*'
  s.resource_bundles = {'attentive-ios-sdk' => ['Sources/Resources/PrivacyInfo.xcprivacy']}

  s.deprecated = true
  s.deprecated_in_favor_of = 'ATTNSDKFramework'
end
