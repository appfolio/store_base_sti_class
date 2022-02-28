# StoreBaseSTIClass

ActiveRecord has always stored the base class in `polymorphic_type` columns when using STI. This can have non-trivial
performance implications in certain cases. This gem adds the `store_base_sti_class` configuration option which controls
whether ActiveRecord will store the base class or the actual class. Defaults to true for backwards compatibility.

## Description

Given the following class definitions:

```ruby
class Address
  belongs_to :addressable, polymorphic: true
end

class Person
  has_many :addresses, as: addressable
end

class Vendor < Person
end
```

and given the following code:

```ruby
vendor = Vendor.create(...)
address = vendor.addresses.create(...)

p vendor
p address
```

will output:

```ruby
#<Vendor id: 1, type: "Vendor" ...>
#<Address id: 1, addressable_id: 1, addressable_type: 'Person' ...>
```

Notice that `addressable_type` column is Person even though the actual class is Vendor.

Normally, this isn't a problem, however, it can have negative performance characteristics in certain circumstances. The
most obvious one is that a join with persons or an extra query is required to find out the actual type of addressable.

This gem adds the `ActiveRecord::Base.store_base_sti_class` configuration option. It defaults to true for backwards
compatibility. Setting it to false will alter ActiveRecord's behavior to store the actual class in `polymorphic_type`
columns when STI is used.

In the example above, if the `ActiveRecord::Base.store_base_sti_class` is `false`, the output will be,

```ruby
#<Vendor id: 1, type: "Vendor" ...>
#<Address id: 1, addressable_id: 1, addressable_type: 'Vendor' ...>
```

## Usage

Add the following line to your Gemfile

```ruby
gem 'store_base_sti_class'
```

then bundle install. Once you have the gem installed, add the following to one of the initializers (or make a new one)
in config/initializers,

```ruby
ActiveRecord::Base.store_base_sti_class = false
```

When changing this behavior, you will have write a migration to update all of your existing `_type` columns accordingly.
You may also need to change your application if it explicitly relies on the `_type` columns.

## Notes

This gem incorporates work from:

- https://github.com/codepodu/store_base_sti_class_for_4_0

It currently works with ActiveRecord `4.2.x` through `7.0.x`. If you need support for ActiveRecord `3.x`, use a
`pre-1.0` version of the gem, or ActiveRecord < `4.2` use a `pre-2.0` version of the gem, or ActiveRecord < `6` use
version < `3` of the gem.

## Conflicts

This gem produces known conflicts with these other gems:

When using [friendly_id](https://github.com/norman/friendly_id) >= `5.2.5` with the
[History module](https://norman.github.io/friendly_id/FriendlyId/History.html) enabled, duplicate slugs will be
generated for STI subclasses with the same sluggable identifier (ex: name). This will either cause saves to fail if you
have the proper indexes in place, or will cause slug lookups to be non-deterministic, either of which is undesirable.

## History

* https://github.com/rails/rails/issues/724
* https://github.com/rails/rails/issues/5441#issuecomment-4563865
* https://github.com/rails/rails/issues/4729#issuecomment-5729297
* https://github.com/rails/rails/issues/5441#issuecomment-264871920
