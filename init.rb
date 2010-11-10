require 'mysql_big_table_migration'

class ActiveRecord::Migration
  include MySQLBigTableMigration
end