#!/bin/sh
### update-autoloads.sh --- update auto-autoloads.el as necessary

# Author: Jamie Zawinski, Ben Wing, Martin Buchholz, Steve Baur
# Maintainer: Steve Baur
# Keywords: internal

# This file is part of XEmacs.

# XEmacs is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.

# XEmacs is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with XEmacs; see the file COPYING.  If not, write to
# the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

### Commentary:

### Code:

set -eu

# This means we're running in a Sun workspace
test -d ../era-specific && cd ../editor

# get to the right directory
test ! -d ./lisp -a -d ../lisp && cd ..
if test ! -d ./lisp ; then
	echo $0: neither ./lisp/ nor ../lisp/ exist
	exit 1
fi

EMACS="./src/xemacs"
echo " (using $EMACS)"

export EMACS

REAL=`cd \`dirname $EMACS\` ; pwd | sed 's|^/tmp_mnt||'`/`basename $EMACS`

echo "Rebuilding autoloads/custom-loads in `pwd|sed 's|^/tmp_mnt||'`"
echo "          with $REAL..."

if [ "`uname -r | sed 's/\(.\).*/\1/'`" -gt 4 ]; then
  echon()
  {    
    /bin/echo $* '\c'
  }
else
  echon()
  {
    echo -n $*
  }
fi

# Compute patterns to ignore when searching for files
# These directories don't have autoloads and customizations, or are partially
#  broken.
ignore_dirs="cl egg eos ilisp its language locale mel mu sunpro term tooltalk"

# Prepare for autoloading directories with directory-specific instructions
make_special_commands=''
make_special () {
	dir="$1"; shift;
	ignore_dirs="$ignore_dirs $dir"
	make_special_commands="$make_special_commands \
		(cd \"lisp/$dir\" && ${MAKE:-make} EMACS=$REAL ${1+$*});"
}

# Only use Mule XEmacs to build Mule-specific autoloads & custom-loads.
echon "Checking for Mule support..."
lisp_prog='(princ (featurep (quote mule)))'
mule_p="`$EMACS -batch -no-site-file -eval \"$lisp_prog\"`"
if test "$mule_p" = nil ; then
	echo No
	ignore_dirs="$ignore_dirs mule leim"
else
	echo Yes
fi

## AUCTeX is a Package now
# if test "$mule_p" = nil ; then
# 	make_special auctex autoloads
# else
# 	make_special auctex autoloads MULE_EL=tex-jp.elc
# fi
#make_special cc-mode autoloads
make_special efs autoloads
#make_special eos autoloads # EOS doesn't have custom or autoloads
make_special hyperbole autoloads
# make_special ilisp autoloads
make_special oobr HYPB_ELC='' autoloads
make_special w3 autoloads

dirs=
for dir in lisp/*; do
	if test -d $dir \
		-a $dir != lisp/CVS \
		-a $dir != lisp/SCCS; then
		for ignore in $ignore_dirs; do
			if test $dir = lisp/$ignore; then
				continue 2
			fi
		done
		dirs="$dirs $dir"
	fi
done

# set -x
for dir in $dirs; do
	$EMACS -batch -q -l autoload -f batch-update-directory $dir
done

eval "$make_special_commands"
