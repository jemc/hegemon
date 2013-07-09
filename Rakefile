require 'rake/testtask'
require 'rdoc/task'

task :default => [:docv]

gemname = "hegemon"

# Generate documentation.
RDoc::Task.new :doc do |rd|
  rd.rdoc_dir = 'doc'
  rd.rdoc_files.include 'lib/**/*.rb'
end

# Generate documentation and view.
task :docv => [:doc] do
  exec "xdg-open ./doc/Hegemon.html"
end

# Rebuild gem
task :g do exec "
rm #{gemname}*.gem
gem uninstall #{gemname} -a
gem build #{gemname}.gemspec
gem install #{gemname}*.gem" end

# Rebuild and push gem
task :gp do exec "
rm #{gemname}*.gem
gem uninstall #{gemname} -a
gem build #{gemname}.gemspec
gem install #{gemname}*.gem
gem push #{gemname}*.gem" end