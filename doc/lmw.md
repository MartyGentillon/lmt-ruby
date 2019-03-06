# Lmw-Ruby

###### Code Block: Description

``` text
A literate Markdown weave tool written in Ruby.
```

Lmw is a literate Markdown weave program for [literate programing](https://en.wikipedia.org/wiki/Literate_programming).  This is a fairly simple program designed to turn a literate Markdown file into a more normal Markdown file without the special semantics.  It is interprets the Markdown as described in [lmt-ruby](lmt.lmd).  The primary changes to the output is that the header for code blocks is extracted and rendered in standard Markdown.  File names are also changed from .lmd to .md.  This change is also applied to links.

## Features

In order to effectively weave a lmt file we must:

1) Replace the lmt headers with something that a standard markdown parser will make sense of.
2) Replace include directives with a more informative text.
3) Update all links to .lmd files with a similar link to a .md file.

A few nice to have features:

1) Links between reopenings of a given block in the lmw output.
2) Add links from macro substitutions to the body of the macro.
3) syntax verification: check for balanced code fences, make sure that all reopenings of a block are in the same language, etc.

Ideally, any links between and to blocks would also go to included files.

Currently, it puts headers on blocks, and replaces include directives with a more human version.

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

Now for an example in implementation.  Using Ruby we can write a template as below:

###### Output Block

``` ruby
#!/usr/bin/env ruby
# Encoding: utf-8

⦅includes⦆

class App
  include Methadone::Main
  include Methadone::CLILogging

  @dev = true

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

  ⦅weave_class⦆

  ⦅option_verification⦆

  description "⦅description⦆"
  ⦅options⦆

  version Lmt::VERSION

  use_log_level_option :toggle_debug_on_signal => 'USR1'

  go! if __FILE__ == $0
end

```

This is a basic template using the [Ruby methadone](https://github.com/davetron5000/methadone) command line application framework and making sure that we report errors (because silent failure sucks).

The main body will first test itself then, invoke the library component, which isn't in lib as traditional because it is in this file and I don't want to move it around.

###### Code Block: Main Body

``` ruby
self_test()
weave = App::Weave.from_file(options[:file])
weave.weave()
weave.write(options[:output])
```

Finally, we have the dependencies.  Optparse and methadone are used for cli argument handling and other niceties.

###### Code Block: Includes

``` ruby
require 'optparse'
require 'methadone'

require 'pry'
```

There, now we are done with the boilerplate. On to:

## The Actual Weaver

The weaver is defined within a class that contains the weaving implementation

###### Code Block: Weave Class

``` ruby
class Weave
  class << self
    ⦅from_file⦆
  end

  ⦅initializer⦆
  ⦅weave⦆
  ⦅write⦆

  private
  ⦅weave_class_privates⦆
end
```

There may be some private methods, we need a block for them.  They will be inserted where needed.

###### Code Block: Weave Class Privates

``` ruby
⦅include_includes⦆
```

### Initializer

The initializer takes the input file and sets up our state.  

###### Code Block: Initializer

``` ruby
def initialize(lines, file_name = "")
  @file_name = file_name
  @lines = lines
  @weaved = false
end
```

#### Factory

For testing, we want to be able to create an instance with a hard coded set of lines.  Furthermore, because this processing is stateful, we want to make the input immutable.  Reading from a file needs to be handled.  A factory can do it.

##### Reading the File

This is fairly self explanatory, though note, we are storing the file in memory as an array of lines.

###### Code Block: From File

``` ruby
def from_file(file)
  File.open(file, 'r') do |f|
    Weave.new(f.readlines, file)
  end
end

```

### Weave

To weave a file, first we have to identify and construct metadata on all the blocks.  Then we use that metadata to transform any lines containing a block declaration into an appropriate header for that block.  Finally, we replace any links to an .lmd file with the equivalent .md link.

###### Code Block: Weave

``` ruby
def weave()
  @blocks = find_blocks(@lines)
  @weaved_lines = substitute_directives_and_headers(
    @lines.map do |line|
      replace_markdown_links(line)
    end)
  @weaved = true
end
```

#### Finding the Blocks

In order to find the blocks we will need the regular expressions defined in:

**See include:** [lmt_expressions.lmd](include_file)

First, we get the lines from includes.  then we filter the lines for only the headers and footers and check for unmatched headers and footers.

###### Code Block: Weave Class Privates

``` ruby
def find_blocks(lines)
  lines_with_includes = include_includes(lines)
  code_block_exp = ⦅code_block_expression⦆
  headers_and_footers = lines_with_includes.filter do |(line, source_file)|
    code_block_exp =~ line
  end
  throw "Missing code fence" if headers_and_footers.length % 2 != 0
```

Now, we throw out all the footers and use the code_block_exp to parse them, group them by name, and generate the metadata.  In this case the metadata includes 1) a count of the number of blocks with a particular name in this file. 2) the source file of each block.

