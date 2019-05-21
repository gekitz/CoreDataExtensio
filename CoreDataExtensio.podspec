Pod::Spec.new do |s|
    s.name             = "CoreDataExtensio"
    s.version          = "2.0.8"
    s.summary          = "Rx Extension for CoreData used by @gekitz"
    s.license          = "MIT"
    s.author           = { "Georg Kitz" => "georgkitz@gmail.com" }
    s.source           = { :git => "https://github.com/gekitz/CoreDataExtensio", :tag => s.version }
    s.homepage         = "http://www.georgkitz.com"
    s.swift_version    = '5.0'
  
    s.platform     = :ios, '11.1'
    s.requires_arc = true
  
    s.source_files = 'CoreDataExtensio/Files'
  
    s.frameworks = 'CoreData'
    s.module_name = 'CoreDataExtensio'
  
    s.dependency 'RxSwift', '~> 5.0.0'
    s.dependency 'RxCocoa', '~> 5.0.0'
    s.dependency 'RxOptional', '~> 4.0.0'
  end
