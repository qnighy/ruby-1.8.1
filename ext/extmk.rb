#! /usr/local/bin/ruby
# -*- ruby -*-

$force_static = nil
$install = nil
$destdir = nil
$clean = nil
$nodynamic = nil
$extinit = nil
$extobjs = nil
$ignore = nil
$message = nil

$progname = $0
alias $PROGRAM_NAME $0
alias $0 $progname

$extlist = []

$:.replace ["."]
require 'rbconfig'

srcdir = Config::CONFIG["srcdir"]

$:.replace [srcdir, srcdir+"/lib", "."]

require 'mkmf'
require 'getopts'

$topdir = File.expand_path(".")
$top_srcdir = srcdir
$hdrdir = $top_srcdir

def sysquote(x)
  @quote ||= /human|os2|macos/ =~ (CROSS_COMPILING || RUBY_PLATFORM)
  @quote ? x.quote : x
end

def extmake(target)
  print "#{$message} #{target}\n"
  $stdout.flush
  if $force_static or $static_ext[target]
    $static = target
  else
    $static = false
  end

  unless $ignore
    return true if $nodynamic and not $static
  end

  init_mkmf

  begin
    dir = Dir.pwd
    FileUtils.mkpath target unless File.directory?(target)
    Dir.chdir target
    $target = target
    $mdir = target
    $srcdir = File.join($top_srcdir, "ext", $mdir)
    $preload = nil
    makefile = "./Makefile"
    unless $ignore
      if $static ||
	 !(t = modified?(makefile, MTIMES)) ||
	 %W<#{$srcdir}/makefile.rb #{$srcdir}/extconf.rb
	    #{$srcdir}/depend #{$srcdir}/MANIFEST>.any? {|f| modified?(f, [t])}
      then
	$defs = []
	Logging::logfile 'mkmf.log'
	Config::CONFIG["srcdir"] = $srcdir
	rm_f makefile
	begin
	  if File.exist?($0 = "#{$srcdir}/makefile.rb")
	    load $0
	  elsif File.exist?($0 = "#{$srcdir}/extconf.rb")
	    load $0
	  else
	    create_makefile(target)
	  end
	  File.exist?(makefile)
	rescue SystemExit
	  # ignore
	ensure
	  rm_f "conftest*"
	  $0 = $PROGRAM_NAME
	  Config::CONFIG["srcdir"] = $top_srcdir
	end
      else
	true
      end
    else
      File.exist?(makefile)
    end or open(makefile, "w") do |f|
      f.print dummy_makefile($srcdir)
      return true
    end
    args = sysquote($mflags)
    if $static
      args += ["static"]
      $extlist.push [$static, $target, File.basename($target), $preload]
    end
    unless system($make, *args)
      $ignore or $continue or return false
    end
    if $static
      $extflags ||= ""
      $extlibs ||= []
      $extpath ||= []
      $extflags += " " + $DLDFLAGS unless $DLDFLAGS.empty?
      $extflags += " " + $LDFLAGS unless $LDFLAGS.empty?
      $extlibs |= $libs.split | $LOCAL_LIBS.split
      $extpath |= $LIBPATH
    end
  ensure
    Dir.chdir dir
  end
  true
end

