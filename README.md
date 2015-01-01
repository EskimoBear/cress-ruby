eson-ruby
=======

An eson reader for ruby.

To evaluate the eson file call the `read` method.

```ruby
Eson.read('HighJump.eson')
```

A `read` will evaluate all the singles in the eson file.

To use eson reader as a JSON preprocessor call the `process` method.

```ruby
Eson.process('EsonMarkup.eson')
```

The `process` method will output a .json file in the same directorywithout the single calls.

eson can also be used from the commandline.

```shell
eson HighJump.eson
```

Eson reader supports eson extensibilty by allowing users to define new special forms to sit alongside those built-in to eson. To create a DSL atop eson a user simply defines a domain specific set of specific forms and their respective handlers.

```ruby
golf-reader = Eson.extend(GolfDslSingles, "golf")
```

In the snippet above the `extend` method returns a reader for a new eson based DSL called `golf`. A reader has all the abilities of the eson reader with the added bonus of being able to parse golf specific functions defined in the GolfDslSingles module.
