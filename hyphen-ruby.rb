#!/usr/bin/env ruby
## hyphen-ruby.rb --- hyphenate/dehyphenate identifiers in Ruby code
# Copyright (C) 2005  Daniel Brockman

# Author: Daniel Brockman <daniel@brockman.se>
# URL: <http://www.brockman.se/software/hyphen-ruby/hyphen-ruby>
# Updated: Sunday 2005-06-26 22:10

# This silliness is the result of me trying to move Ruby one
# additional tiny step in right direction (i.e., towards Lisp).
# The goal is simple:  Allow `foo-bar' as a synonym for `foo_bar'.

# This file is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

# This file is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this file; if not, write to The Free Software Foundation,
# 59 Temple Place - Suite 330, Boston MA, 02111-1307, USA.

## Usage:

# To use Hyphen-Ruby in your program, all you have to do is add the
# following three lines to the top of each entry-point file:

#    #!/usr/bin/ruby -rhyphen-ruby
#    # Don't let ruby see the below code.        -*- Hyphen-Ruby -*-
#    __END__

# (By ``entry-point file'' I mean any file `foo.rb' for which it makes
# sense to call `ruby foo.rb'.)

# The comment is just there to tell Emacs to use Hyphen-Ruby mode
# rather than plain old Ruby mode.  You can get that mode here:
# <http://www.brockman.se/software/hyphen-ruby/hyphen-ruby-mode.el>

# If you don't need to execute your scripts directly, and you don't
# like shebangs for some reason, you can get by without them:

#    require 'hyphen-ruby' # -*- Hyphen-Ruby -*-
#    # The following code needs to be processed by Hyphen-Ruby
#    # before the Ruby interpreter can be allowed to see it.
#    __END__

# In any case, the `__END__' token must appear somewhere in the
# prelude of the file --- before all the significant code --- and it
# must sit on a line all by itself (though you can put it after your
# file header, license blurb and disclaimer if you want).  As you will
# have figured out by now, its job is to prevent the Ruby interpreter
# from trying to parse the Hyphen-Ruby code.

# Actually, you can skip the `__END__' part if your whole entry-point
# file is formatted as vanilla Ruby code.  In this case, you don't
# have put _any_ weird stuff at the top of the file;

#    #!/usr/bin/env ruby
#    ## foo/bar.rb --- frob the thingamabob       -*- Hyphen-Ruby -*-
#    # Copyright (C) 2005  Joe Hacker
#    
#    require 'hyphen-ruby'

# you just have to make sure to load the `hyphen-ruby' library prior
# to loading any library whose source is formatted as Hyphen-Ruby.

# The Emacs magic string (or the equivalent for your text editor)
# still needs to go on the first line, because all files that are
# formatted as Hyphen-Ruby needs to have the string `hyphen-ruby'
# appear somewhere on the first line, or it won't be loaded properly.
# (I may consider relaxing this requirement if it gets annoying.)

# So that's about all you have to know to use this thing successfully.
# If you're curious about how it works, let me present... the code:

