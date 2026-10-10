#!/bin/sh

[ "$ACTION" = ifup ] || exit 0
[ "$DEVICE" = "br-wan" ] || exit 0

/lib/gluon/fnsh/wan-limit.uc