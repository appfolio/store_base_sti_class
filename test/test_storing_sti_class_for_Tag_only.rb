require 'helper'

class TestStoringStiClassForTagOnly < StoreBaseSTIClass::TestCase

  def setup
    @old_store_sti_classes_for               = ActiveRecord::Base.store_sti_classes_for
    ActiveRecord::Base.store_sti_classes_for = ['Tag']

    @thinking_post = SpecialPost.create(:title => 'Thinking', :body => "the body")
    @misc_tag      = Tag.create(:name => 'Misc')
  end

  def teardown
    ActiveRecord::Base.store_sti_classes_for = @old_store_sti_classes_for
  end

  def test_polymorphic_belongs_to_assignment_with_inheritance_Person
    # should store correct addressable_type when assigning a saved record
    vendor = Vendor.create!
    address = vendor.addresses.create!(city: 'Springfield')
    assert_equal vendor.id, address.addressable_id
    assert_equal "Person",  address.addressable_type

    person = Person.create!
    address = person.addresses.create!(city: 'Springfield')
    assert_equal person.id, address.addressable_id
    assert_equal "Person",  address.addressable_type

    # should store correct addressable_type when assigning a new record
    vendor = Vendor.create!
    address = vendor.addresses.build(city: 'Springfield')
    assert_equal vendor.id, address.addressable_id
    assert_equal "Person",  address.addressable_type

    person = Person.create!
    address = person.addresses.build(city: 'Springfield')
    assert_equal person.id, address.addressable_id
    assert_equal "Person",  address.addressable_type
  end

  def test_polymorphic_belongs_to_assignment_with_inheritance_Post
    # should store correct taggable_type when assigning a saved record
    tagging          = Tagging.new
    post             = SpecialPost.create(:title => 'Budget Forecasts Bigger 2011 Deficit', :body => "the body")
    tagging.taggable = post
    assert_equal post.id, tagging.taggable_id
    assert_equal "Post", tagging.taggable_type

    # should store correct taggable_type when assigning a new record
    tagging          = Tagging.new
    post             = SpecialPost.new(:title => 'Budget Forecasts Bigger 2011 Deficit', :body => "the body")
    tagging.taggable = post
    assert_nil tagging.taggable_id
    assert_equal "Post", tagging.taggable_type
  end

  def test_polymorphic_has_many_create_model_with_inheritance
    post = SpecialPost.new(:title => 'Budget Forecasts Bigger 2011 Deficit', :body => "the body")

    tagging = @misc_tag.taggings.create(:taggable => post)
    assert_equal "Post", tagging.taggable_type

    post.reload
    assert_equal [tagging], post.taggings
  end

  def test_polymorphic_has_one_create_model_with_inheritance
    post = SpecialPost.new(:title => 'Budget Forecasts Bigger 2011 Deficit', :body => "the body")

    tagging = @misc_tag.create_tagging(:taggable => post)
    assert_equal "Post", tagging.taggable_type

    post.reload
    assert_equal tagging, post.tagging
  end

  def test_polymorphic_has_many_create_via_association
    tag     = SpecialTag.create!(:name => 'Special')
    tagging = tag.polytaggings.create!

    assert_equal "SpecialTag", tagging.polytag_type
  end

  def test_polymorphic_has_many_through_create_via_association
    tag  = SpecialTag.create!(:name => 'Special')
    tag.polytagged_posts.create!(:title => 'To Be or Not To Be?', :body => "the body")

    assert_equal "SpecialTag", tag.polytaggings.first.polytag_type
  end

  def test_include_polymorphic_has_one
    post    = SpecialPost.create!(:title => 'Budget Forecasts Bigger 2011 Deficit', :body => "the body")
    tagging = post.create_tagging(:tag => @misc_tag)

    post = Post.includes(:tagging).find(post.id)
    assert_equal tagging, assert_no_queries { post.tagging }
  end

  def test_include_polymorphic_has_many
    tag = SpecialTag.create!(:name => 'Special')
    tag.polytagged_posts << SpecialPost.create!(:title => 'Budget Forecasts Bigger 2011 Deficit', :body => "the body")
    tag.polytagged_posts << @thinking_post

    tag = Tag.includes(:polytaggings).find(tag.id)
    assert_equal 2, assert_no_queries { tag.polytaggings.size }
  end

  def test_include_polymorphic_has_many_through
    tag = SpecialTag.create!(:name => 'Special')
    tag.polytagged_posts << SpecialPost.create!(:title => 'Budget Forecasts Bigger 2011 Deficit', :body => "the body")
    tag.polytagged_posts << @thinking_post

    tag = Tag.includes(:polytagged_posts).find(tag.id)
    assert_equal 2, assert_no_queries { tag.polytagged_posts.size }
  end

  def test_join_polymorhic_has_many
    tag = SpecialTag.create!(:name => 'Special')
    tag.polytagged_posts << SpecialPost.create!(:title => 'Budget Forecasts Bigger 2011 Deficit', :body => "the body")
    tag.polytagged_posts << @thinking_post

    assert Tag.joins(:polytaggings).where('taggings.id' => tag.polytaggings.first.id, id: tag.id)
  end

  def test_join_polymorhic_has_many_through
    tag = SpecialTag.create!(:name => 'Special')
    tag.polytagged_posts << SpecialPost.create!(:title => 'Budget Forecasts Bigger 2011 Deficit', :body => "the body")
    tag.polytagged_posts << @thinking_post

    assert Tag.joins(:polytagged_posts).where('posts.id' => tag.polytaggings.first.taggable_id, id: tag.id)
  end

  def test_has_many_through_polymorphic_has_one
    author       = Author.create!(:name => 'Bob')
    post         = Post.create!(:title => 'Budget Forecasts Bigger 2011 Deficit', :author => author, :body => "the body")
    special_post = SpecialPost.create!(:title => 'IBM Watson' 's Jeopardy play', :author => author, :body => "the body")
    special_tag  = SpecialTag.create!(:name => 'SpecialGeneral')

    taggings = [        post.taggings.create!(:tag => special_tag),
                special_post.taggings.create!(:tag => special_tag)]
    assert_equal taggings.sort_by(&:id), author.tagging.sort_by(&:id)
  end

  def test_has_many_polymorphic_with_source_type
    tag = SpecialTag.create!(:name => 'Special')
    tag.polytagged_posts << SpecialPost.create!(:title => 'Budget Forecasts Bigger 2011 Deficit', :body => "the body")
    tag.polytagged_posts << @thinking_post

    tag.save!
    tag.reload

    tag = Tag.find(tag.id)
    assert_equal 2, tag.polytagged_posts.size
  end

  def test_polymorphic_has_many_through_with_double_sti_on_join_model__storing_base_class
    ActiveRecord::Base.store_base_sti_class = true

    tag  = SpecialTag.create!(:name => 'Special')
    post = @thinking_post

    tag.polytagged_posts << post
    tag.reload

    assert_equal 1, tag.polytaggings.size

    tagging = tag.polytaggings.first

    assert_equal 'Tag', tagging.polytag_type
    assert_equal 'Post', tagging.taggable_type

    assert_equal tag, tagging.polytag
    assert_equal post, tagging.taggable
  end

  def test_polymorphic_has_many_through_with_double_sti_on_join_model
    tag  = SpecialTag.create!(:name => 'Special')
    post = @thinking_post

    tag.polytagged_posts << post
    tag.reload

    assert_equal 1, tag.polytaggings.size

    tagging = tag.polytaggings.first

    assert_equal 'SpecialTag', tagging.polytag_type
    assert_equal 'Post', tagging.taggable_type

    assert_equal tag, tagging.polytag
    assert_equal post, tagging.taggable
  end

  def test_join_association
    tag = SpecialTag.create!(:name => 'Special')
    tag.polytaggings << Tagging.new

    assert SpecialTag.joins(:polytaggings).where(id: tag.id).first
  end

  if Gem::Version.new(ActiveRecord::VERSION::STRING) < Gem::Version.new('4.1.0')
    def test_finder_sql_is_supported
      author      = Author.create!(:name => 'Bob')
      post        = Post.create!(:title => 'Budget Forecasts Bigger 2011 Deficit', :author => author, :body => "the body")
      special_tag = Tag.create!(:name => 'SpecialGeneral')
      post.taggings.create(:tag => special_tag)

      assert_equal [author], special_tag.authors
    end
  end
end
