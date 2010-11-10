ENV['RAILS_ENV'] = 'test'
ENV['RAILS_ROOT'] ||= File.dirname(__FILE__) + '/../../../..'

require 'fileutils'
require 'test/unit'
require File.expand_path(File.join(ENV['RAILS_ROOT'], 'config/environment.rb'))
  
def log_file
  File.dirname(__FILE__) + "/debug.log"
end

def read_log_file
  IO.read(log_file)
end

def clear_log_file
  FileUtils.rm_f(log_file)
end

def load_schema
  config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
  ActiveRecord::Base.logger = Logger.new(log_file)
  ActiveRecord::Base.establish_connection(config['mysql'])
  load(File.dirname(__FILE__) + "/schema.rb")
end
