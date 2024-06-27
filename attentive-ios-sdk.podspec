#
# Be sure to run `pod lib lint attentive-ios-sdk.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'attentive-ios-sdk'
  s.version          = '1.0.0-beta.1'
  s.summary          = 'Attentive IOS SDK'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
The Attentive IOS SDK provides the functionality to render Attentive signup units in iOS mobile applications.
                       DESC

  s.homepage         = 'https://www.attentive.com/demo?utm_source=cocoapods.org'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Ivan Loughman-Pawelko' => 'iloughman@attentivemobile.com' }
  s.source           = { :git => 'https://github.com/attentive-mobile/attentive-ios-sdk.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '14.0'

  s.source_files = 'Sources/**/*.swift', 'Objc/**/*'

  s.resource_bundles = {'attentive-ios-sdk' => ['Sources/Resources/PrivacyInfo.xcprivacy']}

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'

  s.deprecated = true
  s.deprecated_in_favor_of = 'ATTNSDKFramework'
end
