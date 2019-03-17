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
    included_string = "I came from lmt_include.lmd"
    report_self_test_failure("included replacements should replace blocks") unless included_string == "I came from lmt_include.lmd"

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
    class << self
      attr_reader :filters
    end
  
    @filters = {
      'ruby_escape' => LineFilter.new do |line|
        line.dump[1..-2]
      end
    }
  
    def initialize(input)
      @input = input
      @block = ""
      @blocks = {}
      @tangled = false
    end
    
    def tangle()
      contents = include_includes(read_file(@input))
      @block, @blocks = parse_blocks(contents)
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
    
    def parse_blocks(lines)
      code_block_exp = /^([s]*)``` ?([\w]*) ?(=?)([-\w]*)?/
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
        Tangler.filters[filter_name]
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