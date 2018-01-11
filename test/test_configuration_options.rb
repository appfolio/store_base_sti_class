require 'helper'

class TestClassVariables < StoreBaseSTIClass::TestCase

  def setup
    @old_store_sti_classes               = ActiveRecord::Base.store_sti_classes
  end

  def teardown
    ActiveRecord::Base.store_sti_classes = @old_store_sti_classes
  end

  def test_setting_store_base_sti_class
    ActiveRecord::Base.store_base_sti_class = false
    assert_equal :all, ActiveRecord::Base.store_sti_classes

    ActiveRecord::Base.store_base_sti_class = true
    assert_equal [], ActiveRecord::Base.store_sti_classes
  end

  def test_setting_store_sti_classes
    assert_nothing_raised do
      ActiveRecord::Base.store_sti_classes = ['Post']
    end
    assert_equal ['Post'], ActiveRecord::Base.store_sti_classes

    assert_raises(ArgumentError) do
      ActiveRecord::Base.store_sti_classes = ['SpecialPost']
    end

    assert_nothing_raised do
      ActiveRecord::Base.store_sti_classes = []
    end
    assert_equal [], ActiveRecord::Base.store_sti_classes

    assert_raises(ArgumentError) do
      ActiveRecord::Base.store_sti_classes = :none
    end
  end

end
