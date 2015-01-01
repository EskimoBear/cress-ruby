cress-ruby
=======

[eson](https://github.com/EskimoBear/eson) reader in ruby.

##Reading 
To evaluate an eson file call the `read` method.

```ruby
Cress.read('HighJump.eson')
```

A `read` will evaluate all the singles in the eson file.

##JSON preprocessing
When eson is being used as a JSON preprocessor call the `process` method to output the evalutated file.

```ruby
Cress.process('EsonMarkup.eson')
```

The process method will output a .json file in the same directory without the single calls.

##Command-line usage
Cress can also be used from the command-line.

```shell
cress.rb HighJump.eson
cress.rb -p EsonMarkup.eson
```

##Extending the reader
Cress supports eson extensibilty by allowing users to define new special forms to sit alongside those built-in to eson. To create a DSL atop eson a user simply defines a domain specific set of special forms and their respective function handlers. 

```ruby
golf-reader = Cress.extend('golf.dsl', GolfDslHandler)
```

The `extend` method returns a reader for a new eson based DSL defined in the `golf.dsl` file. `golf-reader` has all the abilities of the cress reader but can also parse golf specific special forms defined in the `GolfDslHandler` module.
