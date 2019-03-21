# Lmt-Ruby

###### Code Block: Description

``` text
A literate Markdown tangle tool written in Ruby.
```

Lmt is a literate Markdown tangle program for [literate programing](https://en.wikipedia.org/wiki/Literate_programming) in a slightly extended [Markdown](http://daringfireball.net/projects/markdown/syntax) syntax that is written in Ruby.

In literate programming, a program is contained within a prose essay describing the thinking which goes into the program.  The source code is then extracted from the essay using a program called tangle (this application).  The essay can also be formatted into a document for human consumption using a program called "weave" and can be found [here](lmm.md).

## Why?

While there are other Markdown tanglers available (especially [lmt](https://github.com/driusan/lmt), which this program is designed to be superficially similar to) none quite match the combination of simplicity and extensibility which I need.

## Features

In order to be useful for literate programming we need a few features:

1. The ability to strip code out of a Markdown file and place it into a tangled output file.
2. The ability to embed macros so that the code can be expressed in any order desired.
3. The ability to apply filters on the contents of a macro
4. The ability to to identify code blocks which will be expanded when referenced
5. The ability to append to or replace code blocks
6. The ability to include another file.
7. The ability to extend the tangler with Ruby code from a block.

There are also a few potentially useful features that are not implemented but might be in the future:

1. The ability to write out other files.
2. Source mapping
3. Further source verification.  For instance, all instances of the same block should be in the same language.  Also, detect and prevent double inclusion.
4. Simple variables and conditional logic to enable output only under certain circumstances

### Blocks

Markdown already supports code blocks expressed with code fences starting with three backticks, usually enabling syntax highlighting on the output.  This should work excellently for identifying block boundaries.

There are two types of blocks: the default block and macro blocks.

Output begins with the default block.  It is simply a markdown code block which has no macro name.  with no further information.  It looks like this.

###### Output Block

``` ruby
#Output starts here
```

If there is no default block, then no output file will be created.

In order to add the macro feature we need, we will need to add header content at the beginning of such a quote. For code blocks, we can add it after the language name.  For example to create a macro named macro_description we could use:

###### Code Block: Macro Description

``` ruby
# this shouldn't be in the output, it should have been replaced.
block_replacement = false
```

Of course, these do not play well with Markdown rendering, so we will need a weaver to display the name appropriately.

To replace a block put `=` before the block name like so:

###### Replacing Code Block: Macro Description

``` ruby
# this is the replacement
replaced_block = true
```

To append to a block, just open it again.  The macro expansion only happens after the entire file is read.

###### Code Block: Macro Description

``` ruby
# Yay appended code gets injected
block_appendment = true
```

#### Macros

We will also need a way to trigger macro insertion.  Given that unicode tends not to be in use, why don't we say that anything inside `⦅⦆` refers to a block by name and should be replaced by the contents of that block.

###### Code Block: Macro Insertion Description

``` ruby
block_replacement = true
replaced_block = false
block_appendment = false

⦅macro_description⦆
```

Given the definition of `macro_description` above, all the variables will be true at the end of that block.

This also works with spaces inside the `⦅⦆`

###### Code Block: Macro Insertion Description

``` ruby
insertion_works_with_spaces = false
⦅ insertion_works_with_spaces ⦆
```

Finally, if substitution isn't desired, you may escape the `⦅` and `⦆` with `\` which will prevent macro expansion.  As below; the first character of escaped string is `⦅`

###### Code Block: Macro Insertion Description

``` ruby
escaped_string = '\⦅macro_description\⦆'
```

### Filters

Filters can be defined as functions which take an array of lines and return the altered array.  They are applied after a macro's contents are expanded and before it is inserted.  They are triggered with the `|` symbol in expansion. for example: given

###### Code Block: String With Backslash

``` text
this string ends in \.
```

The following will escape the `\`

###### Code Block: Filter Use Description

``` ruby
string_with_backslash = "⦅string_with_backslash | ruby_escape⦆"
```

There are a few built in filters:

###### Code Block: Filter List

``` ruby
{
  'ruby_escape' => ⦅ruby_escape⦆,
  'double_quote' => ⦅double_quote⦆,
  'add_comma' => ⦅add_comma⦆,
  'indent_continuation' => ⦅indent_continuation⦆,
  'indent_lines' => ⦅indent_lines⦆
}
```

### Includes

Other files may be using an include directive and a markdown link.  Include directive are lines starting with `! include` followed by a space.  No further text may follow the markdown link.  Paths are relative to the file being included from.

During tangle the link line will be replaced with the lines from the included file.  This means that they may replace blocks defined in the file that includes them such as this one

###### Code Block: Included Block

``` ruby
included_string = "I am in lmt.lmd"
```

**See include:** [lmt_include.lmd](include_file)

### Extension

In order to extend the tangler, it must be possible to mark a block for evaluation.  To do so we will extend the mechanism to indicate replacement.  Let's use `!`.  A block simply named `!` will just be executed within a contained scope.  Within this scope, it will be possible to access the map of filters through the `@filters` variable.  All of these blocks are executed and removed from the stream before any further processing is done.

However, after blocks have been parsed, the map of blocks will be passed to the `parse_hook` method which an extension may define.  It will be passed a two arguments.  The first is an array with the lines of the main block, the second is a map of block name to line arrays.  It is expected to return the same datastructure in a two value array.  An example parse hook which adds a block to the list of know blocks follows:

###### Execute Extension Block

``` ruby
def parse_hook(main_block, blocks)
  blocks["from_extension"] = ["from_extension = true\n"]
  [main_block, blocks]
end
```

### Self Test

Of course, we will also need a testing procedure.  Since this is written as a literate program, our test procedure is: can we tangle ourself.  If the output of the tangler run on this file can tangle this file, then we know that the tangler works.

###### Code Block: Self Test

``` ruby
def self.self_test()
  ⦅test_description⦆
end
```

## Interface

We need to know where to get the input from and where to send the output to.  For that, we will use the following command line options

###### Code Block: Options

``` ruby
on("--file FILE", "-f", "Required: input file")
on("--output FILE", "-o", "Required: output file")
on("--dev", "disables self test failure for development")
```

Of which, both are required

###### Code Block: Options

``` ruby
required(:file, :output)
```

## Implementation and Example

Now for an example in implementation.  Using Ruby we can write a template as below:  (We are replacing the default block because the version above doesn't have a #!.)

###### Replacing Output Block

``` ruby
#!/usr/bin/env ruby
# Encoding: utf-8

⦅includes⦆

module Lmt

class Tangle
  include Methadone::Main
  include Methadone::CLILogging

  @dev = false

  main do
    check_arguments()
    begin
      ⦅main_body⦆
    rescue Exception => e
      puts "Error: #{e.message} #{extract_causes(e)}At:"
      e.backtrace.each do |trace|
        puts "    #{trace}"
      end
    end
  end

  def self.extract_causes(error)
    if (error.cause)
      "  Caused by: #{error.cause.message}\n#{extract_causes(error.cause)}"
    else
      ""
    end
  end

  ⦅self_test⦆

  ⦅report_self_test_failure⦆
  
  ⦅filter_class⦆

  ⦅tangle_class⦆

  ⦅context_class⦆

  ⦅option_verification⦆

  description "⦅description⦆"
  ⦅options⦆

  version Lmt::VERSION

  use_log_level_option :toggle_debug_on_signal => 'USR1'

  go! if __FILE__ == $0
end

end

```

This is a basic template using the [Ruby methadone](https://github.com/davetron5000/methadone) command line application framework and making sure that we report errors (because silent failure sucks).

The main body will first test itself then, invoke the library component, which isn't in lib as traditional because it is in this file and I don't want to move it around.

###### Code Block: Main Body

``` ruby
@dev = options[:dev]
self_test()
tangler = Tangle::Tangler.new(options[:file])
tangler.tangle()
tangler.write(options[:output])
```

Finally, we have the dependencies.  Optparse and methadone are used for cli argument handling and other niceties.

###### Code Block: Includes

``` ruby
require 'optparse'
require 'methadone'
require 'lmt/version'
```

There, now we are done with the boilerplate. On to:

## The Actual Tangler

The tangler is defined within a class that contains the tangling implementation.  It contains the following blocks

###### Code Block: Tangle Class

``` ruby
class Tangler
  ⦅initializer⦆
  ⦅tangle⦆
  ⦅read_file⦆
  ⦅include_includes⦆
  ⦅eval_extensions⦆
  ⦅parse_blocks⦆
  ⦅expand_macros⦆
  ⦅apply_filters⦆
  ⦅unescape_double_parens⦆
  ⦅write⦆

  private
  def filters_map
    @extension_context.filters
  end
  ⦅tangle_class_privates⦆
end
```

### Initializer

The initializer takes in the input file and sets up our state.  We are keeping the unnamed top level block separate from the rest.  Then we have a hash of blocks.  Finally, we need to make sure we have tangled before we write the output.

###### Code Block: Initializer

``` ruby
def initialize(input)
  @extension_context = Context.new()
  @extension_context.filters = ⦅filter_list⦆
  @input = input
  @block = ""
  @blocks = {}
  @tangled = false
end

```

### Tangle

Now we have the basic tangle process wherein a file is read, includes are substituted, extensions processed, the blocks extracted, the extension hook called, macros expanded recursively, and escaped double parentheses unescaped.  If there is no default block, then there is no further work to be done.

###### Code Block: Tangle

``` ruby
def tangle()
  contents = eval_and_remove_extensions(
      include_includes(read_file(@input)))
  @block, @blocks = @extension_context.parse_hook(*parse_blocks(contents))
  if @block
    @block = expand_macros(@block)
    @block = unescape_double_parens(@block)
  end
  @tangled = true
end

```

### Reading The File

This is fairly self explanatory, though note, we are storing the file in memory as an array of lines.

###### Code Block: Read File

``` ruby
def read_file(file)
  File.open(file, 'r') do |f|
    f.readlines
  end
end

```

### Including the Includes

As our specification is a regular language (we do not support any kind of nesting), we will be using regular expressions to process it.  Those expressions are detailed in:

**See include:** [lmt_expressions.lmd](include_file)

Here we go through each line looking for an include statement.  When we find one, we replace it with the lines from that file.  Those lines will, of course, need to have includes processed as well.

###### Code Block: Include Includes

``` ruby
def include_includes(lines, current_file = @input, depth = 0)
  raise "too many includes" if depth > 1000
  include_exp = ⦅include_expression⦆
  lines.map do |line|
    match = include_exp.match(line)
    if match
      file = File.dirname(current_file) + '/' + match[1]
      include_includes(read_file(file), file, depth + 1)
    else
      [line]
    end
  end.flatten(1)
end

```

### Evaling the Extensions

The extensions are executed within the following context.  This context is also
used to evaluate conditionals.

###### Code Block: Context Class

``` ruby
class Context
  attr_accessor :filters

  def get_binding
    binding
  end

  def parse_hook(main_block, blocks)
    [main_block, blocks]
  end
end

```

In order to process the extensions we must go through the lines, separating out any extension blocks.  We then execute them within the extension_context and return the non-extension lines.

###### Code Block: Eval Extensions

``` ruby
def eval_and_remove_extensions(lines)
  extension_expression = ⦅extension_expression⦆
  extension_exit_expression = /```/
  in_extension_block = false

  extension_lines, other_lines = lines.partition do |line|
    unless in_extension_block
      in_extension_block = line =~ extension_expression
    else
      in_extension_block = !(line =~ extension_exit_expression)
      true
    end
  end

  e = extension_lines.slice_before do |line|
    extension_expression =~ line
  end.map do |block|
    block[1..-2].join
  end.each do |block|
    @extension_context.get_binding.eval(block)
  end

  other_lines
end

```

### Parsing The Blocks

Now we get to the meat of the algorithm.  This uses the regular expression in [lmt_expressions](lmt_expressions.lmd#The-Code-Block-Expression)

First, we filter out all non block lines, keeping the block headers, slice it into separate blocks at the header, process the header and turn it into a map of lists of lines.  We then group by the headers and combine the blocks which follow the last reset for that block name.

We also need to remove the last newline from the block as it causes problems when injecting a block onto a line with stuff after the end.

Finally, (after making sure we aren't missing a code fence) we extract the unnamed block from the hash and return both it and the rest.

###### Code Block: Parse Blocks

``` ruby
def parse_blocks(lines)
  code_block_exp = ⦅code_block_expression⦆
  in_block = false
  blocks = lines.find_all do |line|
    in_block = !in_block if line =~ code_block_exp
    in_block
  end.slice_before do |line|
    code_block_exp =~ line
  end.map do |(header, *rest)|
    white_space, language, replacement_mark, name = code_block_exp.match(header)[1..-1]
    [name, replacement_mark, rest]
  end.group_by do |(name, _, _)|
    name
  end.transform_values do |bodies|
    last_replacement_index = get_last_replacement_index(bodies)
    bodies[last_replacement_index..-1].map { |(_, _, body)| body}
      .flatten(1)
  end.transform_values do |body_lines|
    body_lines[-1] = body_lines[-1].chomp if body_lines[-1]
    body_lines
  end
  throw "Missing code fence" if in_block
  main = blocks[""]
  blocks.delete("")
  [main, blocks]
end

```

We have a private helper helper method here.  So, after we turn each block chunk into an array of `[name, replacement_mark, body]` we can find the last one by scanning for a replacement mark set to `=`.  Otherwise the answer is `0` as there is no replacement index.

###### Code Block: Tangle Class Privates

``` ruby
def get_last_replacement_index(bodies)
  last_replacement = bodies.each_with_index
      .select do |((_, replacement_mark, _), _)|
        replacement_mark == '='
      end[-1]
  if last_replacement
    last_replacement[1]
  else
    0
  end
end

```

### Handling the macros

The other half of the meat.  Here we use two regular expressions.  One to identify and propagate whitespace and the other to actually find the replacements in a line.

This is implemented by splitting the line on the replacement section, grouping into pairs, and then reducing.  Afterwords, we end up with an extra layer of lists which need to be flattened.  (Yes I am using a monad and bind.)

###### Code Block: Expand Macros

``` ruby
def expand_macros(lines, depth = 0)
  throw "too deep macro expansion {depth}" if depth > 1000
  lines.map do |line|
    begin
      expand_macro_on_line(line, depth)
    rescue Exception => e
      raise Exception, "Failed to process line: #{line}", e.backtrace
    end
  end.flatten(1)
end

```

Expand_macro_on_line turns a line into a list of lines.  The collected results will have to be flattened by 1.

First we process the white space off the front of the expression.  This will be added to each line in the extended macros so that the output file is nicely indented.  It also means that indentation sensitive languages like python will be tangled correctly.

###### Code Block: Tangle Class Privates

``` ruby
def expand_macro_on_line(line, depth)
  white_space_exp = /^(\s*)(.*\n?)/
  macro_substitution_exp = ⦅macro_substitution_expression⦆
  filter_extraction_exp = / *\| *([-\w]+) */
  white_space, text = white_space_exp.match(line)[1..2]
```

Then we chop it into pieces using the [macro substitution expression](lmt_expressions.lmd#The-Macro-Substitution-Expression) This results in text, macro_name / filter pairs.  If there is a macro name, we then split the filter names off with the filter expression which provides filter names followed by stuff between them (nothing) which we discard.

###### Code Block: Tangle Class Privates

``` ruby
  section = text.split(macro_substitution_exp)
      .each_slice(2)
      .map do |(text_before_macro, macro_match)|
        if (macro_match)
          macro_name, *filters = macro_match.strip.split(filter_extraction_exp)
          [text_before_macro, macro_name, filters.each_slice(2).map(&:first)]
        else
          [text_before_macro]
        end
```

Finally, we are ready to actually process the text and macros.  We build the list of ines with just the white space, and appending the results of precessing to the end.  Each potential line is built up by appending to the end of the last line.  If there is no macro, then we can just append the text.  

###### Code Block: Tangle Class Privates

``` ruby
      end.inject([white_space]) do
        |(*new_lines, last_line), (text_before_macro, macro_name, filters)|
        if macro_name.nil?
          last_line = "" unless last_line
          new_lines << last_line + text_before_macro
        else
```

If there is a macro substitution, first we get the new lines.  The we append the first line of the macro text to the last line.  Finally, we append the white space to the front of each of the macro's lines and insert them into the middle.  of the list of lines we are building.

###### Code Block: Tangle Class Privates

``` ruby
          throw "Macro '#{macro_name}' unknown" unless @blocks[macro_name]
          macro_lines = apply_filters(
              expand_macros(@blocks[macro_name], depth + 1), filters)
          unless macro_lines.empty?
            new_line = last_line + text_before_macro + macro_lines[0]
            macro_continued = macro_lines[1..-1].map do |macro_line|
              white_space + macro_line
            end
            (new_lines << new_line) + macro_continued
          else
            new_lines
          end
        end
      end
end
```

Finally, throughout this process, we have to be ware that a macro may have no content.  We must deal with `nil` and empty lists where they occur.

### Unescaping Double Parentheses

This is fairly self explanatory, gsub is global substitution.  We need three `\`s two to match the escape sequence for `\` in ruby and a third to handle the escaped `⦅` and `⦆` when this file itself is tangled.

###### Code Block: Unescape Double Parens

``` ruby
def unescape_double_parens(block)
  block.map do |l|
    l = l.gsub("\\\⦅", "⦅")
    l = l.gsub("\\\⦆", "⦆")
    l
  end
end

```

### Write The Output

Finally, if there is a default block, write the output.

###### Code Block: Write

``` ruby
def write(output)
  tangle() unless @tangled
  if @block
    fout = File.open(output, 'w')
    @block.each {|line| fout << line}
  end
end

```

## The Filters

The filters are instances of the Filter class which can be created by passing a block to the initializer of the class.  When the filter is executed, this block of code will be called on all of the lines of code being filtered.

###### Code Block: Filter Class

``` ruby
class Filter
  def initialize(&block)
    @code = block;
  end

  def filter(lines)
    @code.call(lines)
  end
end
```

Because it is fairly common to filter lines one at a time, LineFilter will pass in each line instead of the whole block.

###### Code Block: Filter Class

``` ruby
class LineFilter < Filter
  def filter(lines)
    lines.map do |line|
      @code.call(line)
    end
  end
end
```

Filters are applied by the following method:

###### Code Block: Apply Filters

``` ruby
def apply_filters(strings, filters)
  filters.map do |filter_name|
    filters_map[filter_name]
  end.inject(strings) do |strings, filter|
    filter.filter(strings)
  end
end
```

### Ruby Escape

Ruby escape escapes strings appropriately for Ruby.  

###### Code Block: Ruby Escape

``` ruby
LineFilter.new do |line|
  line.dump[1..-2]
end
```

### Double Quote

Double quote surrounds strings in double quotes

###### Code Block: Double Quote

``` ruby
LineFilter.new do |line|
  before_white = /^\s*/.match(line)[0]
  after_white = /\s*$/.match(line)[0]
  "#{before_white}\"#{line.strip}\"#{after_white}"
end
```

### Add Commas

Add commas adds comma to the end of each line.

###### Code Block: Add Comma

``` ruby
LineFilter.new do |line|
  before_white = /^\s*/.match(line)[0]
  after_white = /\s*$/.match(line)[0]
  "#{before_white}#{line.strip},#{after_white}"
end
```

### Indent continuation

Adds two spaces to the front of each line after the first

###### Code Block: Indent Continuation

``` ruby
Filter.new do |lines|
  [lines[0], *lines[1..-1].map {|l| "  #{l}"}]
end
```

### Indent Lines

Adds two spaces to the front of each line

###### Code Block: Indent Lines

``` ruby
LineFilter.new do |line|
  "  #{line}"
end
```

## Option Verification

Option verification is described here:

**See include:** [option_verification.lmd](include_file)

## Self Test, Details

So, now we need to go into details of our self test and also include regressions which have caused problems.

First, we need a method to report test failures:

**See include:** [error_reporting.lmd](include_file)

Then we need the tests we are doing.  The intentionally empty block is included both at the beginning and end to make sure that we handled all the edge cases related to empty blocks appropriately.

###### Code Block: Test Description

``` ruby
⦅intentionally_empty_block⦆
⦅test_macro_insertion_description⦆
⦅test_filters⦆
⦅test_inclusion⦆
⦅intentionally_empty_block⦆
⦅test_extensions⦆
```

### Testing: Macros

At [the top of the file](#Macros), we described the macros.  Lets make sure that works by ensuring the variables are as they were described above

###### Code Block: Test Macro Insertion Description

``` ruby
⦅macro_insertion_description⦆
# These require the code in the macro to work.
report_self_test_failure("block replacement doesn't work") unless block_replacement and replaced_block
report_self_test_failure("appending to macros doesn't work") unless block_appendment
report_self_test_failure("insertion must support spaces") unless insertion_works_with_spaces
report_self_test_failure("double parentheses may be escaped") unless escaped_string[0] != '\\'
```

Finally, we need to make sure two macros on the same line works.

###### Code Block: Test Macro Insertion Description

``` ruby
two_macros = "⦅foo⦆ ⦅foo⦆"
report_self_test_failure("Should be able to place two macros on the same line") unless two_macros == "foo foo"
```

For that to work we need:

###### Code Block: Insertion Works With Spaces

``` ruby
insertion_works_with_spaces = true
```

and

###### Code Block: Foo

``` ruby
foo
```

### Testing: Filters

At the [top of the file](Filters) we described the usage of filters.  Let's make sure that works.  The extra `.?` in the regular expression is a workaround for an editor bug in Visual Studio Code, where, apparently, `/\\/` escapes the `/` rather than the `\`.... annoying.

###### Code Block: Some Text

``` text
some text
```

###### Code Block: A List

``` text
item 1
item 2
```

###### Code Block: Test Filters

``` ruby
⦅filter_use_description⦆
report_self_test_failure("ruby escape doesn't escape backslash") unless string_with_backslash =~ /\\.?/
some_text = ⦅some_text | double_quote⦆
report_self_test_failure("Double quote doesn't double quote") unless some_text == "⦅some_text⦆"
some_indented_text = "⦅some_text | indent_lines⦆"
report_self_test_failure("Indent lines should add two spaces to lines") unless some_indented_text == "  ⦅some_text⦆"
items = [⦅a_list | double_quote | add_comma | indent_continuation⦆]
report_self_test_failure("Add comma isn't adding commas") unless items == ["item 1", "item 2"]
```

### Testing: Inclusion

###### Code Block: Test Inclusion

``` ruby
⦅included_block⦆
report_self_test_failure("included replacements should replace blocks") unless included_string == "I came from lmt_include.lmd"
```

### Testing: Extensions

###### Code Block: Test Extensions

``` ruby
⦅from_extension⦆
report_self_test_failure("extension hook should be able to add blocks") unless from_extension
```


### Regressions

Some regressions / edge cases that we need to watch for.  These should not break our tangle operation.

#### Empty Blocks

We need to be able to tangle empty blocks such as:

###### Code Block: Intentionally Empty Block

``` ruby
```

#### Unused blocks referencing nonexistent blocks

If a block is unused, then don't break if it uses a nonexistent block.

###### Code Block: Unused Block

``` ruby
⦅this_block_does_not_exist⦆
```

## Fin ┐( ˘_˘)┌

And with that, we have tangled a file.

At current, there are a few more features that would be nice to have. First, this does not yet support extension by commands.  Second, we cannot write to any file other than the output file.  Third, we don't have many filters.  These features can wait for now.

∎
