Pod::Spec.new do |s|
    s.name             = "CoreDataExtensio"
    s.version          = "1.0.9"
    s.summary          = "Rx Extension for CoreData used by @gekitz"
    s.license          = "MIT"
    s.author           = { "Georg Kitz" => "georgkitz@gmail.com" }
    s.source           = { :git => "https://github.com/gekitz/CoreDataExtensio", :tag => s.version }
    s.homepage         = "http://www.georgkitz.com"
  
    s.platform     = :ios, '10.0'
    s.requires_arc = true
  
    s.source_files = 'CoreDataExtensio/Files'
  
    s.frameworks = 'CoreData'
    s.module_name = 'CoreDataExtensio'
  
    s.dependency 'RxSwift', '~>4.0'
    s.dependency 'RxCocoa', '~> 4.0'
    s.dependency 'RxOptional', '~> 3.2'
  end