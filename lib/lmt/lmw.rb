#!/usr/bin/env ruby
# Encoding: utf-8

require 'optparse'
require 'methadone'
require 'lmt/version'
require 'pry'
require 'pathname'

module Lmt

class Lmw
  include Methadone::Main
  include Methadone::CLILogging

  @dev = true

  main do
    check_arguments()
    begin
      self_test()
      include_path = (options[:"include-path"] or [])
      weave = Lmw::Weave.from_file(options[:file], include_path)
      weave.weave()
      weave.write(options[:output])
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
  end

  def self.report_self_test_failure(message)
    if @dev
      p message
    else
      throw message
    end
  end

  class Weave
    class << self
      def from_file(file, include_path = [])
        File.open(file, 'r') do |f|
          Weave.new(f.readlines, file, include_path)
        end
      end
      
    end
  
    def initialize(lines, file_name = "", include_path = [])
      @include_path = include_path
      @file_name = file_name
      @lines = lines
      @weaved = false
    end
    def weave()
      @blocks = find_blocks(@lines)
      @weaved_lines = substitute_directives_and_headers(
        @lines.map do |line|
          replace_markdown_links(line)
        end)
      @weaved = true
    end
    def write(output)
      fout = File.open(output, 'w')
      weave() unless @weaved
      @weaved_lines.each {|line| fout << line}
    end
    
  
    private
    def find_blocks(lines)
      lines_with_includes = include_includes(lines)
      code_block_exp = /^(\s*)``` ?([\w]*) ?(=?)([-\w]*)?/
      headers_and_footers = lines_with_includes.filter do |(line, source_file)|
        code_block_exp =~ line
      end
      throw "Missing code fence" if headers_and_footers.length % 2 != 0
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
    def include_includes(lines, current_file = @file_name, current_path = '', depth = 0)
      raise "too many includes" if depth > 1000
      include_exp = /^!\s+include\s+\[.*\]\((.*)\)\s*$/
      include_path_exp = /^!\s+include-path\s+(.*)\s*$/
      lines.map do |line|
        include_path_match = include_path_exp.match(line)
        include_match = include_exp.match(line)
        if include_path_match
          path = resolve_include(include_path_match[1], current_file)[0]
          @include_path << path
          [[line,current_path]]
        elsif include_match
          file, path = resolve_include(include_match[1], current_file)
          new_lines = File.open(file, 'r') {|f| f.readlines}
          include_includes(new_lines, file, path, depth + 1)
        else
          [[line, current_path]]
        end
      end.flatten(1)
    end
    
    def substitute_directives_and_headers(lines)
      include_expression = /^!\s+include\s+\[.*\]\((.*)\)\s*$/
      code_block_expression = /^(\s*)``` ?([\w]*) ?(=?)([-\w]*)?/
      extension_block_expression = /^(\s*)``` ruby !/
      in_block = false
      block_name = ""
      lines.map do |line|
        case line
        when include_expression
          include_file = $1
          include_path = resolve_include(include_file, @file_name)[1]
          ["**See include:** [included file](#{include_path.gsub(/\.lmd/, ".md")})\n"]
        when code_block_expression
          in_block = !in_block
          if in_block
            if line =~ extension_block_expression
              white_space = extension_block_expression.match(line)[1]
              header = "###### Execute Extension Block\n\n"
              [header, "#{white_space}``` ruby\n"]
            else
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
            end
          else
            [line]
          end
        else
          [line]
        end
      end.flatten(1)
    end
    def replace_markdown_links(line)
      line
    end
    def resolve_include(file, current_file)
      include_file_loc = File.join(File.dirname(current_file), file)
      if File.exist?(include_file_loc)
        return [include_file_loc, file]
      end
      @include_path.each do |include_dir|
        include_file_loc = File.join(include_dir, file)
        if File.exist? (include_file_loc)
          relative_path = Pathname.new(include_file_loc).relative_path_from(File.dirname(current_file)).to_s
          return [include_file_loc, relative_path]
        end
      end
      throw "include file: #{file} not found from #{current_file} or in #{@include_path}"
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

  description "A literate Markdown weave tool written in Ruby."
  on("--file FILE", "-f", "Required: input file")
  on("--output FILE", "-o", "Required: output file")
  on("--include-path DIRECTORY,DIRECTORY", "-i", Array, "Include path")
  on("--dev", "disables self test failure for development")
  required(:file, :output)

  version Lmt::VERSION

  use_log_level_option :toggle_debug_on_signal => 'USR1'

  go! if __FILE__ == $0
end

end