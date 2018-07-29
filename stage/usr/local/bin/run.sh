#!/bin/sh

# stamp out nginx template
if [ -z "$UPSTREAM_SERVER" ]; then
    export UPSTREAM_SERVER="unix:/var/run/default-server.sock"
    cp /etc/nginx/templates/default-server.conf /etc/nginx/conf.d/
fi
if [ ! -f "/etc/nginx/conf.d/upstream-server.conf" ]; then
    envsubst '${UPSTREAM_SERVER}' \
        < /etc/nginx/templates/upstream-server.conf \
        > /etc/nginx/conf.d/upstream-server.conf
fi

# start okta-nginx
okta-nginx &
okta_verify_pid=$!

okta_verify_started="false"
for i in $(seq 0 50); do
    if [ -S "/var/run/auth.sock" ]; then
        okta_verify_started="true"
        break
    fi
    sleep 0.1
done

if [ "$okta_verify_started" = "false" ]; then
    echo "okta-nginx failed to start" >&2
    exit 1
fi
echo "okta-nginx started"

# start nginx
nginx -g 'daemon off;' &
nginx_pid=$!
echo "nginx started"

# monitor
while true; do
    if ! kill -0 "$okta_verify_pid"; then
        echo "okta-nginx has died" >&2
        exit 1
    fi
    if ! kill -0 "$nginx_pid"; then
        echo "nginx has died" >&2
        exit 1
    fi
    sleep 0.1
done
