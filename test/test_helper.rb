require 'rubygems'
require 'fileutils'
require 'test/unit'
require 'active_record'
require File.dirname(__FILE__) + "/../lib/mysql_big_table_migration"

TEST_CONFIGS = ["mysql", "mysql2"]

def read_log_file
  @log.string
end

def load_schema(adapter)
  config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
  @log = StringIO.new
  ActiveRecord::Base.logger = Logger.new(@log)
  ActiveRecord::Base.establish_connection(config[adapter.to_s])
  load(File.dirname(__FILE__) + "/schema.rb")
end

def load_fixtures
  connection = ActiveRecord::Base.connection

  connection.execute("DELETE FROM test_table;")
  5.times do |i|
    connection.execute("INSERT INTO test_table (foo, bar) VALUES ('foo#{i}', 'bar#{i}');")
  end
end

def assert_valid_database_setup
  fields = result_hashes("DESCRIBE test_table")
  assert_equal 3, fields.length
  assert_equal "id", fields[0]["Field"]
  assert_equal "int(11)", fields[0]["Type"]
  assert_equal "foo", fields[1]["Field"]
  assert_equal "varchar(255)", fields[1]["Type"]
  assert_equal "bar", fields[2]["Field"]
  assert_equal "varchar(255)", fields[2]["Type"]

  indexes = result_hashes("SHOW INDEX FROM test_table")
  assert_equal 2, indexes.length
  assert_equal "id", indexes[0]["Column_name"]
  assert_equal "foo", indexes[1]["Column_name"]

  results = result_hashes("SELECT * FROM test_table")
  assert_equal 5, results.length
  assert_equal "foo2", results[2]["foo"]
  assert_equal "bar3", results[3]["bar"]
end

def result_hashes(query)
  result = connection.execute(query)
  case connection
  when ActiveRecord::ConnectionAdapters::MysqlAdapter
    result.all_hashes
  when ActiveRecord::ConnectionAdapters::Mysql2Adapter
    result.each(:as => :hash)
  else
    raise "Unknown adapter"
  end
end

module DatabaseTest
  def test_against_all_configs(name, &block)
    TEST_CONFIGS.each do |config|
      self.send(:define_method, :"test_#{name.to_s}_with_#{config}") do
          silence_stream($stdout) do
          load_schema(config)
          load_fixtures
        end
        assert_valid_database_setup
        block.bind(self).call
      end
    end
  end
end

def connection
  ActiveRecord::Base.connection
end
