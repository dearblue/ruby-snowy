verreg = /^\s*\*\s+version:\s*(\d+(?:\.\w+)+)\s*$/i
unless File.read("README.md", mode: "rt") =~ verreg
  raise "``version'' is not defined or bad syntax in ``README.md''"
end

version = String($1)

GEMSTUB = Gem::Specification.new do |s|
  s.name = "snowy"
  s.version = version
  s.summary = "an identicon implements"
  s.description = <<EOS
Pure ruby identicon implement with the snow crystal motif
EOS
  s.homepage = "https://github.com/dearblue/ruby-snowy/"
  s.license = "BSD-2-Clause"
  s.author = "dearblue"
  s.email = "dearblue@users.noreply.github.com"

  #s.required_ruby_version = ">= 2.1"
  s.add_development_dependency "rake", "~> 11"
end

EXTRA << "snowy-demo.png"
EXTRA << "snowy-demo.rb"