def parse_args()
  getopts('n', 'extstatic:', 'dest-dir:',
	  'make:', 'make-flags:', 'mflags:')

  $dryrun = $OPT['n']
  $force_static = $OPT['extstatic'] == 'static'
  $destdir = $OPT['dest-dir'] || ''
  $make = $OPT['make'] || $make || 'make'
  mflags = ($OPT['make-flags'] || '').strip
  mflags = ($OPT['mflags'] || '').strip if mflags.empty?

  $mflags = Shellwords.shellwords(mflags)
  if arg = $mflags.first
    arg.insert(0, '-') if /\A[^-][^=]*\Z/ =~ arg
  end

  $make, *rest = Shellwords.shellwords($make)
  $mflags.unshift(*rest) unless rest.empty?

  def $mflags.set?(flag)
    grep(/\A-(?!-).*#{'%c' % flag}/i) { return true }
    false
  end

  if $mflags.set?(?n)
    $dryrun = true
  else
    $mflags.unshift '-n' if $dryrun
  end

  $continue = $mflags.set?(?k)
  $mflags |= ["DESTDIR=#{$destdir}"]
end

parse_args()

unless $message
  if $message = ARGV.shift and /^[a-z]+$/ =~ $message
    $mflags.push($message)
    $message = $message.sub(/^(?:dist|real)(?=(?:clean)?$)/, '\1')
    case $message
    when "clean"
      $ignore ||= true
    when "install"
      $ignore ||= true
      $mflags.unshift("INSTALL_PROG=install -c -p -m 0755",
		      "INSTALL_DATA=install -c -p -m 0644",
		      "MAKEDIRS=mkdir -p") if $dryrun
    end
    $message.sub!(/e?$/, "ing")
  else
    $message = "compiling"
  end
end

EXEEXT = CONFIG['EXEEXT']
if CROSS_COMPILING
  $ruby = CONFIG['MINIRUBY']
elsif $nmake
  $ruby = '$(topdir:/=\\)\\miniruby' + EXEEXT
else
  $ruby = '$(topdir)/miniruby' + EXEEXT
end
$ruby << " -I$(topdir) -I$(hdrdir)/lib"
$config_h = '$(topdir)/config.h'

MTIMES = [__FILE__, srcdir+'/lib/mkmf.rb'].collect {|f| File.mtime(f)}

# get static-link modules
$static_ext = {}
for dir in ["ext", File::join($top_srcdir, "ext")]
  setup = File::join(dir, CONFIG['setup'])
  if File.file? setup
    f = open(setup) 
    while line = f.gets()
      line.chomp!
      line.sub!(/#.*$/, '')
      next if /^\s*$/ =~ line
      target, opt = line.split(nil, 3)
      if target == 'option'
	case opt
	when 'nodynamic'
	  $nodynamic = true
	end
	next
      end
      target = target.downcase if /mswin32|bccwin32/ =~ RUBY_PLATFORM
      $static_ext[target] = true
    end
    MTIMES << f.mtime
    $setup = setup
    f.close
    break
  end
end

FileUtils::makedirs('ext')
Dir::chdir('ext')

ext_prefix = "#{$top_srcdir}/ext"
Dir.glob("#{ext_prefix}/*/**/MANIFEST") do |d|
  d = File.dirname(d)
  d.slice!(0, ext_prefix.length + 1)
  extmake(d) or exit(1)
end

if $ignore
  Dir.chdir ".."
  exit
end

if $extlist.size > 0
  $extinit ||= ""
  $extobjs ||= ""
  list = $extlist.dup
  until list.empty?
    s,t,i,r = list.shift
    if r and list.any? {|l| r.include?(l[1])}
      list << [s,t,i]
      next
    end
    f = format("%s/%s.%s", s, i, $LIBEXT)
    if File.exist?(f)
      $extinit += "\tinit(Init_#{i}, \"#{t}.so\");\n"
      $extobjs += "ext/#{f} "
    end
  end

  src = <<SRC
extern char *ruby_sourcefile, *rb_source_filename();
#define init(func, name) (ruby_sourcefile = src = rb_source_filename(name), func(), rb_provide(src))
void Init_ext() {\n\tchar* src;\n#$extinit}
SRC
  if !modified?("extinit.c", MTIMES) || IO.read("extinit.c") != src
    open("extinit.c", "w") {|f| f.print src}
  end

  $extobjs = "ext/extinit.#{$OBJEXT} " + $extobjs
  if RUBY_PLATFORM =~ /m68k-human|beos/
    $extflags.delete("-L/usr/local/lib")
  end
  $extpath.delete("$(topdir)")
  $extflags = libpathflag($extpath) << " " << $extflags.strip
  conf = [
    ['SETUP', $setup], [$enable_shared ? 'DLDOBJS' : 'EXTOBJS', $extobjs],
    ['EXTLIBS', $extlibs.join(' ')], ['EXTLDFLAGS', $extflags]
  ].map {|n, v|
    "#{n}=#{v}" if v and !(v = v.strip).empty?
  }.compact
  puts conf
  $stdout.flush
  $mflags.concat(conf)
end
rubies = []
%w[RUBY RUBYW].each {|r|
  config_string(r+"_INSTALL_NAME") {|r| rubies << r+EXEEXT}
}

Dir.chdir ".."
if $extlist.size > 0
  rm_f(Config::CONFIG["LIBRUBY_SO"])
end
puts "making #{rubies.join(', ')}"
$stdout.flush
$mflags.concat(rubies)

system($make, *sysquote($mflags)) or exit($?.exitstatus)

#Local variables:
# mode: ruby
#end:
