#!/bin/bash
#
# This is a special test script that will actually install KA Lite
# on the host system and test that stuff works!
# This script is intended for Travis CI mainly.

set -e

# Goto location of this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

# Traceback utility for Bash
. "$DIR/traceback.sh"

test_version=1.2.3
echo "Starting tests"


# A user account which is used for some tests and deleted after.
TEST_USER="kolibri_test"

if [ "$1" = "" ]
then
    target_kolibri=true
    target_upgrade=true
    target_manual_init=true
else
    target_kolibri=false
    target_upgrade=false
    target_manual_init=false
    [ "$1" = "kolibri" ] && target_kolibri=true
    [ "$1" = "upgrade" ] && target_upgrade=true
    [ "$1" = "manual_init" ] && target_manual_init=true
fi


test_fail()
{
    error=$1
    echo ""
    echo "!!! exiting due to test failure"
    echo "!!! $error"
    exit 1
}

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

get_conf_value()
{
  pkg=$1
  conf=$2
  echo `debconf-show $pkg | grep $2 | sed 's/.*:\s//'`
}

./test_build.sh $test_version 1

cd test

# Disable asking questions
export DEBIAN_FRONTEND=noninteractive


echo ""
echo "=============================="
echo " Testing kolibri"
echo "=============================="
echo ""


if $target_kolibri
then

    # Remove all previous values from debconf
    echo "Purging any prior values in debconf"
    echo PURGE | sudo debconf-communicate kolibri
    echo PURGE | sudo debconf-communicate kolibri-server

    # Use the test user
    echo "kolibri kolibri/user select $TEST_USER" | sudo debconf-set-selections

    # Simple install of kolibri with no prior debconf set...
    test_command_with_pipe "sudo -E dpkg -i --debug=2 kolibri-server_${test_version}_all.deb" "tail"
    kolibri status
    sudo -E apt-get purge -y kolibri-server

    echo "Done with normal kolibri-server tests"

fi

echo ""
echo "======================================="
echo " Testing kolibri w/o update.rcd"
echo "======================================="
echo ""


if $target_manual_init
then

    # Remove all previous values from debconf
    echo "Purging any prior values in debconf"
    echo PURGE | sudo debconf-communicate kolibri
    echo PURGE | sudo debconf-communicate kolibri-server

    echo "kolibri kolibri/init select false" | sudo debconf-set-selections

    test_command_with_pipe "sudo -E dpkg -i --debug=2 kolibri-server_${test_version}_all.deb" "tail"
    kolibri status
    # Test that the script restarts
    sudo service kolibri start
    sudo service kolibri stop
    sudo -E apt-get purge -y kolibri

    echo "Done with kolibri tests"
fi

echo ""
echo "=============================="
echo " Testing upgrades"
echo "=============================="
echo ""


# Test upgrades
if $target_upgrade
then
    # Install previous test
    test_command_with_pipe "sudo -E dpkg -i --debug=2 kolibri-server_${test_version}_all.deb" "tail"

    # Then install a version with .1 appended
    cd $DIR
    ./test_build.sh ${test_version}.1 1
    cd test

    test_command_with_pipe "sudo -E dpkg -i --debug=2 kolibri-server_${test_version}.1_all.deb" "tail"

    sudo -E apt-get purge -y kolibri

    echo "Done with upgrade tests"


fi

echo ""
echo "=============================="
echo " Cleaning up"
echo "=============================="
echo ""

sudo deluser --remove-home "$TEST_USER" || echo "$TEST_USER already deleted or not created"
