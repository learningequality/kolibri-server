#!/bin/bash

set -e

# When piping, you loose the status code and non-0 exit commands are lost
# so we need this...
test_command_with_pipe()
{
    cmd=$1
    pipe=$2
    $1 | $2
    if [ ! ${PIPESTATUS[0]} -eq 0 ]
    then
        exit 123
    fi
}

# Builds the test package

test_version="$1"
build_dir="build/"

if [ "$1" = "" ]
then
	echo "usage: ./script VERSION"
	exit 1
fi

keep_old_build=`echo "$2" | xargs`

# Goto location of this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

if [ -d "$build_dir" ] && [ "$keep_old_build" = "" ]
then
     echo "Already built, skipping"
     exit 0
fi

# Remove old test if exists
rm -rf "$build_dir"

# Create a new test package
./make_test_pkg.sh $test_version "$build_dir"
cd "$build_dir"

# Build the test package
test_command_with_pipe "debuild --no-lintian -us -uc" "tail"

# Go to the build dir
cd $DIR

if which dpkg-scanpackages
then
	# Turn it into a repository
	cd test
	echo "Creating an apt archive in $DIR/test"
	dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
fi

cd $DIR
