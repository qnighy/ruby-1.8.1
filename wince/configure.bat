@echo off
::: Don't set environment variable in batch file other than autoexec.bat
::: to avoid "Out of environment space" problem on Windows 95/98.
::: set TMPMAKE=~tmp~.mak

echo> ~tmp~.mak ####
echo>> ~tmp~.mak conf = %0
echo>> ~tmp~.mak $(conf:\=/): nul
echo>> ~tmp~.mak 	@del ~tmp~.mak
echo>> ~tmp~.mak 	@-$(MAKE) -l$(MAKEFLAGS) -f $(@D)/setup.mak \
:loop
if "%1" == "" goto :end
if "%1" == "--srcdir" goto :srcdir
if "%1" == "srcdir" goto :srcdir
if "%1" == "--target" goto :target
if "%1" == "target" goto :target
if "%1" == "--program-suffix" goto :suffix
if "%1" == "--program-name" goto :progname
if "%1" == "CC" goto :define
if "%1" == "EMBEDDED_TOOLS_DIR" goto :define
if "%1" == "CE_TOOLS_DIR" goto :define
if "%1" == "EMBEDDED_TOOLS4_DIR" goto :define
if "%1" == "CE_TOOLS4_DIR" goto :define
  echo>> ~tmp~.mak 	"%1" \
  shift
goto :loop
:srcdir
  echo>> ~tmp~.mak 	"srcdir=%2" \
  shift
  shift
goto :loop
:suffix
  echo>> ~tmp~.mak 	"RUBY_SUFFIX=%2" \
  shift
  shift
goto :loop
:installname
  echo>> ~tmp~.mak 	"RUBY_INSTALL_NAME=%2" \
  shift
  shift
goto :loop
:soname
  echo>> ~tmp~.mak 	"RUBY_SO_NAME=%2" \
  shift
  shift
goto :loop
:define
  echo>> ~tmp~.mak 	"%1=%2" \
  shift
  shift
goto :loop
:target
  echo>> ~tmp~.mak 	"%2" \
  shift
  shift
goto :loop
:end
echo>> ~tmp~.mak 	WIN32DIR=$(@D)
nmake -alf ~tmp~.mak
