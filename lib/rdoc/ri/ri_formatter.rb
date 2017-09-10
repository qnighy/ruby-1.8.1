module RI
  class TextFormatter

    def TextFormatter.list
      "plain, bs, ansi"
    end

    def TextFormatter.for(name)
      case name
      when /plain/i then TextFormatter
      when /bs/i then OverstrikeFormatter
      when /ansi/i then AnsiFormatter
      else nil
      end
    end

    attr_reader :indent
    
    def initialize(options, indent)
      @options = options
      @width   = options.width
      @indent  = indent
    end
    
    
    ######################################################################
    
    def draw_line(label=nil)
      len = @width
      len -= (label.size+1) if label
      print "-"*len
      if label
        print(" ")
        bold_print(label) 
      end
      puts
    end
    
    ######################################################################
    
    def wrap(txt,  prefix=@indent, linelen=@width)
      return unless txt && !txt.empty?
      work = conv_markup(txt)
      textLen = linelen - prefix.length
      patt = Regexp.new("^(.{0,#{textLen}})[ \n]")
      next_prefix = prefix.tr("^ ", " ")

      res = []

      while work.length > textLen
        if work =~ patt
          res << $1
          work.slice!(0, $&.length)
        else
          res << work.slice!(0, textLen)
        end
      end
      res << work if work.length.nonzero?
      puts (prefix +  res.join("\n" + next_prefix))
    end

    ######################################################################

    def blankline
      puts
    end
    
    ######################################################################

    def bold_print(txt)
      print txt
    end

    ######################################################################

    # convert HTML entities back to ASCII
    def conv_html(txt)
      txt.
          gsub(/&gt;/, '>').
          gsub(/&lt;/, '<').
          gsub(/&quot;/, '"').
          gsub(/&amp;/, '&')
          
    end

    # convert markup into display form
    def conv_markup(txt)
      txt.
          gsub(%r{<tt>(.*?)</tt>}) { "+#$1+" } .
          gsub(%r{<code>(.*?)</code>}) { "+#$1+" } .
          gsub(%r{<b>(.*?)</b>}) { "*#$1*" } .
          gsub(%r{<em>(.*?)</em>}) { "_#$1_" }
    end

    ######################################################################

    def display_list(list)
      case list.type

      when SM::ListBase::BULLET 
        prefixer = proc { |ignored| @indent + "*   " }

      when SM::ListBase::NUMBER,
      SM::ListBase::UPPERALPHA,
      SM::ListBase::LOWERALPHA

        start = case list.type
                when SM::ListBase::NUMBER      then 1
                when  SM::ListBase::UPPERALPHA then 'A'
                when SM::ListBase::LOWERALPHA  then 'a'
                end
        prefixer = proc do |ignored|
          res = @indent + "#{start}.".ljust(4)
          start = start.succ
          res
        end
        
      when SM::ListBase::LABELED
        prefixer = proc do |li|
          li.label
        end

      when SM::ListBase::NOTE
        longest = 0
        list.contents.each do |item|
          if item.kind_of?(SM::Flow::LI) && item.label.length > longest
            longest = item.label.length
          end
        end

        prefixer = proc do |li|
          @indent + li.label.ljust(longest+1)
        end

      else
        fail "unknown list type"

      end

      list.contents.each do |item|
        if item.kind_of? SM::Flow::LI
          prefix = prefixer.call(item)
          display_flow_item(item, prefix)
        else
          display_flow_item(item)
        end
       end
    end

    ######################################################################

    def display_flow_item(item, prefix=@indent)
      case item
      when SM::Flow::P, SM::Flow::LI
        wrap(conv_html(item.body), prefix)
        blankline
        
      when SM::Flow::LIST
        display_list(item)

      when SM::Flow::VERB
        item.body.split(/\n/).each do |line|
          print @indent, conv_html(line), "\n"
        end
        blankline

      when SM::Flow::H
        display_heading(conv_html(item.text.join), item.level, @indent)
      else
        fail "Unknown flow element: #{item.class}"
      end
    end

    ######################################################################

    def display_heading(text, level, indent)
      case level
      when 1
        ul = "=" * text.length
        puts
        puts text.upcase
        puts ul
#        puts
        
      when 2
        ul = "-" * text.length
        puts
        puts text
        puts ul
