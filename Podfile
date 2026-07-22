platform :ios, '15.0'

install! 'cocoapods', :deterministic_uuids => true

target 'iPxavno' do
  # Overseas data region. Use SolarEngineSDK for mainland-China products.
  pod 'SolarEngineSDKiOSInter', '~> 1.3.2'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
    end
  end
end
