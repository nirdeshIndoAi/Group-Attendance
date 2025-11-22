Pod::Spec.new do |s|
  s.name             = 'face_recognition_sdk'
  s.version          = '1.0.0'
  s.summary          = 'Native bridge for the face recognition SDK.'
  s.description      = <<-DESC
                      Provides native implementations for secure face template comparison and license validation.
                       DESC
  s.homepage         = 'https://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'GroupAttendance' => 'sdk@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform     = :ios, '12.0'
  s.swift_version = '5.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
  s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end

