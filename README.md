eson-ruby
=======

[eson](https://github.com/EskimoBear/eson) compiler implemented in ruby.

##Compiling 
To compile an eson file call the `complile` method with the file path of the eson program.

```ruby
Eson.compile('program.eson')
```

A `compile` will evaluate all singles and calls in the eson file and output a .json file in the same directory. 

##Code generation
Eson can generate JSON documents and Ruby source code. The default code generator is JSON but the Ruby code generator can be invoked by passing `:ruby` as the second argument.

```ruby
Eson.read('program.eson', :ruby)
```

##Command-line usage
eson can also be used from the command-line.

```shell
# Calls read with the JSON code generator
eson program.eson

#Calls read with the Ruby code generator
eson --ruby program.eson
```

##Extending the reader
Eson reader supports eson extensibilty by allowing users to define new special forms to sit alongside those built-in to eson. To create a DSL atop eson a user defines a domain specific set of special forms and their respective handlers.

```ruby
golf-reader = Eson.extend(GolfDsl, "golf")
```

In the snippet above the `extend` method returns a reader for a new eson based DSL called `golf`. `golf-reader` has all the abilities of the eson reader and can also parse the special forms defined in the GolfDsl module.
