$LOAD_PATH.unshift 'lib'

Gem::Specification.new do |s|
  s.name              = "mysql_big_table_migration"
  s.version           = "0.0.2"
  s.date              = Time.now.strftime('%Y-%m-%d')
  s.summary           = "allow columns and indexes to be added to and removed from large tables"
  s.homepage          = "http://github.com/analog-analytics/mysql_big_table_migration"
  s.email             = "engineering@analoganalytics.com"
  s.authors           = [ "Mark Woods" ]
  s.has_rdoc          = false

  s.files             = %w( README.md Rakefile LICENSE )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("bin/**/*")
  s.files            += Dir.glob("man/**/*")
  s.files            += Dir.glob("test/**/*")

  s.description       = <<desc
  A Rails plugin that adds methods to ActiveRecord::Migration to allow columns 
  and indexes to be added to and removed from large tables with millions of
  rows in MySQL, without leaving processes seemingly stalled in state "copy
  to tmp table".
desc
end
