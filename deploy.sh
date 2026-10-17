#!/bin/bash

PODMAN_NETWORK=sd-net

WEBSERVER_IMAGE=localhost/sd:latest
WEBSERVER_CONTAINER=sd-backend

DB_IMAGE=docker.io/library/mysql:8.4.11
DB_CONTAINER=sd-db

CMD_NETWORK_CREATE=${CMD_NETWORK_CREATE:-0}
CMD_NETWORK_DELETE=${CMD_NETWORK_DELETE:-0}
CMD_WEBSERVER_BUILD=${CMD_WEBSERVER_BUILD:-0}
CMD_WEBSERVER_START=${CMD_WEBSERVER_START:-0}
CMD_WEBSERVER_STOP=${CMD_WEBSERVER_STOP:-0}
CMD_WEBSERVER_LOG=${CMD_WEBSERVER_LOG:-0}
CMD_DB_START=${CMD_DB_START:-0}
CMD_DB_STOP=${CMD_DB_STOP:-0}
CMD_DB_LOG=${CMD_DB_LOG:-0}
CMD_DB_CLI=${CMD_DB_CLI:-0}
CMD_DB_CREATE=${CMD_DB_CREATE:-0}

network_create() {
	podman network create $PODMAN_NETWORK
}

network_delete() {
	podman network rm $PODMAN_NETWORK
}

webserver_build() {
	podman build -t $WEBSERVER_IMAGE backend
}

webserver_start() {
	podman run -d --net=$PODMAN_NETWORK -p 8000:8000 \
		--name $WEBSERVER_CONTAINER $WEBSERVER_IMAGE
}

webserver_stop() {
	podman stop $WEBSERVER_CONTAINER
	podman rm $WEBSERVER_CONTAINER
}

webserver_log() {
	podman logs -f $WEBSERVER_CONTAINER
}

db_start() {
	podman run --net=$PODMAN_NETWORK -d -e MYSQL_ROOT_PASSWORD=root \
		--name $DB_CONTAINER $DB_IMAGE
}

db_stop() {
	podman stop $DB_CONTAINER
	podman rm $DB_CONTAINER
}

db_log() {
	podman logs -f $DB_CONTAINER
}

db_cli() {
	podman exec -it $DB_CONTAINER \
		mysql -u root -proot "$@"
}

db_create() {
	podman exec -i "$DB_CONTAINER" mysql -u root -proot \
		< db/schema-0.sql
}

[ "$CMD_NETWORK_CREATE" == 1 ] && network_create
[ "$CMD_NETWORK_DELETE" == 1 ] && network_delete
[ "$CMD_WEBSERVER_BUILD" == 1 ] && webserver_build
[ "$CMD_WEBSERVER_START" == 1 ] && webserver_start
[ "$CMD_WEBSERVER_STOP" == 1 ] && webserver_stop
[ "$CMD_WEBSERVER_LOG" == 1 ] && webserver_log
[ "$CMD_DB_START" == 1 ] && db_start
[ "$CMD_DB_STOP" == 1 ] && db_stop
[ "$CMD_DB_LOG" == 1 ] && db_log
[ "$CMD_DB_CLI" == 1 ] && db_cli "$@"
[ "$CMD_DB_CREATE" == 1 ] && db_create

