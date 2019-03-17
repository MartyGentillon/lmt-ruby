
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "lmt/version"

Gem::Specification.new do |spec|
  spec.name          = "lmt"
  spec.license       = "MIT"
  spec.version       = Lmt::VERSION
  spec.authors       = ["Marty Gentillon"]
  spec.email         = ["marty.gentillon+lmt-ruby@gmail.com"]

  spec.summary       = %q{A literate tangler written in Ruby for use with MarkDown.}
  spec.description   = %q{A literate tangler written in Ruby for use with MarkDown.}
  spec.homepage      = "https://github.com/MartyGentillon/lmt-ruby"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "bin"
  spec.executables   = ["lmt", "lmw"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency('rdoc')
  spec.add_development_dependency('pry')
  spec.add_dependency('methadone', '~> 1.9.5')
  spec.add_development_dependency('test-unit')
end
