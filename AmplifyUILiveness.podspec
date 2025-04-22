Pod::Spec.new do |s|
  s.name         = 'AmplifyUILiveness'
  s.version      = '1.0.0'
  s.summary      = 'AWS Amplify UI Liveness module'
  s.homepage     = 'https://github.com/aws-amplify/amplify-ui-swift-liveness'
  s.license      = { :type => 'Apache 2.0', :file => 'LICENSE' }
  s.author       = { 'AWS Amplify' => 'aws-amplify@amazon.com' }
  s.source       = { :git => 'https://github.com/guamacard/amplify-ui-swift-liveness.git', :branch => 'main' }
  s.ios.deployment_target = '13.0'
  s.source_files  = 'Sources/**/*.{swift,h,m}'
  s.swift_version = '5.0'
end