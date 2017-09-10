#
#   tkmacpkg.rb : methods for Tcl/Tk packages for Macintosh
#                     2000/11/22 by Hidetoshi Nagai <nagai@ai.kyutech.ac.jp>
#
#     ATTENTION !!
#         This is NOT TESTED. Because I have no test-environment.
#
#
require 'tk'

module TkMacResource
  extend Tk
  extend TkMacResource

  TkCommandNames = ['resource'.freeze].freeze

  tk_call('package', 'require', 'resource')

  def close(rsrcRef)
    tk_call('resource', 'close', rsrcRef)
  end

  def delete(rsrcType, opts=nil)
    tk_call('resource', 'delete', *(hash_kv(opts) + rsrcType))
  end

  def files(rsrcRef=nil)
    if rsrcRef
      tk_call('resource', 'files', rsrcRef)
    else
      tk_split_simplelist(tk_call('resource', 'files'))
    end
  end

  def list(rsrcType, rsrcRef=nil)
    tk_split_simplelist(tk_call('resource', 'list', rsrcType, rsrcRef))
  end

  def open(fname, access=nil)
    tk_call('resource', 'open', fname, access)
  end

  def read(rsrcType, rsrcID, rsrcRef=nil)
    tk_call('resource', 'read', rsrcType, rsrcID, rsrcRef)
  end

  def types(rsrcRef=nil)
    tk_split_simplelist(tk_call('resource', 'types', rsrcRef))
  end

  def write(rsrcType, data, opts=nil)
    tk_call('resource', 'write', *(hash_kv(opts) + rsrcType + data))
  end

  module_function :close, :delete, :files, :list, :open, :read, :types, :write
end
