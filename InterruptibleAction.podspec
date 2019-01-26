Pod::Spec.new do |s|
  s.name             = 'InterruptibleAction'
  s.version          = '0.9.0'
  s.summary          = 'A short description of InterruptibleAction.'

  s.description      = <<-DESC
A thin wrapper on top of Action that enables the interruption of the inner action.
                       DESC

  s.homepage         = 'https://github.com/gkaimakas/InterruptibleAction'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'George Kaiakas' => 'gkaimakas@gmail.com' }
  s.source           = { :git => 'https://github.com/gkaimakas/InterruptibleAction.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'

  s.source_files = 'InterruptibleAction/Classes/**/*'
  s.dependency 'ReactiveSwift'
end