#        puts
      else
        print indent, text, "\n"
      end
    end

    ######################################################################

    def display_flow(flow)
      flow.each do |f|
        display_flow_item(f)
      end
    end
  end
  
  
  # Handle text with attributes. We're a base class: there are
  # different presentation classes (one, for example, uses overstrikes
  # to handle bold and underlinig, while another using ANSI escape
  # sequences
  
  class AttributeFormatter < TextFormatter
    
    BOLD      = 1
    ITALIC    = 2
    CODE      = 4

    ATTR_MAP = {
      "b"    => BOLD,
      "code" => CODE,
      "em"   => ITALIC,
      "i"    => ITALIC,
      "tt"   => CODE
    }

    # TODO: struct?
    class AttrChar
      attr_reader :char
      attr_reader :attr

      def initialize(char, attr)
        @char = char
        @attr = attr
      end
    end

    
    class AttributeString
      def initialize
        @txt = []
        @optr = 0
      end

      def <<(char)
        @txt << char
      end

      def empty?
        @optr >= @txt.length
      end

      # accept non space, then all following spaces
      def next_word
        start = @optr
        len = @txt.length

        while @optr < len && @txt[@optr].char != " "
          @optr += 1
        end

        while @optr < len && @txt[@optr].char == " "
          @optr += 1
        end

        @txt[start...@optr]
      end
    end

    ######################################################################
    # overrides base class. Looks for <tt>...</tt> etc sequences
    # and generates an array of AttrChars. This array is then used
    # as the basis for the split

    def wrap(txt,  prefix=@indent, linelen=@width)
      return unless txt && !txt.empty?

      txt = add_attributes_to(txt)

      line = []

      until txt.empty?
        word = txt.next_word
        if word.size + line.size > linelen - @indent.size
          write_attribute_text(line)
          line = []
        end
        line.concat(word)
      end

      write_attribute_text(line) if line.length > 0
    end

    protected

    # overridden in specific formatters

    def write_attribute_text(line)
      print @indent
      line.each do |achar|
        print achar.char
      end
      puts
    end

    # again, overridden

    def bold_print(txt)
      print txt
    end

    private

    def add_attributes_to(txt)
      tokens = txt.split(%r{(</?(?:b|code|em|i|tt)>)})
      text = AttributeString.new
      attributes = 0
      tokens.each do |tok|
        case tok
        when %r{^</(\w+)>$} then attributes &= ~(ATTR_MAP[$1]||0)
        when %r{^<(\w+)>$}  then attributes  |= (ATTR_MAP[$1]||0)
        else
          tok.split(//).each {|ch| text << AttrChar.new(ch, attributes)}
        end
      end
      text
    end

  end


  ##################################################
  
  # This formatter generates overstrike-style formatting, which
  # works with pages such as man and less.

  class OverstrikeFormatter < AttributeFormatter

    BS = "\C-h"

    def write_attribute_text(line)
      print @indent
      line.each do |achar|
        attr = achar.attr
        if (attr & (ITALIC+CODE)) != 0
          print "_", BS
        end
        if (attr & BOLD) != 0
          print achar.char, BS
        end
        print achar.char
      end
      puts
    end

    # draw a string in bold
    def bold_print(text)
      text.split(//).each do |ch|
        print ch, BS, ch
      end
    end
  end

  ##################################################
  
  # This formatter uses ANSI escape sequences
  # to colorize stuff
  # works with pages such as man and less.

  class AnsiFormatter < AttributeFormatter

    BS = "\C-h"

    def initialize(*args)
      print "\033[0m"
      super
    end

    def write_attribute_text(line)
      print @indent
      curr_attr = 0
      line.each do |achar|
        attr = achar.attr
        if achar.attr != curr_attr
          update_attributes(achar.attr)
          curr_attr = achar.attr
        end
        print achar.char
      end
      update_attributes(0) unless curr_attr.zero?
      puts
    end


    def bold_print(txt)
      print "\033[1m#{txt}\033[m"
    end

    HEADINGS = {
      1 => "\033[1;32m%s\033[m",
      2 => "\033[4;32m%s\033[m",
      3 => "\033[32m%s\033[m"
    }

    def display_heading(text, level, indent)
      level = 3 if level > 3
      print indent
      printf(HEADINGS[level], text)
      puts
    end
    
    private

    ATTR_MAP = {
      BOLD   => "1",
      ITALIC => "33",
      CODE   => "36"
    }

    def update_attributes(attr)
      str = "\033["
      for quality in [ BOLD, ITALIC, CODE]
        unless (attr & quality).zero?
          str << ATTR_MAP[quality]
        end
      end
      print str, "m"
    end
  end

# options = "options"
# def options.width
#   70
# end
# a = OverstrikeFormatter.new(options, "   ")  
# a.wrap(
# "The quick <b>brown</b> and <i>italic</i> dog " +
# "The quick <b>brown and <i>italic</i></b> dog " +
# "The quick <b>brown and <i>italic</i></b> dog " +
# "The quick <b>brown and <i>italic</i></b> dog " +
# "The quick <b>brown and <i>italic</i></b> dog " +
# "The quick <b>brown and <i>italic</i></b> dog " +
# "The quick <b>brown and <i>italic</i></b> dog " +
# "The quick <b>brown and <i>italic</i></b> dog " +
# "The quick <b>brown and <i>italic</i></b> dog " +
# "The quick <b>brown and <i>italic</i></b> dog " +
# "The quick <b>brown and <i>italic</i></b> dog " 
# )
end


