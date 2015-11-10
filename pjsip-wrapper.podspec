Pod::Spec.new do |s|
  s.name         = "pjsip-wrapper"
  s.version      = "0.0.1"
  s.summary      = "PJSUA wrapper for PJSIP"
  s.homepage     = "http://www.pjsip.org"
  s.license      = { :type => 'MIT' }
  s.author       = { "Jonathan Tribouharet" => "jonathan.tribouharet@gmail.com" }
  s.platform     = :ios, '7.0'
  s.source       = { :git => "https://git.budist.ru/modules/pjsip-wrapper.git", :tag => s.version.to_s }
  s.source_files  = 'WAPjsua/*'
  s.requires_arc = true
  s.dependency            'pjsip', :git => 'https://git.budist.ru/modules/pjsip.git'
end