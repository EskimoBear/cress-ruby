eson-ruby
=======

[eson](https://github.com/EskimoBear/eson) reader in ruby.

##Reading 
To evaluate an eson file call the `read` method.

```ruby
Eson.read('HighJump.eson')
```

A `read` will evaluate all singles and calls in the eson file.

##JSON preprocessing
When eson is being used as a JSON preprocessor call the `process` method to output the evalutated file.

```ruby
Eson.process('EsonMarkup.eson')
```

The `process` method will output a .json file in the same directory without the single calls.

##Command-line usage
eson can also be used from the command-line.

```shell
eson HighJump.eson
```

##Extending the reader
Eson reader supports eson extensibilty by allowing users to define new special forms to sit alongside those built-in to eson. To create a DSL atop eson a user defines a domain specific set of special forms and their respective handlers.

```ruby
golf-reader = Eson.extend(GolfDsl, "golf")
```

In the snippet above the `extend` method returns a reader for a new eson based DSL called `golf`. `golf-reader` has all the abilities of the eson reader and can also parse the special forms defined in the GolfDsl module.
