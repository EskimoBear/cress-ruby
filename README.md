cress-ruby
=======

An eson reader for ruby.

To read an eson file call the read method.

```ruby
Cress.read('HighJump.eson')
```

Cress can also be used from the commandline.

```shell
cress HighJump.eson
```

Cress supports eson extensibilty by allowing users to define new singles to sit alongside those built-in to son. To create a DSL atop eson a user simply defines a domain specific set of singles and their respective handlers. This gives the user an eson based DSL and an accompanying parser.

```ruby
golf-reader = Cress.extend(GolfDslSingles, "golf")
```

The `extend` method returns a reader for a new eson based DSL called `golf`. A reader has all the abilities of the cress reader with the added bonus of being able to parse golf specific singles defined in the GolfDslSingles module.
