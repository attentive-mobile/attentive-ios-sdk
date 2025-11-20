source "https://rubygems.org"

ruby "~> 3.3"

gem "fastlane", "~> 2.217"
gem "cocoapods", "~> 1.14"

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
