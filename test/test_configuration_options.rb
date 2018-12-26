require 'helper'

class TestClassVariables < StoreBaseSTIClass::TestCase

  def setup
    @old_store_sti_classes_for               = ActiveRecord::Base.store_sti_classes_for
  end

  def teardown
    ActiveRecord::Base.store_sti_classes_for = @old_store_sti_classes_for
  end

  def test_setting_store_base_sti_class
    ActiveRecord::Base.store_base_sti_class = false
    assert_equal :all, ActiveRecord::Base.store_sti_classes_for

    ActiveRecord::Base.store_base_sti_class = true
    assert_equal [], ActiveRecord::Base.store_sti_classes_for
  end

  def test_setting_store_sti_classes_for
    assert_nothing_raised do
      ActiveRecord::Base.store_sti_classes_for = ['Post']
    end
    assert_equal ['Post'], ActiveRecord::Base.store_sti_classes_for

    assert_raises(ArgumentError) do
      ActiveRecord::Base.store_sti_classes_for = ['SpecialPost']
    end

    assert_nothing_raised do
      ActiveRecord::Base.store_sti_classes_for = []
    end
    assert_equal [], ActiveRecord::Base.store_sti_classes_for

    assert_raises(ArgumentError) do
      ActiveRecord::Base.store_sti_classes_for = :none
    end
  end

end