module HyphenRuby
  class RubyMonster
    def initialize options = {}
      @mode = options[:mode] || :dehyphenate
      @file_name = options[:file_name] || '(unknown file)'
      @line = 0
      input = options[:input] || STDIN
      output = options[:output] || STDOUT

      if input.kind_of? String
        @input = input
      elsif input.respond_to? :read
        @input = input.read
      else
        raise ArgumentError, 'expected String, IO, or something that ' +
          'supports `read\' for input'
      end

      if output.respond_to? :<<
        @output = output
      else
        raise ArgumentError, 'expected String, IO, or something that ' +
          'supports `<<\' for output'
      end
    end

    def looking_at? pattern
      case pattern
      when Regexp : @input =~ pattern
      when String : @input[0, pattern.size] == pattern
      end
    end

    def count_newlines string
      string.each_byte do |character|
        @line += 1 if character == ?\n
      end
    end

    def bite pattern
      case pattern
      when Regexp
        if @input =~ pattern
          fail 'tried to bite middle of input' unless $`.empty?
          @input = $'
          count_newlines $&
          return $&
        end
      when String
        if @input[0, pattern.size] == pattern
          @input.slice! 0, pattern.size
          count_newlines pattern
          return pattern
        end
      end
    end

    def chew pattern
      if chunk = bite(pattern)
        swallow yield(chunk)
      end
    end

    def swallow chunk
      @output << chunk
      return chunk
    end

    def copy *patterns
      if patterns.size == 1
        chew patterns.first do |x| x end
      else
        result = false
        result = true while patterns.any? { |x| copy x }
        return result
      end
    end

    def copy! string
      choke "expected \`#{string}'" unless copy string
    end

    def breathe
      copy(/\A\s+/, /\A#[^\n]*\n/)
    end

    def choke reason = 'choking on garbage'
      STDOUT.flush ; STDERR.puts ; STDERR.puts
      STDERR.puts "#@file_name:#@line"
      fail "#{reason}:\n" +
        '-' * 60 + "\n" + @input[0, 50] + "\n" + '-' * 60 + "\n"
    end

    PAIRS = { '(' => ')', '[' => ']',
              '{' => '}', '<' => '>', }

    # Copy an opening delimiter; return the sought closing delimiter.
    def copy_opening_delimiter
      delimiter = copy(/\A./)
      [PAIRS[delimiter] || delimiter, delimiter]
    end

    def copying_delimiters
      closing, opening = copy_opening_delimiter
      yield closing, opening ; copy! closing
    end

    def eat_identifier
      unless copy(/\A\$[^a-zA-Z]/)
        chew(/(?:@|@@|\$|:)?[a-zA-Z0-9_-]+[?!]?/) do |chunk|
          # Here's actually the point of this whole charade:
          case @mode
          when :hyphenate
            chunk.gsub(/([a-zA-Z0-9])_([a-zA-Z0-9])/, '\1-\2')
          when :dehyphenate
            chunk.gsub(/([a-zA-Z0-9])-([a-zA-Z0-9])/, '\1_\2')
          end
        end or choke
      end
    end

    def eat_hard_string
      copying_delimiters do |closing, _|
        copy(/\A[^#{closing}\\]+/, /\A\\./m)
      end
    end

    def eat_soft_string
      copying_delimiters do |closing, opening|
#         STDERR.puts 'CLOSING: ' + closing
#         STDERR.puts 'OPENING: ' + opening
        nesting = 1
        loop do
          copy(/\A[^#{closing}#{opening}\\#]+/, /\A\\./m)
          if copy '#'
            if looking_at? '{'
              eat_delimited_program
            elsif looking_at? '$' or looking_at? '@'
              eat_identifier
            end
          elsif looking_at? closing
            if nesting == 1
              break
            else
              nesting -= 1
              copy! closing
            end
          elsif copy opening
            nesting += 1
          end
        end
      end
    end

    def eat_delimited_program
      copying_delimiters { eat_program }
    end

    def eat_program
      while not @input.empty? do
        breathe
        case @input
        when /\A([a-zA-Z_$]|[:@][a-zA-Z])/
          eat_identifier
        when /\A('|%[qw])/ ; copy(/\A%./)
          eat_hard_string
        when /\A(["`]|%[Qx]|%[^a-zA-Z0-9]|\/\S)/ ; copy(/\A%[a-zA-Z0-9]?/)
          eat_soft_string
        when /\A[\[({]/
          eat_delimited_program
        else
          break unless copy(/\A\\./m) or copy(/\A\?(\S|\\.)/m) or
            copy(/\A(0[box])?([0-9a-f]_?)+(\.([0-9a-f]_?))?\b/i) or
            copy(/\A[-+\/*%=&|^!?~><,.;:]/)
        end
      end
    end

    def eat_input
      eat_program
      choke unless @input.empty?
    end
  end

  def self.find_file base_name
    if base_name =~ /^\//
      base_name
    else
      for directory in $: do
        for extension in ['', '.rb', '.o', '.dll', '.so'] do
          file_name = File.join directory, base_name + extension
          if FileTest.exists? file_name
            a = File.expand_path file_name
            b = File.expand_path base_name
            return a == b ? base_name : file_name
          end
        end
      end
    end
  end

  def self.hyphen_ruby_file? file_name
    open file_name do |file|
      return file.read(100) =~ /hyphen-ruby/i && true || false
    end rescue false
  end

  def self.load_hyphen_ruby file_name
    open file_name do |file|
      input = file.read
      input.sub! /^__END__$/, ''
      output = String.new
      monster = RubyMonster.new \
        :input => input, :file_name => file_name, :output => output
      monster.eat_input
      Object.module_eval output, file_name, 1
    end
  end

  def self.load base_name
    file_name = find_file base_name
    if hyphen_ruby_file? file_name
      load_hyphen_ruby file_name
    else
      __hyphen_ruby_load file_name
    end
  end

  def self.require base_name
    if $".include? base_name
      return true
    else
      file_name = find_file base_name
      if hyphen_ruby_file? file_name
        begin
          load_hyphen_ruby file_name
          $" << base_name
          return true
        rescue Errno::ENOENT
          return false
        end
      else
        __hyphen_ruby_require file_name
      end
    end
  end
end

if __FILE__ == $0
  require 'optparse'

  mode = :dehyphenate
  output = STDOUT

  OptionParser.new do |opts|
    opts.banner = "Usage: #$0 [OPTION]... [INPUT]"

    opts.separator ''
    opts.separator 'Options:'

    opts.on '--hyphenate', '-h', <<-EOF do
Convert identifiers to \`foo-bar-baz\' style.
EOF
      mode = :hyphenate
    end

    opts.on '--dehyphenate', '-d', <<-EOS do
Convert identifiers to \`foo_bar_baz\' style (this is the default).
EOS
      mode = :dehyphenate
    end

    opts.on '--output=FILE', '-o', <<-EOS do |file_name|
Write output to FILE instead of standard output.
EOS
      output = open file_name, 'w'
    end
  end.parse! ARGV

  case ARGV.size
  when 0
    input = STDIN
    file_name = '(standard input)'
  when 1
    input = open(ARGV.first) { |file| file.read }
    file_name = ARGV.first
  else
    STDERR.puts "#$0: cannot process multiple files at a time"
    exit 1
  end

  monster = HyphenRuby::RubyMonster.new \
    :input => input, :file_name => file_name,
    :output => output, :mode => mode
  monster.eat_input
else
  alias __hyphen_ruby_load load
  def load base_name, wrap = nil
    if wrap
      STDERR.puts 'hyphen-ruby: warning: using plain-old Kernel#load \
because the `wrap\' parameter is currently not supported'
      __hyphen_ruby_load base_name, wrap
    else
      HyphenRuby.load base_name
    end
  end

  alias __hyphen_ruby_require require
  def require base_name
    HyphenRuby.require base_name
  end

  HyphenRuby.load $0
end
