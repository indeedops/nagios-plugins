#!/usr/bin/env bash
#
#  Author: Hari Sekhon
#  Date: 2007-11-14 10:21:36 +0000 (Wed, 14 Nov 2007)
#
#  http://github.com/harisekhon/nagios-plugins
#
#  License: see accompanying LICENSE file
#

export PATH=$PATH:/usr/lib64/nagios/plugins:/usr/lib/nagios/plugins:/usr/nagios/libexec:/usr/local/nagios/libexec

if ! which check_nt &>/dev/null; then
    echo "CRITICAL: check_nt was not found in path"
    exit $CRITICAL
fi
check_nt=`which check_nt`


if [ ! -f "$check_nt" ]; then
    echo "CRITICAL: $check_nt cannot be found"
    exit $CRITICAL
fi

if [ ! -x "$check_nt" ]; then
    echo "CRITICAL: $check_nt is not set executable!"
    exit $CRITICAL
fi

