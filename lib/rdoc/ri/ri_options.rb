# We handle the parsing of options, and subsequently as a singleton
# object to be queried for option values

module RI

  VERSION_STRING = "alpha 0.1"

  class Options
    
    require 'singleton'
    require 'getoptlong'
    
    include Singleton

    # No not use a pager. Writable, because ri sets it if it
    # can't find a pager
    attr_accessor :use_stdout

    # The width of the output line
    attr_reader :width

    # the formatting we apply to the output
    attr_reader :formatter

    module OptionList
      
      OPTION_LIST = [
        [ "--help",          "-h",   nil,
         "you're looking at it" ],

        [ "--format",       "-f",   "<name>",
         "Format to use when displaying output:\n" +
         "   " + RI::TextFormatter.list + "\n" +
         "Use 'bs' (backspace) with most pager programs.\n" +
         "To use ANSI, either also use the -T option, or\n\n" +
         "tell your pager to allow control characters\n" +
         "(for example using the -R option to less)"],

        [ "--no-pager",      "-T",   nil,
          "Send output directly to stdout." 
        ],

        [ "--width",         "-w",   "output width",
        "set the width of the output" ],

      ]

      def OptionList.options
        OPTION_LIST.map do |long, short, arg,|
          [ long, 
           short, 
           arg ? GetoptLong::REQUIRED_ARGUMENT : GetoptLong::NO_ARGUMENT 
          ]
        end
      end


      def OptionList.strip_output(text)
        text =~ /^\s+/
        leading_spaces = $&
        text.gsub!(/^#{leading_spaces}/, '')
        $stdout.puts text
      end
      
      
      # Show an error and exit
      
      def OptionList.error(msg)
        $stderr.puts
        $stderr.puts msg
        $stderr.puts "\nFor help on options, try 'ri --help'\n\n"
        exit 1
      end
      
      # Show usage and exit
      
      def OptionList.usage(short_form=false)
        
        puts
        puts(RI::VERSION_STRING)
        puts
        
        name = File.basename($0)
        OptionList.strip_output(<<-EOT)
          Usage:

            #{name} [options]  [names...]

          Display information on Ruby classes, modules, and methods.
          Give the names of classes or methods to see their documentation.
          Partial names may be given: if the names match more than
          one entity, a list will be shown, otherwise details on
          that entity will be displayed.

          Nested classes and modules can be specified using the normal
          Name::Name notation, and instance methods can be distinguished
          from class methods using "." (or "#") instead of "::".

          For example:

              ri  File
              ri  File.new
              ri  F.n
              ri  zip

          Note that shell quoting may be required for method names
          containing puncuation:

              ri 'Array.[]'
              ri compact\\!

      EOT

      if short_form
        class_list
        puts "For help, type 'ri -h'"
      else
        puts "Options:\n\n"
        OPTION_LIST.each do |long, short, arg, desc|
          opt = sprintf("%20s", "#{long}, #{short}")
          oparg = sprintf("%-7s", arg)
          print "#{opt} #{oparg}"
          desc = desc.split("\n")
          if arg.nil? || arg.length < 7  
            puts desc.shift
          else
            puts
          end
          desc.each do |line|
            puts(" "*28 + line)
          end
          puts
        end

        exit 0
      end
    end

    def OptionList.class_list
      paths = RI::Paths::PATH
      if paths.empty?
        puts "Before using ri, you need to generate documentation"
        puts "using 'rdoc' with the --ri option"
      else
        @ri_reader = RI::RiReader.new(RI::RiCache.new(paths))
        puts
        puts "Classes and modules I know about:"
        puts
        puts @ri_reader.class_names.sort.join(", ")
        puts
      end
    end

  end

    # Parse command line options.

    def parse

      @use_stdout = !STDOUT.tty?
      @width = 72
      @formatter = RI::TextFormatter.for("plain") 

      begin
        
        go = GetoptLong.new(*OptionList.options)
        go.quiet = true
        
        go.each do |opt, arg|
          case opt
          when "--help"      then OptionList.usage
          when "--no-pager"  then @use_stdout = true
          when "--format"
            @formatter = RI::TextFormatter.for(arg)
            unless @formatter
              $stderr.print "Invalid formatter (should be one of "
              $stderr.puts RI::TextFormatter.list + ")"
              exit 1
            end
          when "--width"
            begin
              @width = Integer(arg)
            rescue 
              $stderr.puts "Invalid width: '#{arg}'"
              exit 1
            end
          end
        end
        
      rescue GetoptLong::InvalidOption, GetoptLong::MissingArgument => error
        OptionList.error(error.message)
        
      end
    end
  end
end

