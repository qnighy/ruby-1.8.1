# $RoughId: extconf.rb,v 1.3 2001/08/14 19:54:51 knu Exp $
# $Id$

require "mkmf"

$CFLAGS << " -DHAVE_CONFIG_H -I#{File.dirname(__FILE__)}/.."

$objs = [ "md5init.#{$OBJEXT}" ]

dir_config("openssl")

if !with_config("bundled-md5") &&
    have_library("crypto") && have_header("openssl/md5.h")
  $objs << "md5ossl.#{$OBJEXT}"

  $libs << " -lcrypto"
else
  $objs << "md5.#{$OBJEXT}"
end

have_header("sys/cdefs.h")

have_header("inttypes.h")

have_header("unistd.h")

create_makefile("digest/md5")
