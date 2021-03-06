#!/bin/sh

scutil_query()
{
    key=$1

    scutil<<EOT
    open
    get $key
    d.show
    close
EOT
}

SERVICE_GUID=`scutil_query State:/Network/Global/IPv4 | grep "PrimaryService" | awk '{print $3}'`

SERVICE_NAME=`scutil_query Setup:/Network/Service/$SERVICE_GUID | grep "UserDefinedName" | awk -F': ' '{print $2}'`

echo $SERVICE_NAME

if [[ ${SERVICE_NAME} =~ ' is not ' ]] || [[ ${SERVICE_NAME} == '' ]]; then
    echo "Not a Valid Service Name"
else
    /usr/sbin/networksetup -setsearchdomains "$SERVICE_NAME" SEARCH_DOMAINS
fi
