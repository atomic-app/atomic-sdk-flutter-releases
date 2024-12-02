Pod::Spec.new do |s|
  s.name             = 'atomic_sdk_flutter'
  s.version          = '1.0.0'
  s.summary          = 'Atomic SDK for Flutter (iOS and Android).'
  s.description      = <<-DESC
  Atomic SDK for Flutter (iOS and Android).
                       DESC
  s.homepage         = 'https://atomic.io'
  s.license          = { :type => 'Commercial', :text => ' ' }
  s.authors          = 'Atomic.io Limited'
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'AtomicSDK', '24.2.5' # comment out '24.2.5' when switching to beta branch.
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }

  # Privacy Manifest file (copied from https://github.com/atomic-app/action-cards-ios-sdk/blob/develop/ActionCardsSDK/ActionCardsSDK/PrivacyInfo.xcprivacy)
  s.resource_bundles = {'atomic_sdk_flutter_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end