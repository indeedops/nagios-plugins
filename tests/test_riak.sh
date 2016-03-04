#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2015-05-25 01:38:24 +0100 (Mon, 25 May 2015)
#
#  https://github.com/harisekhon/nagios-plugins
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help improve or steer this or other code I publish
#
#  https://www.linkedin.com/in/harisekhon
#

set -eu
[ -n "${DEBUG:-}" ] && set -x
srcdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$srcdir/..";

. ./tests/utils.sh

echo "
# ============================================================================ #
#                                   R I A K
# ============================================================================ #
"

export DOCKER_IMAGE="harisekhon/riak-dev"

export RIAK_TEST_VERSIONS="${RIAK_TEST_VERSIONS:-1.4.9 2.1.3}"

# RIAK_HOST no longer obtained via .travis.yml, some of these require local riak-admin tool so only makes more sense to run all tests locally
RIAK_HOST="${DOCKER_HOST:-${RIAK_HOST:-${HOST:-localhost}}}"
RIAK_HOST="${RIAK_HOST##*/}"
RIAK_HOST="${RIAK_HOST%%:*}"
export RIAK_HOST
echo "using docker address '$RIAK_HOST'"

export DOCKER_CONTAINER="nagios-plugins-riak"
export MNTDIR="/nagios-plugins-tmp"

if ! is_docker_available; then
    echo 'WARNING: Docker not found, skipping Riak checks!!!'
    exit 0
fi

docker_run_test(){
    docker exec -ti -u riak "$DOCKER_CONTAINER" $MNTDIR/$@
}

startupwait=20
[ -n "${TRAVIS:-}" ] && let startupwait+=20

test_riak(){
    local version="$1"
    echo "Setting up test Riak $version container"
    if ! docker ps | tee /dev/stderr | grep -q "[[:space:]]$DOCKER_CONTAINER$"; then
        docker rm -f "$DOCKER_CONTAINER" &>/dev/null || :
        echo "Starting Docker Riak test container"
        docker run -d --name "$DOCKER_CONTAINER" -v "$srcdir/..":"$MNTDIR" -p 8098:8098 "$DOCKER_IMAGE":"$version"
        echo "waiting $startupwait seconds for Riak to start up and settle"
        sleep $startupwait
        # Riak 2.x
        #echo "creating myBucket with n_val setting of 1 (to avoid warnings in riak-admin)"
        #docker exec -ti -u riak "$DOCKER_CONTAINER" riak-admin bucket-type create myBucket '{"props":{"n_val":1}}' || :
        #docker exec -ti -u riak "$DOCKER_CONTAINER" riak-admin bucket-type activate myBucket
        #docker exec -ti -u riak "$DOCKER_CONTAINER" riak-admin bucket-type update myBucket '{"props":{"n_val":1}}'
        echo "creating test Riak document"
        # don't use new bucket types yet
        #curl -XPUT localhost:8098/types/myType/buckets/myBucket/keys/myKey -d 'hari'
        curl -XPUT $RIAK_HOST:8098/buckets/myBucket/keys/myKey -d 'hari'
        echo "done"
    else
        echo "Docker Riak test container already running"
    fi

    hr
    # riak-admin doesn't work in Dockerized environments, fails trying to stat '/proc/sys/net/core/wmem_default'
    #docker_run_test check_riak_diag.pl --ignore-warnings -v
    # must attempt to check this locally if available - but may get "CRITICAL: 'riak-admin diag' returned 1 -  Node is not running!"
    if which riak-admin; then
        $perl -T $I_lib check_riak_diag.pl --ignore-warnings -v || :
    fi
    hr
    $perl -T $I_lib check_riak_key.pl -b myBucket -k myKey -e hari -v
    hr
    docker_run_test check_riak_member_status.pl -v
    hr
    docker_run_test check_riak_ringready.pl -v
    hr
    $perl -T $I_lib check_riak_stats.pl --all -v
    hr
    $perl -T $I_lib check_riak_stats.pl -s ring_num_partitions -c 64:64 -v
    hr
    if [ "${version:0:1}" != 1 ]; then
        $perl -T $I_lib check_riak_stats.pl -s disk.0.size -c 1024: -v
    fi
    hr
    $perl -T $I_lib check_riak_write.pl -v
    hr
    docker_run_test check_riak_write_local.pl -v
    hr
    $perl -T $I_lib check_riak_version.pl -v

    echo
    echo -n "Deleting container "
    docker rm -f "$DOCKER_CONTAINER"
    sleep 1
    echo
    hr
    echo; echo
}

for version in $RIAK_TEST_VERSIONS; do
    test_riak $version
done

# ============================================================================ #
#                                     E N D
# ============================================================================ #
exit 0
# ============================================================================ #
# Old Travis checks not used any more

echo "creating myBucket with n_val setting of 1 (to avoid warnings in riak-admin)"
$sudo riak-admin bucket-type create myBucket '{"props":{"n_val":1}}' || :
$sudo riak-admin bucket-type activate myBucket
$sudo riak-admin bucket-type update myBucket '{"props":{"n_val":1}}'
echo "creating test Riak document"
# don't use new bucket types yet
#curl -XPUT localhost:8098/types/myType/buckets/myBucket/keys/myKey -d 'hari'
curl -XPUT $RIAK_HOST:8098/buckets/myBucket/keys/myKey -d 'hari'
echo "done"
hr
# needs sudo - uses wrong version of perl if not explicit path with sudo
$sudo $perl -T $I_lib ./check_riak_diag.pl --ignore-warnings -v
hr
$perl -T $I_lib ./check_riak_key.pl -b myBucket -k myKey -e hari -v
hr
$sudo $perl -T $I_lib ./check_riak_member_status.pl -v
hr
# needs sudo - riak must be started as root in Travis
$sudo $perl -T $I_lib ./check_riak_ringready.pl -v
hr
$perl -T $I_lib ./check_riak_stats.pl --all -v
hr
$perl -T $I_lib ./check_riak_stats.pl -s ring_num_partitions -c 64:64 -v
hr
$perl -T $I_lib ./check_riak_stats.pl -s disk.0.size -c 1024: -v
hr
$perl -T $I_lib ./check_riak_write.pl -v
hr
# needs sudo - riak must be started as root in Travis
$sudo $perl -T $I_lib ./check_riak_write_local.pl -v
hr
$perl -T $I_lib ./check_riak_version.pl

echo; echo
