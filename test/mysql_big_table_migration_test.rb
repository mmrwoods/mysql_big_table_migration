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

    fields = test_table_fields
    assert_equal 4, fields.length
    assert_equal "baz", fields[3]["Field"]
    assert_equal "varchar(255)", fields[3]["Type"]

    results = test_table_rows
    assert_equal 5, results.length
    assert_equal "foo2", results[2]["foo"]
    assert_equal "bar3", results[3]["bar"]
    assert_equal nil, results[4]["baz"]
  end

  test_against_all_configs :remove_column_using_tmp_table do
    silence_stream($stdout) do
      ActiveRecord::Migration.remove_column_using_tmp_table(:test_table, :bar)
    end

    fields = test_table_fields
    assert_equal 2, fields.length
    assert_equal "id", fields[0]["Field"]
    assert_equal "foo", fields[1]["Field"]

    results = test_table_rows
    assert_equal 5, results.length
    assert_equal "foo2", results[2]["foo"]
    assert !results[3].has_key?("bar")
  end

  test_against_all_configs :rename_column_using_tmp_table do
    silence_stream($stdout) do
      ActiveRecord::Migration.rename_column_using_tmp_table(:test_table, :foo, :baz)
    end

    fields = test_table_fields
    assert_equal 3, fields.length
    assert_equal "id", fields[0]["Field"]
    assert_equal "int(11)", fields[0]["Type"]
    assert_equal "baz", fields[1]["Field"]
    assert_equal "varchar(255)", fields[1]["Type"]
    assert_equal "bar", fields[2]["Field"]
    assert_equal "varchar(255)", fields[2]["Type"]

    results = test_table_rows
    assert_equal 5, results.length
    5.times do |i|
      assert_equal "foo#{i}", results[i]["baz"]
      assert_equal "bar#{i}", results[i]["bar"]
    end
  end

  test_against_all_configs :change_column_using_tmp_table do
    silence_stream($stdout) do
      ActiveRecord::Migration.change_column_using_tmp_table(:test_table, :bar, :text)
    end

    fields = test_table_fields
    assert_equal 3, fields.length
    assert_equal "id", fields[0]["Field"]
    assert_equal "foo", fields[1]["Field"]
    assert_equal "bar", fields[2]["Field"]
    assert_equal "text", fields[2]["Type"]

    results = test_table_rows
    assert_equal 5, results.length
    assert_equal "foo2", results[2]["foo"]
    assert_equal "bar3", results[3]["bar"]
  end

  test_against_all_configs :add_index_using_tmp_table do
    silence_stream($stdout) do
      ActiveRecord::Migration.add_index_using_tmp_table(:test_table, :bar)
    end

    indexes = result_hashes("SHOW INDEX FROM test_table")
    assert_equal 3, indexes.length
    assert_equal "id", indexes[0]["Column_name"]
    assert_equal "foo", indexes[1]["Column_name"]
    assert_equal "bar", indexes[2]["Column_name"]
  end

  test_against_all_configs :remove_index_using_tmp_table do
    silence_stream($stdout) do
      ActiveRecord::Migration.remove_index_using_tmp_table(:test_table, :foo)
    end

    indexes = result_hashes("SHOW INDEX FROM test_table")
    assert_equal 1, indexes.length
    assert_equal "id", indexes[0]["Column_name"]
  end

  test_against_all_configs :rename_with_remove do
    silence_stream($stdout) do
      ActiveRecord::Migration.with_tmp_table(:test_table) do |tmp_table_name|
        ActiveRecord::Migration.rename_column tmp_table_name, :bar, :baz
        ActiveRecord::Migration.remove_column tmp_table_name, :foo
      end
    end

    fields = test_table_fields
    assert_equal 2, fields.length
    assert_equal "id", fields[0]["Field"]
    assert_equal "baz", fields[1]["Field"]

    results = test_table_rows
    assert_equal 5, results.length
    5.times do |i|
      assert_equal "bar#{i}", results[i]["baz"]
    end
  end

  test_against_all_configs :rename_with_add do
    silence_stream($stdout) do
      ActiveRecord::Migration.with_tmp_table(:test_table) do |tmp_table_name|
        ActiveRecord::Migration.rename_column tmp_table_name, :bar, :baz
        ActiveRecord::Migration.add_column tmp_table_name, :dummy, :integer
      end
    end

    fields = test_table_fields
    assert_equal 4, fields.length
    assert_equal "id", fields[0]["Field"]
    assert_equal "foo", fields[1]["Field"]
    assert_equal "baz", fields[2]["Field"]
    assert_equal "dummy", fields[3]["Field"]

    results = test_table_rows
    assert_equal 5, results.length
    5.times do |i|
      assert_equal "foo#{i}", results[i]["foo"]
      assert_equal "bar#{i}", results[i]["baz"]
      assert_equal nil, results[i]["dummy"]
    end
  end

  test_against_all_configs :rename_with_change do
    silence_stream($stdout) do
      ActiveRecord::Migration.with_tmp_table(:test_table) do |tmp_table_name|
        ActiveRecord::Migration.rename_column tmp_table_name, :bar, :baz
        ActiveRecord::Migration.change_column tmp_table_name, :foo, :integer
      end
    end

    fields = test_table_fields
    assert_equal 3, fields.length
    assert_equal "id", fields[0]["Field"]
    assert_equal "foo", fields[1]["Field"]
    assert_equal "int(11)", fields[1]["Type"]
    assert_equal "baz", fields[2]["Field"]

    results = test_table_rows
    assert_equal 5, results.length
    5.times do |i|
      assert results[i]["foo"] == "0" || results[i]["foo"] == 0
      assert_equal "bar#{i}", results[i]["baz"]
    end
  end

  test_against_all_configs :rename_with_rename do
    silence_stream($stdout) do
      ActiveRecord::Migration.with_tmp_table(:test_table) do |tmp_table_name|
        ActiveRecord::Migration.rename_column tmp_table_name, :bar, :baz
        ActiveRecord::Migration.rename_column tmp_table_name, :foo, :dummy
      end
    end

    fields = test_table_fields
    assert_equal 3, fields.length
    assert_equal "id", fields[0]["Field"]
    assert_equal "dummy", fields[1]["Field"]
    assert_equal "baz", fields[2]["Field"]

    results = test_table_rows
    assert_equal 5, results.length
    5.times do |i|
      assert_equal "foo#{i}", results[i]["dummy"]
      assert_equal "bar#{i}", results[i]["baz"]
    end
  end

  private

  def test_table_fields
    result_hashes("DESCRIBE test_table")
  end

  def test_table_rows
    result_hashes("SELECT * FROM test_table")
  end
end
