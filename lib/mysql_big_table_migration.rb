require "rails/version"

module MySQLBigTableMigration

  SUPPORTED_ADAPTERS = [
    "ActiveRecord::ConnectionAdapters::MysqlAdapter",
    "ActiveRecord::ConnectionAdapters::Mysql2Adapter"
  ]

  def rename_column(table, old_name, new_name)
    push_state unless @state_stack.try(:any?)
    current_state[:renames] ||= {}
    current_state[:renames][old_name] = new_name
    super
  end

  def add_column_using_tmp_table(table_name, *args)
    with_tmp_table(table_name) do |tmp_table_name|
      begin
        add_column tmp_table_name, *args
      rescue ActiveRecord::StatementInvalid => e
        raise unless e.message.include?("Duplicate column name")
      end
    end
  end

  def remove_column_using_tmp_table(table_name, column_name)
    with_tmp_table(table_name) do |tmp_table_name|
      begin
        remove_column tmp_table_name, column_name
      rescue ActiveRecord::StatementInvalid => e
        raise unless e.message.include?("check that column/key exists")
      end
    end
  end

  def rename_column_using_tmp_table(table_name, column_name, new_column_name)
    with_tmp_table(table_name) { |tmp_table_name| rename_column(tmp_table_name, column_name, new_column_name) }
  end

  def change_column_using_tmp_table(table_name, column_name, type, options={})
    with_tmp_table(table_name) { |tmp_table_name| change_column(tmp_table_name, column_name, type, options) }
  end

  def add_index_using_tmp_table(table_name, column_name, options={})
    # generate the index name using the original table name if no name provided
    options[:name] = index_name(table_name, :column => Array(column_name)) if options[:name].nil?
    with_tmp_table(table_name) { |tmp_table_name| add_index(tmp_table_name, column_name, options) }
  end

  def remove_index_using_tmp_table(table_name, options={})
    with_tmp_table(table_name) { |tmp_table_name| remove_index(tmp_table_name, :name => index_name(table_name, options)) }
  end

  def with_tmp_table(table_name)
    raise ArgumentError, "block expected" unless block_given?

    unless SUPPORTED_ADAPTERS.include? connection.class.name
      puts "Warning: Unsupported connection adapter '#{connection.class.name}' for MySQL Big Table Migration Plugin"
      puts "         Migration methods will still be executed, but without using a temp table."
      yield table_name
      return
    end

    table_name = table_name.to_s
    new_table_name = "tmp_new_" + table_name
    old_table_name = "tmp_old_" + table_name

    begin
      say "Creating temporary table #{new_table_name} like #{table_name}..."
      connection.execute("CREATE TABLE #{new_table_name} LIKE #{table_name}")

      # yield the temporary table name to the block, which should alter the table using standard migration methods
      push_state
      yield new_table_name
      state = pop_state

      rename_columns ||= state[:renames] || {}

      # get column names to copy *after* yielding to block - could drop a column from new table
      # note: do not get column names using the column_names method, we need to make sure we avoid obtaining a cached array of column names
      old_column_names = []
      each_result_hash(connection.execute("DESCRIBE #{table_name}")) { |row| old_column_names << row['Field'] } # see ruby mysql docs for more info
      new_column_names = []
      each_result_hash(connection.execute("DESCRIBE #{new_table_name}")) { |row| new_column_names << row['Field'] }

      shared_columns = old_column_names & new_column_names

      old_column_list = column_list(shared_columns + rename_columns.keys)
      new_column_list = column_list(shared_columns + rename_columns.values)

      timestamp_before_migration = fetch_result_row(connection.execute("SELECT CURRENT_TIMESTAMP"))[0] # note: string, not time object
      max_id_before_migration = fetch_result_row(connection.execute("SELECT MAX(id) FROM #{table_name}"))[0].to_i

      if max_id_before_migration == 0
        say "Source table is empty, no rows to copy into temporary table"
      else
        batch_size = mysql_big_table_migration_bach_size
        start = fetch_result_row(connection.execute("SELECT MIN(id) FROM #{table_name}"))[0].to_i
        counter = start
        say "Inserting into temporary table in batches of #{batch_size}..."
        say "Approximately #{max_id_before_migration-start+1} rows to process, first row has id #{start}", true
        while counter <= ( max = fetch_result_row(connection.execute("SELECT MAX(id) FROM #{table_name}"))[0].to_i )
          percentage_complete = ( ( ( counter - start ).to_f / ( max - start ).to_f ) * 100 ).to_i
          say "Processing rows with ids between #{counter} and #{(counter+batch_size)-1} (#{percentage_complete}% complete)", true
          connection.execute("INSERT INTO #{new_table_name} (#{new_column_list}) SELECT #{old_column_list} FROM #{table_name} WHERE id >= #{counter} AND id < #{counter + batch_size}")
          counter = counter + batch_size
        end
        say "Finished inserting into temporary table"
      end

    rescue Exception => e
      drop_table new_table_name
      raise
    end

    say "Replacing source table with temporary table..."
    rename_table table_name, old_table_name
    rename_table new_table_name, table_name

    say "Cleaning up, checking for rows created/updated during migration, dropping old table..."
    begin
      connection.execute("LOCK TABLES #{table_name} WRITE, #{old_table_name} READ")
      recently_created_or_updated_conditions = "id > #{max_id_before_migration}"
      recently_created_or_updated_conditions << " OR updated_at > '#{timestamp_before_migration}'" if old_column_names.include?("updated_at")
      connection.execute("REPLACE INTO #{table_name} (#{new_column_list}) SELECT #{old_column_list} FROM #{old_table_name} WHERE #{recently_created_or_updated_conditions}")
    rescue Exception => e
      puts "Failed to lock tables and do final cleanup. This may not be anything to worry about, especially on an infrequently used table."
      puts "ERROR MESSAGE: " + e.message
    ensure
      connection.execute("UNLOCK TABLES")
    end
    drop_table old_table_name
  end

  private

  def mysql_big_table_migration_bach_size
    10000
  end

  def connection
    ActiveRecord::Base.connection
  end

  def each_result_hash(result, &block)
    case connection.class.name
    when "ActiveRecord::ConnectionAdapters::MysqlAdapter"
      result.each_hash(&block)
    when "ActiveRecord::ConnectionAdapters::Mysql2Adapter"
      result.each(:as => :hash, &block)
    end
  end

  def fetch_result_row(result)
    case connection.class.name
    when "ActiveRecord::ConnectionAdapters::MysqlAdapter"
      result.fetch_row
    when "ActiveRecord::ConnectionAdapters::Mysql2Adapter"
      result.first
    end
  end

  def column_list(column_names)
    "`" + column_names.join("`, `") + "`"
  end

  def push_state
    @state_stack ||= []
    @state_stack.push({})
  end

  def pop_state
    @state_stack.pop
  end

  def current_state
    @state_stack.last
  end

end

if Object.const_defined?("ActiveRecord")
  class ActiveRecord::Migration
    if Rails::VERSION::STRING < "3.0"
      extend MySQLBigTableMigration
    else
      include MySQLBigTableMigration
    end
  end
end
