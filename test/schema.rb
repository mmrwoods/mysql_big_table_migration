ActiveRecord::Schema.define(:version => 0) do
  create_table :test_table, :force => true do |t|
    t.string :foo
    t.string :bar
  end

  add_index :test_table, [:foo]
end
