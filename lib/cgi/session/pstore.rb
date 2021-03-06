#
# cgi/session/pstore.rb - persistent storage of marshalled session data
#
# Documentation: William Webber (william@williamwebber.com)
# 
# == Overview
#
# This file provides the CGI::Session::PStore class, which builds
# persistent of session data on top of the pstore library.  See
# cgi/session.rb for more details on session storage managers.

require 'cgi/session'
require 'pstore'

class CGI
  class Session
    def []=(key, val)
      unless @write_lock
	@write_lock = true
      end
      unless @data
	@data = @dbman.restore
      end
      #@data[key] = String(val)
      @data[key] = val
    end

    # PStore-based session storage class.
    #
    # This builds upon the top-level PStore class provided by the
    # library file pstore.rb.  Session data is marshalled and stored
    # in a file.  File locking and transaction services are provided.
    class PStore
      def check_id(id) #:nodoc:
	/[^0-9a-zA-Z]/ =~ id.to_s ? false : true
      end

      # Create a new CGI::Session::PStore instance
      #
      # This constructor is used internally by CGI::Session.  The
      # user does not generally need to call it directly.
      #
      # +session+ is the session for which this instance is being
      # created.  The session id must only contain alphanumeric
      # characters; automatically generated session ids observe
      # this requirement.
      # 
      # +option+ is a hash of options for the initialiser.  The
      # following options are recognised:
      #
      # tmpdir:: the directory to use for storing the PStore
      #          file.  Defaults to Dir::tmpdir (generally "/tmp"
      #          on Unix systems).
      # prefix:: the prefix to add to the session id when generating
      #          the filename for this session's PStore file.
      #          Defaults to the empty string.
      #
      # This session's PStore file will be created if it does
      # not exist, or opened if it does.
      def initialize session, option={}
	dir = option['tmpdir'] || ENV['TMP'] || '/tmp'
	prefix = option['prefix'] || ''
	id = session.session_id
	unless check_id(id)
	  raise ArgumentError, "session_id `%s' is invalid" % id
	end
	path = dir+"/"+prefix+id
	path.untaint
	unless File::exist? path
	  @hash = {}
	end
	@p = ::PStore.new(path)
      end

      # Restore session state from the session's PStore file.
      #
      # Returns the session state as a hash.
      def restore
	unless @hash
	  @p.transaction do
	    begin
	      @hash = @p['hash']
	    rescue
	      @hash = {}
	    end
	  end
	end
	@hash
      end

      # Save session state to the session's PStore file.
      def update 
	@p.transaction do
	    @p['hash'] = @hash
	end
      end

      # Update and close the session's PStore file.
      def close
	update
      end

      # Close and delete the session's PStore file.
      def delete
	path = @p.path
	File::unlink path
      end

    end
  end
end

if $0 == __FILE__
  # :enddoc:
  STDIN.reopen("/dev/null")
  cgi = CGI.new
  session = CGI::Session.new(cgi, 'database_manager' => CGI::Session::PStore)
  session['key'] = {'k' => 'v'}
  puts session['key'].class
  fail unless Hash === session['key']
  puts session['key'].inspect
  fail unless session['key'].inspect == '{"k"=>"v"}'
end
