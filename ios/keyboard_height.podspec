Pod::Spec.new do |s|
  s.name             = 'keyboard_height'
  s.version          = '1.0.0'
  s.summary          = 'Keyboard height'
  s.description      = <<-DESC
A simple plugin that streams keyboard height changes.
                       DESC
  s.homepage         = 'https://swipelab.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Alexandru R. Agrapine' => 'agra@swipelab.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'
  s.swift_version = '5.0'
end
