require 'vert'
require_relative 'eson/tokenizer'
require_relative 'eson/parser'

#The following EBNF rules describe the eson grammar. 
#---EBNF
#program = program_start, [declaration], program_end, [end_of_file];
#
#program_start = "{";
#program_end = "}";
#end_of_file = EOF;
#
#declaration = pair, declaration_list;
#declaration_list = {comma, pair};
#
#pair = call | attribute;
#comma = ",";
#
#(*a call is a declaration performing procedure application without
#  direct substitution*)
#call = procedure, colon, array | null | single;
#
#procedure = proc_prefix, special_form; 
#proc_prefix = "&";
#special_form = let | ref | doc | unknown_special_form;
#let = "let";
#ref = "ref";
#doc = "doc";
#unknown_special_form = {char};
#colon = ":";
#
#value = variable_identifier | string | single | document | number |
#        array | true | false | null;
#
#(*a variable_identifier is a string that can be dereferenced to a value held 
#  in the value store*)
#variable_identifier = variable_prefix, word;
#variable_prefix = "$";
#
#string = [whitespace | variable_prefix], [word | other_chars],
#         {[whitespace | variable_prefix], [word | other_chars]};
#whitespace = " ";
#word = {char}; (*letters, numbers, '-', '_', '.'*)
#other_chars = {char}; (*characters excluding those found
#   in variable_prefix, word and whitespace*)
#
#array = array_start, value, array_list, array_end;
#array_list = {comma, value}
#
#(*an attribute performs simultaneous variable and
# value creation*)
#attribute = key_word, colon, value;
#key_word = {char} (*all characters excluding proc_prefix*)
#
#(*a single is a program allowing
# procedure application and substitution*)
#single = program_start, call, program_end;
#
#prefix = proc_prefix | variable_prefix;
#
#(*a document is a program that contains only attributes*)
#document = program_start, {attribute, [comma, attribute]}, program_end, end_of_file;
#---EBNF
module Eson

  include Vert
  extend self

  def read(eson_program)
    validate_json(eson_program)
    Tokenizer.tokenize_program(eson_program)
  end
  
end
