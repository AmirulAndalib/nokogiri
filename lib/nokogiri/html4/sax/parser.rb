# frozen_string_literal: true

module Nokogiri
  module HTML4
    ###
    # Nokogiri lets you write a SAX parser to process HTML but get HTML correction features.
    #
    # See Nokogiri::HTML4::SAX::Parser for a basic example of using a SAX parser with HTML.
    #
    # For more information on SAX parsers, see Nokogiri::XML::SAX
    module SAX
      ###
      # This parser is a SAX style parser that reads its input as it deems necessary. The parser
      # takes a Nokogiri::XML::SAX::Document, an optional encoding, then given an HTML input, sends
      # messages to the Nokogiri::XML::SAX::Document.
      #
      # ⚠ This is an HTML4 parser and so may not support some HTML5 features and behaviors.
      #
      # Here is a basic usage example:
      #
      #   class MyDoc < Nokogiri::XML::SAX::Document
      #     def start_element name, attributes = []
      #       puts "found a #{name}"
      #     end
      #   end
      #
      #   parser = Nokogiri::HTML4::SAX::Parser.new(MyDoc.new)
      #   parser.parse(File.read(ARGV[0], mode: 'rb'))
      #
      # For more information on SAX parsers, see Nokogiri::XML::SAX
      class Parser < Nokogiri::XML::SAX::Parser
        ###
        # Parse html stored in +data+ using +encoding+
        def parse_memory(data, encoding = "UTF-8")
          raise TypeError unless String === data
          return if data.empty?

          ctx = ParserContext.memory(data, encoding)
          yield ctx if block_given?
          ctx.parse_with(self)
        end

        ###
        # Parse given +io+
        def parse_io(io, encoding = "UTF-8")
          check_encoding(encoding)
          @encoding = encoding
          ctx = ParserContext.io(io, ENCODINGS[encoding])
          yield ctx if block_given?
          ctx.parse_with(self)
        end

        ###
        # Parse a file with +filename+
        def parse_file(filename, encoding = "UTF-8")
          raise ArgumentError unless filename
          raise Errno::ENOENT unless File.exist?(filename)
          raise Errno::EISDIR if File.directory?(filename)

          ctx = ParserContext.file(filename, encoding)
          yield ctx if block_given?
          ctx.parse_with(self)
        end
      end
    end
  end
end
