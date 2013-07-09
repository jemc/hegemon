Gem::Specification.new do |s|
  s.name          = 'hegemon'
  s.version       = '0.0.4'
  s.date          = '2013-07-07'
  s.summary       = "hegemon"
  s.description   = \
"A generic Ruby state machine pattern, with thread safety as a top priority."+\
"Make your object a hegemon, in complete control of its states."
    
  s.authors       = ["Joe McIlvain"]
  s.email         = 'joe.eli.mac@gmail.com'
  s.files         = Dir["{lib}/**/*.rb", "bin/*", "LICENSE", "*.md"]
  s.require_path  = 'lib'
  s.homepage      = 'https://github.com/jemc/gegemon/'
  s.licenses      = ["MIT License",
                     "Copyright 2013 Joe McIlvain"]
  
  s.add_dependency('threadlock', '~> 1.2')
end