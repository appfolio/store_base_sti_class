ActiveRecord::Schema.define do

  # Please keep these create table statements in alphabetical order
  # unless the ordering matters.  In which case, define them below

  create_table :accounts, :force => true do |t|
    t.string :name, :null => false
    t.string :type
  end

  create_table :authors, :force => true do |t|
    t.string :name, :null => false
  end

  create_table :comments, :force => true do |t|
    t.string  :name, :null => false
    t.string  :commentable_type
    t.integer :commentable_id
  end

  create_table :posts, :force => true do |t|
    t.string  :type

    t.integer :author_id
    t.string  :title, :null => false
    t.text    :body, :null => false
    t.integer :taggings_count, :default => 0
  end

  create_table :taggings, :force => true do |t|
    t.integer :tag_id

    t.integer :polytag_id
    t.string  :polytag_type

    t.string  :taggable_type
    t.integer :taggable_id
  end

  create_table :tags, :force => true do |t|
    t.string  :type
    t.string  :name
    t.integer :taggings_count, :default => 0
  end

end
