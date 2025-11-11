Pod::Spec.new do |s|
  s.name             = 'keyboard_height'
  s.version          = '1.0.7'
  s.summary          = 'Keyboard Height'
  s.description      = <<-DESC
Keyboard Height
                       DESC
  s.homepage         = 'http://swipelab.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Alexandru R. Agrapine' => 'agra@swipelab.com' }

  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'

  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end


