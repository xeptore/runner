#!/bin/sh

set -x

ip -4 route add 0.0.0.0/0 dev tun0 table 51821 && {
    ip -4 rule add not fwmark 2 table 51821
    ip -4 rule add table main suppress_prefixlength 0
}

cat >/etc/resolv.conf <<EOF
nameserver 1.1.1.2
EOF
