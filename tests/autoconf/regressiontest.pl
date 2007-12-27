#!/usr/bin/perl -w
#
# Try the new and old versions of configure with various command lines to see
# if they produce identical output.
#
# Invocation: $0 /path/to/old/configure  /path/to/new/configure
#
# Since not all tests use --srcdir, invoke this script from a directory where
# configure can automatically find its input files (Makefile.in.in, etc).  If
# interrupted, it probably will leave its temporary directories behind.  In
# that case, it will error on next invocation, but remove the directories.
# The next invocation will then succeed.
#

use strict;
use File::Basename;

# Files generated by configure.  There should be no functional difference
# between these files generated by 2.13 and those generated by 2.59.
my @output_files =
  (
   "Installation",
   "Makefile.in",
   "./Makefile",
   "./GNUmakefile",
   "dynodump/Makefile.in",
   "dynodump/Makefile",
   "lib-src/Makefile.in",
   "lib-src/Makefile",
   "lib-src/GNUmakefile",
#   "lib-src/config.values", # This is specific to the version of autoconf.
   "lib-src/ellcc.h",
   "lwlib/Makefile.in",
   "lwlib/Makefile",
   "lwlib/GNUmakefile",
   "lwlib/config.h",
   "modules/ldap/Makefile.in",
   "modules/ldap/Makefile",
   "modules/ldap/GNUmakefile",
   "modules/postgresql/Makefile.in",
   "modules/postgresql/Makefile",
   "modules/postgresql/GNUmakefile",
   "netinstall/Makefile.in",
   "netinstall/Makefile",
   "src/Makefile.in",
   "src/Makefile",
   "src/GNUmakefile",
   "src/config.h",
   "src/paths.h",
   "src/xemacs.def.in",
   "src/xemacs.def",
  );

# The list of complete command line arguments to test against.  Since the
# command line arguments have changed between 2.13 and 2.59 this hash maps from
# old => new.  If new is 'undef' then the old arguments are used instead.
my %config_args =
  (
   " " => undef,
   "--prefix=/tmp/foo" => undef,
   "--with-gnome" => undef,
   "--with-mule" => "--enable-mule",
# My build flags for MacOS X.  Needs /sw (fink) to be present.
#   "--prefix=/Users/malcolmp/prefix --site-prefixes=/sw --with-sound=none --with-database=no --without-ldap --without-postgresql" =>
#     "--prefix=/Users/malcolmp/prefix --with-site-prefixes=/sw --disable-sound --disable-database --without-ldap --without-postgresql",
# My build flags for Linux (powerpc64)
   "--prefix=/usr/local/gcc3-world --package-path=/usr/local/lib/xemacs" =>
     "--prefix=/usr/local/gcc3-world --with-package-path=/usr/local/lib/xemacs",
   "--use_union_type" => "--enable-union-type",
   "--use_kkcc" => "--enable-kkcc",
   "--xemacs-compiler=g++" => "--with-xemacs-compiler=g++",
   "--lispdir=/tmp/foo" => "--with-lispdir=/tmp/foo",
   "--moduledir=/tmp/foo" => "--with-moduledir=/tmp/foo",
   "--etcdir=/tmp/foo" => "--with-etcdir=/tmp/foo",
   "--infopath=/tmp/foo" => "--with-infopath=/tmp/foo",
   "--archlibdir=/tmp/foo" => "--with-archlibdir=/tmp/foo",
   "--docdir=/tmp/foo" => "--with-docdir=/tmp/foo",
   "--package-prefix=/tmp/foo" => "--with-package-prefix=/tmp/foo",
   "--package-path=/tmp/foo" => "--with-package-path=/tmp/foo",
   "--datadir=/tmp/foo" => undef,
   "--mandir=/tmp/foo" => undef,
   "--infodir=/tmp/foo" => undef,
   "--libdir=/tmp/foo" => undef,
   "--exec-prefix=/tmp/foo" => undef,
   "--with-athena=3d" => undef,
   "--with-mule --with-xft=emacs --debug --error-checking=all --with-xim=xlib --with-widgets=athena --with-athena=3d --with-dialogs=athena --memory-usage-stats --use-number-lib=gmp --site-prefixes=/opt/local:/sw --with-ldap=no --use-union-type" => "--enable-mule --with-xft=emacs --enable-debug --enable-error-checking=all --with-xim=xlib --enable-widgets=athena --with-athena=3d --enable-dialogs=athena --enable-memory-usage-stats --enable-bignum=gmp --with-site-prefixes=/opt/local:/sw --with-ldap=no --enable-union-type"
  );

die "Usage: $0 /path/to/configure-2.13 /path/to/configure-2.59\n" if scalar(@ARGV) != 2;

my $old_configure = $ARGV[0];
my $new_configure = $ARGV[1];
my $old_dir = dirname($old_configure);
my $new_dir = dirname($new_configure);

foreach my $old_arg (keys %config_args) {
  mkdir "/tmp/old" or die "$0: Cannot create /tmp/old: $!\n";
  mkdir "/tmp/new" or die "$0: Cannot create /tmp/new: $!\n";

  my $new_arg = $config_args{$old_arg};
  $new_arg = $old_arg if ! defined($new_arg);

  print "--------------------------------------------------\n";
  print "$old_configure $old_arg\n";
  print "$new_configure $new_arg\n";

  chdir "/tmp/old" or die "$0: Cannot cd to /tmp/old: $!\n";
  system ("$old_configure $old_arg >/tmp/old-output.txt\n") == 0 or
    die "$0: $old_configure $old_arg failed\n";

  chdir "/tmp/new" or die "$0: Cannot cd to /tmp/new: $!\n";
  system ("$new_configure $new_arg >/tmp/new-output.txt\n") == 0 or
    die "$0: $new_configure $new_arg failed\n";

  foreach my $file (@output_files) {
    if (-r "/tmp/old/$file" && -r "/tmp/new/$file") {
# Strip out parts that always differ: Paths and the 'Generated by configure'
# lines.
      system("for i in /tmp/old/$file /tmp/new/$file ; do sed -e '/HAVE_DECL_SYS_SIGLIST/d' -e '\\!$old_configure!d' -e '\\!$new_configure!d' -e '/EMACS_CONFIG_OPTIONS/d' -e '/Generated.*configure/d' -e '\\!$old_dir!s///' -e '\\!$new_dir!s///' -e '\\!/tmp/new!s///' -e '\\!/tmp/old!s///' <\$i >\$i.processed ; done");
# Compare the processed versions.  These should be the same.
      system "diff -U 0 -L old-$file -L new-$file /tmp/old/$file.processed /tmp/new/$file.processed";
    }
  }
  chdir "/";
  system("rm -rf /tmp/old /tmp/new");
}

END {
  chdir "/";
  system("rm -rf /tmp/old /tmp/new");
}
