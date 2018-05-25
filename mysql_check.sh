#!/bin/bash
#
# check_mysql
#
# A mind blowing MySQL check script for Nagios
#
# Jeroen Ketelaar - ketelaar@redkiwi.nl
# Wiard van Rij - vanrij@redkiwi.nl

E_SUCCESS="0"
E_WARNING="1"
E_CRITICAL="2"
E_UNKNOWN="3"

WARNING_LIMIT=75
CRITICAL_LIMIT=85

MYSQL_STATUS=$(pidof mysqld | wc -w)

if [ "$MYSQL_STATUS" -eq 0 ]; then
    echo "CRITICAL: MySQL is not running"
    exit ${E_CRITICAL}
fi

/usr/bin/pgrep mysql > /dev/null

if [ "$?" -ne 0 ]; then
    echo "CRITICAL: MySQL is not running correctly"
    exit ${E_CRITICAL}
else

    MYSQL_MAX_CONN=`mysql --defaults-file=/var/lib/nagios/.my.cnf -e "show variables like 'max_connections'" | awk '{ print $2 }' | sed -n '2p'`

    if [ "$MYSQL_MAX_CONN" -gt 0 ]; then

        MYSQL_CURRENT_CONN=`mysql --defaults-file=/var/lib/nagios/.my.cnf -e "show processlist" | wc -l`
        # Get actual percentage from MYSQL itself since bash cannot handle decimals.
        MYSQL_CON_PERCENT=`mysql --defaults-file=/var/lib/nagios/.my.cnf -e "SELECT ( pl.connections / gv.max_con ) * 100 AS percentage_used_connections FROM ( SELECT COUNT(*) AS connections FROM information_schema.processlist ) AS pl, ( SELECT  @@max_connections as max_con ) AS gv" |  awk '{ print $1 }' | tail -n 1`

        if ! [[ "$scale" =~ ^[0-9]+$ ]]
            then
                # Need to cast to int. It does not matter if it is 75.1 or 75.2.. Such value is still < limit.
                MYSQL_INT_PERCENT=$( printf "%.0f" $MYSQL_CON_PERCENT )
        else
                MYSQL_INT_PERCENT=$MYSQL_CON_PERCENT
        fi

        if [ "$MYSQL_INT_PERCENT" -gt "$CRITICAL_LIMIT" ]; then
            echo "ERROR: Connection limit at $MYSQL_CON_PERCENT%: $MYSQL_CURRENT_CONN of $MYSQL_MAX_CONN MySQL connections"
            exit ${E_CRITICAL}
        elif [ "$MYSQL_INT_PERCENT" -gt "$WARNING_LIMIT" ]; then
            echo "WARNING: Connection limit at $MYSQL_CON_PERCENT%: $MYSQL_CURRENT_CONN of $MYSQL_MAX_CONN MySQL connections"
            exit ${E_WARNING}
        fi
    else
        echo "CRITICAL: Could not gather MySQL max_connections variable"
        exit ${E_CRITICAL}
    fi

    echo "OK: MySQL is running"
    exit ${E_SUCCESS}
fi
