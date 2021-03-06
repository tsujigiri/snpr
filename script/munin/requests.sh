#!/usr/bin/env sh

case $1 in
	config)
		cat <<EOM
graph_title requests
graph_vlabel requests
graph_category opensnp.org
req.label requests
req.type DERIVE
req.min 0
EOM
	exit 0;;
esac

req=$(egrep -c '^Started ' /var/www/snpr/log/extra_production.log)
echo "req.value ${req}"
