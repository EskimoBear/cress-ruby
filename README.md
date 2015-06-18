Dote-ruby
=======

[Dote](https://github.com/EskimoBear/dote-spec) compiler implemented in Ruby.

##Compiling 
To compile a Dote program call the `compile` method with its file path.

```ruby
Dote.compile('program.dt')
```

A `compile` will evaluate all singles and calls in the eson file and output a `.json` file in the same directory. 

##Code generation
Dote will generate JSON documents by default but the compiler can also generate Ruby source code. The Ruby code generator can be invoked by passing `:ruby` as the second argument.

```ruby
Dote.compile('program.dt', :ruby)
```

##Command-line usage
Dote can also be used from the command-line.

```shell
#Calls compile with the JSON code generator
Dote program.dt

#Calls compile with the Ruby code generator
Dote --ruby program.dt
```

##Extending the compiler
Dote compiler supports extensibilty by allowing users to define additional special forms to sit alongside those built-in to Dote. This allows a user to create declarative DSLs that use Dote syntax. To create a DSL atop Dote a user defines a domain specific set of special forms and their respective handlers.

```ruby
golf-compiler = Dote.extend(GolfDsl, "golf")
```

In the snippet above the `extend` method returns a compiler for a new Dote based DSL called `golf`. `golf-compiler` has all the abilities of the original Dote compiler as well as the ability to parse the special forms defined in the GolfDsl module.
