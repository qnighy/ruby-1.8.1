require 'rexml/parseexception'
require 'rexml/parsers/baseparser'
require 'rexml/xmltokens'

module REXML
	module Parsers
		# = Using the Pull Parser
		# <em>This API is experimental, and subject to change.</em>
		#  parser = PullParser.new( "<a>text<b att='val'/>txet</a>" )
		#  while parser.has_next?
		#    res = parser.next
		#    puts res[1]['att'] if res.start_tag? and res[0] == 'b'
		#  end
		# See the PullEvent class for information on the content of the results.
		# The data is identical to the arguments passed for the various events to
		# the StreamListener API.
		#
		# Notice that:
		#  parser = PullParser.new( "<a>BAD DOCUMENT" )
		#  while parser.has_next?
		#    res = parser.next
		#    raise res[1] if res.error?
		#  end
		#
		# Nat Price gave me some good ideas for the API.
		class PullParser < BaseParser
			include XMLTokens

			def initialize stream
				super
				@entities = {}
			end

			def each
				while has_next?
					yield self.pull
				end
			end

			def peek depth=0
				PullEvent.new(super)
			end

			def pull
				event = super
				case event[0]
				when :entitydecl
					@entities[ event[1] ] = 
						event[2] unless event[2] =~ /PUBLIC|SYSTEM/
				when :text
					unnormalized = unnormalize( event[1], @entities )
					event << unnormalized
				end
				PullEvent.new( event )
			end
		end

		# A parsing event.  The contents of the event are accessed as an +Array?,
		# and the type is given either by the ...? methods, or by accessing the
		# +type+ accessor.  The contents of this object vary from event to event,
		# but are identical to the arguments passed to +StreamListener+s for each
		# event.
		class PullEvent
			# The type of this event.  Will be one of :tag_start, :tag_end, :text,
			# :processing_instruction, :comment, :doctype, :attlistdecl, :entitydecl,
			# :notationdecl, :entity, :cdata, :xmldecl, or :error.
			def initialize(arg)
				@contents = arg
			end
			def []( index )
				@contents[index+1]
			end
			def event_type
				@contents[0]
			end
			# Content: [ String tag_name, Hash attributes ]
			def start_element?
				@contents[0] == :start_element
			end
			# Content: [ String tag_name ]
			def end_element?
				@contents[0] == :end_element
			end
			# Content: [ String raw_text, String unnormalized_text ]
			def text?
				@contents[0] == :text
			end
			# Content: [ String text ]
			def instruction?
				@contents[0] == :processing_instruction
			end
			# Content: [ String text ]
			def comment?
				@contents[0] == :comment
			end
			# Content: [ String name, String pub_sys, String long_name, String uri ]
			def doctype?
				@contents[0] == :start_doctype
			end
			# Content: [ String text ]
			def attlistdecl?
				@contents[0] == :attlistdecl
			end
			# Content: [ String text ]
			def elementdecl?
				@contents[0] == :elementdecl
			end
			# Due to the wonders of DTDs, an entity declaration can be just about
			# anything.  There's no way to normalize it; you'll have to interpret the
			# content yourself.  However, the following is true:
			#
			# * If the entity declaration is an internal entity:
			#   [ String name, String value ]
			# Content: [ String text ]
			def entitydecl?
				@contents[0] == :entitydecl
			end
			# Content: [ String text ]
			def notationdecl?
				@contents[0] == :notationdecl
			end
			# Content: [ String text ]
			def entity?
				@contents[0] == :entity
			end
			# Content: [ String text ]
			def cdata?
				@contents[0] == :cdata
			end
			# Content: [ String version, String encoding, String standalone ]
			def xmldecl?
				@contents[0] == :xmldecl
			end
			def error?
				@contents[0] == :error
			end

			def inspect
				@contents[0].to_s + ": " + @contents[1..-1].inspect
			end
		end
	end
end