We are also validating that a block only has one language.

###### Code Block: Weave Class Privates

``` ruby
  headers_and_footers.each_slice(2).map(&:first)
      .map do |(header, source_file)|
        white_space, language, replacement_mark, name = code_block_exp.match(header)[1..-1]
        [name, source_file, language, replacement_mark]
      end.group_by do |name, _, _, _|
        name
      end.transform_values do |blocks|
        block_name, _, block_language, _ = blocks[0]
        count, _ = blocks.inject(0) do |count, (name, source_file, language, replacement_mark)|
          throw "block #{block_name} has multiple languages" unless language == block_language
          count + 1
        end
        block_locations = blocks.each_with_index.map do |(name, source_file, language, replacement_mark), index|
          [name, index, source_file]
        end
        {:count => count, :block_locations => block_locations}
      end
end
```

### Including the Includes

This depends on the expression in [lmt_expressions][lmt_expressions.md#The-Include-Expression]

Here we go through each line looking for an include statement.  When we find one, we replace it with the lines from that file.  Those lines will, of course, need to have includes processed as well.  For each line, we also need to add the file that it came from.

###### Code Block: Include Includes

``` ruby
def include_includes(lines, current_file = @file_name, current_path = '', depth = 0)
  raise "too many includes" if depth > 1000
  include_exp = ⦅include_expression⦆
  lines.map do |line|
    match = include_exp.match(line)
    if match
      file = File.dirname(current_file) + '/' + match[1]
      path = File.dirname(current_path) + '/' + match[1]
      new_lines = File.open(file, 'r') {|f| f.readlines}
      include_includes(new_lines, file, path, depth + 1)
    else
      [[line, current_path]]
    end
  end.flatten(1)
end

```

### Substituting the Directives and Headers

Now we need to substitute both the directives and headers with appropriate markdown replacements.  To do so we need the [include expression](lmt_expressions.lmd#The-Include-Expression) and the [code block expression](lmt_expressions.lmd#The-Code-Block-Expression).

We will match the lines against the expressions and, when a match occurs, we will substitute the appropriate template.  There is a little complexity when dealing with entering and exiting code fences.  Specifically, we will need to toggle between entering and exiting code fence behavior.

###### Code Block: Weave Class Privates

``` ruby
def substitute_directives_and_headers(lines)
  include_expression = ⦅include_expression⦆
  code_block_expression = ⦅code_block_expression⦆
  in_block = false
  block_name = ""
  lines.map do |line|
    case line
    when include_expression
      include_file = $1
      ["**See include:** [#{include_file}](include_file)\n"]
    when code_block_expression
      in_block = !in_block
      if in_block
        ⦅make_code_block_header⦆
      else
        [line]
      end
    else
      [line]
    end
  end.flatten(1)
end
```

#### The header for code blocks

Code blocks need to be headed appropriately as markdown parsing eats the code block name.  Because of this we put it in a `h6` header.  When the block is repeated, we add a `(part n)` to the end.  We also should be adding links for the next and last version of this header.

###### Code Block: Make Code Block Header

``` ruby
white_space, language, replacement_mark, name =
  code_block_expression.match(line)[1..-1]
human_name = name.gsub(/[-_]/, ' ').split(' ').map(&:capitalize).join(' ')
replacing = if replacement_mark == "="
      " Replacing"
    else
      ""
    end
header = if name != ""
  "#######{replacing} Code Block: #{human_name}\n\n"
else
  "#######{replacing} Output Block\n\n"
end
[header,
  "#{white_space}``` #{language}\n"]
```

### Replacing the Markdown Links

###### Code Block: Weave Class Privates

``` ruby
def replace_markdown_links(line)
  line
end
```

### Write The Output

Finally, write the output.

###### Code Block: Write

``` ruby
def write(output)
  fout = File.open(output, 'w')
  weave() unless @weaved
  @weaved_lines.each {|line| fout << line}
end

```

## Option Verification

Option verification is described here:

**See include:** [option_verification.lmd](include_file)

## Testing

Of course, we will also need a testing procedure.  In this case, we will be passing a set of strings in to the weave and seeing if the output is sane.

First, we need a method to report test failures:

**See include:** [error_reporting.lmd](include_file)

###### Code Block: Self Test

``` ruby
def self.self_test()
end
```

## Fin ┐( ˘_˘)┌

And with that, we have weaved some Markdown.

∎
