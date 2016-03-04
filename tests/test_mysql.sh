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
#                                   M y S Q L
# ============================================================================ #
"

MYSQL_HOST="${MYSQL_HOST:-${DOCKER_HOST:-${HOST:-localhost}}}"
MYSQL_HOST="${MYSQL_HOST##*/}"
MYSQL_HOST="${MYSQL_HOST%%:*}"
# using 'localhost' causes mysql driver to try to shortcut to using local socket
# which doesn't work in Dockerized environment
[ "$MYSQL_HOST" = "localhost" ] && MYSQL_HOST="127.0.0.1"
export MYSQL_HOST
echo "using docker address '$MYSQL_HOST'"
export MYSQL_DATABASE="${MYSQL_DATABASE:-mysql}"
export MYSQL_USER="root"
export MYSQL_PASSWORD="test123"

export DOCKER_CONTAINER="nagios-plugins-mysql"

if ! is_docker_available; then
    echo 'WARNING: Docker not found, skipping MySQL checks!!!'
    exit 0
fi

startupwait=10
[ -n "${TRAVIS:-}" ] && let startupwait+=20

echo "Setting up test MySQL container"
if ! docker ps | tee /dev/stderr | grep -q "[[:space:]]$DOCKER_CONTAINER$"; then
    docker rm -f "$DOCKER_CONTAINER" &>/dev/null || :
    echo "Starting Docker MySQL test container"
    docker run -d --name "$DOCKER_CONTAINER" -p 3306:3306 -e MYSQL_ROOT_PASSWORD="$MYSQL_PASSWORD" mysql
    echo "waiting $startupwait seconds for MySQL to start up"
    sleep $startupwait
else
    echo "Docker MySQL test container already running"
fi

hr
docker cp "$DOCKER_CONTAINER":/etc/mysql/my.cnf /tmp
$perl -T $I_lib ./check_mysql_config.pl -c /tmp/my.cnf --warn-on-missing -v
rm -f /tmp/my.cnf
hr
$perl -T $I_lib ./check_mysql_query.pl -q "SHOW TABLES IN information_schema" -o CHARACTER_SETS -v
hr
#$perl -T $I_lib ./check_mysql_query.pl -d information_schema -q "SELECT * FROM user_privileges LIMIT 1"  -o "'root'@'localhost'" -v
hr
$perl -T $I_lib ./check_mysql_query.pl -d information_schema -q "SELECT * FROM user_privileges LIMIT 1"  -o "'root'@'%'" -v
# TODO: add socket test - must mount on a compiled system, ie replace the docker image with a custom test one
unset MYSQL_HOST
#$perl -T $I_lib ./check_mysql_query.pl -d information_schema -q "SELECT * FROM user_privileges LIMIT 1"  -o "'root'@'localhost'" -v
hr
echo
echo -n "Deleting container "
docker rm -f "$DOCKER_CONTAINER"
echo; echo
