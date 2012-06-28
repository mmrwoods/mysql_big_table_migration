require File.dirname(__FILE__) + '/test_helper.rb'

class MysqlBigTableMigrationTest < Test::Unit::TestCase
  extend DatabaseTest
  
  test_against_all_configs :methods_are_added_to_migration do
    MySQLBigTableMigration::ClassMethods.instance_methods(false).each do |method|
      assert_respond_to ActiveRecord::Migration, method
    end
  end

  test_against_all_configs :with_tmp_table_creates_tmp_table do
    silence_stream($stdout) do
      ActiveRecord::Migration.send(:with_tmp_table, :test_table) {}
    end
    assert_match "CREATE TABLE tmp_new_test_table LIKE test_table", read_log_file
  end

  test_against_all_configs :add_column_using_tmp_table do
    silence_stream($stdout) do
      ActiveRecord::Migration.add_column_using_tmp_table(:test_table, :baz, :string)
    end

    fields = result_hashes(connection.execute("DESCRIBE test_table"))
    assert_equal 4, fields.length
    assert_equal "baz", fields[3]["Field"]
    assert_equal "varchar(255)", fields[3]["Type"]

    results = result_hashes(connection.execute("SELECT * FROM test_table"))
    assert_equal 5, results.length
    assert_equal "foo2", results[2]["foo"]
    assert_equal "bar3", results[3]["bar"]
    assert_equal nil, results[4]["baz"]
  end

  test_against_all_configs :remove_column_using_tmp_table do
    silence_stream($stdout) do
      ActiveRecord::Migration.remove_column_using_tmp_table(:test_table, :bar)
    end

    fields = result_hashes(connection.execute("DESCRIBE test_table"))
    assert_equal 2, fields.length
    assert_equal "id", fields[0]["Field"]
    assert_equal "foo", fields[1]["Field"]

    results = result_hashes(connection.execute("SELECT * FROM test_table"))
    assert_equal 5, results.length
    assert_equal "foo2", results[2]["foo"]
    assert !results[3].has_key?("bar")
  end

  test_against_all_configs :change_column_using_tmp_table do
    silence_stream($stdout) do
      ActiveRecord::Migration.change_column_using_tmp_table(:test_table, :bar, :text)
    end

    fields = result_hashes(connection.execute("DESCRIBE test_table"))
    assert_equal 3, fields.length
    assert_equal "id", fields[0]["Field"]
    assert_equal "foo", fields[1]["Field"]
    assert_equal "bar", fields[2]["Field"]
    assert_equal "text", fields[2]["Type"]

    results = result_hashes(connection.execute("SELECT * FROM test_table"))
    assert_equal 5, results.length
    assert_equal "foo2", results[2]["foo"]
    assert_equal "bar3", results[3]["bar"]
  end

  test_against_all_configs :add_index_using_tmp_table do
    silence_stream($stdout) do
      ActiveRecord::Migration.add_index_using_tmp_table(:test_table, :bar)
    end

    indexes = result_hashes(connection.execute("SHOW INDEX FROM test_table"))
    assert_equal 3, indexes.length
    assert_equal "id", indexes[0]["Column_name"]
    assert_equal "foo", indexes[1]["Column_name"]
    assert_equal "bar", indexes[2]["Column_name"]
  end

  test_against_all_configs :remove_index_using_tmp_table do
    silence_stream($stdout) do
      ActiveRecord::Migration.remove_index_using_tmp_table(:test_table, :foo)
    end

    indexes = result_hashes(connection.execute("SHOW INDEX FROM test_table"))
    assert_equal 1, indexes.length
    assert_equal "id", indexes[0]["Column_name"]
  end

end
