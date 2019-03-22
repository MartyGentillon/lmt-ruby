#!/usr/bin/env ruby
# Encoding: utf-8

require 'optparse'
require 'methadone'
require 'lmt/version'

module Lmt

class Tangle
  include Methadone::Main
  include Methadone::CLILogging

  @dev = false

  main do
    check_arguments()
    begin
      @dev = options[:dev]
      self_test()
      tangler = Tangle::Tangler.new(options[:file])
      tangler.tangle()
      tangler.write(options[:output])
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

  def self.self_test()
    
    block_replacement = true
    replaced_block = false
    block_appendment = false
    
    # this is the replacement
    replaced_block = true
    # Yay appended code gets injected
    block_appendment = true
    insertion_works_with_spaces = false
    insertion_works_with_spaces = true
    escaped_string = '⦅macro_description⦆'
    # These require the code in the macro to work.
    report_self_test_failure("block replacement doesn't work") unless block_replacement and replaced_block
    report_self_test_failure("appending to macros doesn't work") unless block_appendment
    report_self_test_failure("insertion must support spaces") unless insertion_works_with_spaces
    report_self_test_failure("double parentheses may be escaped") unless escaped_string[0] != '\\'
    two_macros = "foo foo"
    report_self_test_failure("Should be able to place two macros on the same line") unless two_macros == "foo foo"
    string_with_backslash = "this string ends in \\."
    report_self_test_failure("ruby escape doesn't escape backslash") unless string_with_backslash =~ /\\.?/
    some_text = "some text"
    report_self_test_failure("Double quote doesn't double quote") unless some_text == "some text"
    some_indented_text = "  some text"
    report_self_test_failure("Indent lines should add two spaces to lines") unless some_indented_text == "  some text"
    items = ["item 1",
      "item 2",]
    report_self_test_failure("Add comma isn't adding commas") unless items == ["item 1", "item 2"]
    included_string = "I came from lmt_include.lmd"
    report_self_test_failure("included replacements should replace blocks") unless included_string == "I came from lmt_include.lmd"
    
    from_extension = true

    report_self_test_failure("extension hook should be able to add blocks") unless from_extension
    conditional_output_else = true
    conditional_output_elsif = true
    report_self_test_failure("conditional output elseif should not be output when elseif is false") unless conditional_output_elsif
    report_self_test_failure("conditional output else should not be output when if true") unless conditional_output_else
    conditional_output_else = true
    conditional_output_elsif = true
    report_self_test_failure("conditional output elsif should not be output even if true when is also true") unless conditional_output_elsif
    report_self_test_failure("conditional output else should not be output when if is true (if and elseif)") unless conditional_output_else
    conditional_output_if = true
    conditional_output_else = true
    conditional_output_elsif = true
    report_self_test_failure("conditional output if should not be output when false") unless conditional_output_if
    report_self_test_failure("conditional output elseif should be output when elseif is true") unless conditional_output_elsif
    report_self_test_failure("conditional output else should not be output when elseif is true") unless conditional_output_else
    conditional_output_if = true
    conditional_output_elsif = true
    conditional_output_else = true
    report_self_test_failure("conditional output if should not be output when false") unless conditional_output_if
    report_self_test_failure("conditional output elseif should not be output when elseif is false") unless conditional_output_elsif
    report_self_test_failure("conditional output else should be output when neither if nor elseif is true") unless conditional_output_else
  end

  def self.report_self_test_failure(message)
    if @dev
      p message
    else
      throw message
    end
  end
  
  class Filter
    def initialize(&block)
      @code = block;
    end
  
    def filter(lines)
      @code.call(lines)
    end
  end
  class LineFilter < Filter
    def filter(lines)
      lines.map do |line|
        @code.call(line)
      end
    end
  end

  class Tangler
    def initialize(input)
      @extension_context = Context.new()
      @extension_context.filters = {
        'ruby_escape' => LineFilter.new do |line|
          line.dump[1..-2]
        end,
        'double_quote' => LineFilter.new do |line|
          before_white = /^\s*/.match(line)[0]
          after_white = /\s*$/.match(line)[0]
          "#{before_white}\"#{line.strip}\"#{after_white}"
        end,
        'add_comma' => LineFilter.new do |line|
          before_white = /^\s*/.match(line)[0]
          after_white = /\s*$/.match(line)[0]
          "#{before_white}#{line.strip},#{after_white}"
        end,
        'indent_continuation' => Filter.new do |lines|
          [lines[0], *lines[1..-1].map {|l| "  #{l}"}]
        end,
        'indent_lines' => LineFilter.new do |line|
          "  #{line}"
        end
      }
      @input = input
      @block = ""
      @blocks = {}
      @tangled = false
    end
    
    def tangle()
      contents =  handle_extensions_and_conditionals(
          include_includes(read_file(@input)))
      @block, @blocks = @extension_context.parse_hook(*parse_blocks(contents))
      if @block
        @block = expand_macros(@block)
        @block = unescape_double_parens(@block)
      end
      @tangled = true
    end
    
    def read_file(file)
      File.open(file, 'r') do |f|
        f.readlines
      end
    end
    
    def include_includes(lines, current_file = @input, depth = 0)
      raise "too many includes" if depth > 1000
      include_exp = /^!\s+include\s+\[.*\]\((.*)\)\s*$/
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
    
    def handle_extensions_and_conditionals(lines)
      extension_expression = /^(\s*)``` ruby !/
      condition_processor = ConditionalProcessor.new(@extension_context)
      extension_exit_expression = /```/
      in_extension_block = false
      current_extension_block = []
    
      other_lines = lines.lazy
        .find_all do |line|
          condition_processor.should_output(line)
        end.find_all do |line|
          unless in_extension_block
            in_extension_block = line =~ extension_expression
            if in_extension_block
              current_extension_block = []
            end
            !in_extension_block
          else
            in_extension_block = !(line =~ extension_exit_expression)
            if in_extension_block
              current_extension_block << line
            else
              @extension_context.get_binding.eval(current_extension_block.join)
            end
            false
          end
        end.force
    
      condition_processor.check_block_balance()
    
      other_lines
    end
    
    def parse_blocks(lines)
      code_block_exp = /^(\s*)``` ?([\w]*) ?(=?)([-\w]*)?/
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
    
    def apply_filters(strings, filters)
      filters.map do |filter_name|
        filters_map[filter_name]
      end.inject(strings) do |strings, filter|
        filter.filter(strings)
      end
    end
    def unescape_double_parens(block)
      block.map do |l|
        l = l.gsub("\\⦅", "⦅")
        l = l.gsub("\\⦆", "⦆")
        l
      end
    end
    
    def write(output)
      tangle() unless @tangled
      if @block
        fout = File.open(output, 'w')
        @block.each {|line| fout << line}
      end
    end
    
  
    private
    def filters_map
      @extension_context.filters
    end
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
    
    def expand_macro_on_line(line, depth)
      white_space_exp = /^(\s*)(.*\n?)/
      macro_substitution_exp = /(?<!\\)⦅ *([-\w | ]*) *⦆/
      filter_extraction_exp = / *\| *([-\w]+) */
      white_space, text = white_space_exp.match(line)[1..2]
      section = text.split(macro_substitution_exp)
          .each_slice(2)
          .map do |(text_before_macro, macro_match)|
            if (macro_match)
              macro_name, *filters = macro_match.strip.split(filter_extraction_exp)
              [text_before_macro, macro_name, filters.each_slice(2).map(&:first)]
            else
              [text_before_macro]
            end
          end.inject([white_space]) do
            |(*new_lines, last_line), (text_before_macro, macro_name, filters)|
            if macro_name.nil?
              last_line = "" unless last_line
              new_lines << last_line + text_before_macro
            else
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
  
    class ConditionalProcessor
    
      def initialize(extension_context)
        @if_expression = /^!\s+if\s+(.*)$/
        @elsif_expression = /^!\s+elsif\s+(.*)$/
        @else_expression = /^!\s+else/
        @end_expression = /^!\s+end$/
        @output_enabled = true
        @stack = []
        @extension_context = extension_context
      end
    
      def should_output(line)
        case line
          when @if_expression
            condition = $1
            prior_state = @output_enabled
            @output_enabled = !!@extension_context.get_binding.eval(condition)
            @stack.push([:if, prior_state, !@output_enabled])
          when @elsif_expression
            throw "elsif statement missing if"  if @stack.empty?
            condition = $1
            type, prior_state, execute_else = @stack.pop()
            @output_enabled = execute_else && !!@extension_context.get_binding.eval(condition)
            @stack.push([type, prior_state, execute_else && !@output_enabled])
          when @else_expression
            throw "else statement missing if" if @stack.empty?
            type, prior_state, execute_else = @stack.pop()
            @output_enabled = execute_else
            @stack.push([type, prior_state, execute_else])
          when @end_expression
            throw "end statement missing begin" if @stack.empty?
            type, prior_state, execute_else = @stack.pop()
            @output_enabled = prior_state
        end
        @output_enabled
      end
      
      def check_block_balance
        throw "unbalanced blocks" unless @stack.empty?
      end
    end
    
  end

  class Context
    attr_accessor :filters
  
    def get_binding
      binding
    end
  
    def parse_hook(main_block, blocks)
      [main_block, blocks]
    end
  end
  

  def self.required(*options)
    @required_options = options
  end
  
  def self.check_arguments
    missing = @required_options.select{ |p| options[p].nil?}
    unless missing.empty?
      message = "Missing Required Argument(s): #{missing.join(', ')}"
  
      abort("#{message}\n\n#{opts.help()}")
    end
  end

  description "A literate Markdown tangle tool written in Ruby."
  on("--file FILE", "-f", "Required: input file")
  on("--output FILE", "-o", "Required: output file")
  on("--dev", "disables self test failure for development")
  required(:file, :output)

  version Lmt::VERSION

  use_log_level_option :toggle_debug_on_signal => 'USR1'

  go! if __FILE__ == $0
end

end
