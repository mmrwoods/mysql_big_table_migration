require File.dirname(__FILE__) + '/test_helper.rb'

# TODO: finish me

class MysqlBigTableMigrationTest < Test::Unit::TestCase

  clear_log_file
  load_schema
  
  def test_methods_are_added_to_migration
    MySQLBigTableMigration::ClassMethods.instance_methods(false).each do |method|
      assert_respond_to ActiveRecord::Migration, method
    end
  end

  def test_with_tmp_table_creates_tmp_table
    silence_stream($stdout) do
      ActiveRecord::Migration.send(:with_tmp_table, 'test_table') {|x| puts x}
    end
    assert_match "CREATE TABLE tmp_new_test_table LIKE test_table", read_log_file
  end

end
