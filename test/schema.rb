ActiveRecord::Schema.define(:version => 0) do
  create_table :test_table, :force => true do |t|
    t.string :foo
    t.string :bar
  end
  create_table :table_with_timestamps, :force => true do |t|
    t.string :foo
    t.string :bar
    t.timestamps
  end  
end
