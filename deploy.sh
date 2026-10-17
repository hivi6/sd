#!/bin/bash

WEBSERVER_IMAGE=localhost/sd:latest
WEBSERVER_CONTAINER=sd-backend

DB_IMAGE=docker.io/library/mysql:8.4.11
DB_CONTAINER=sd-db

CMD_WEBSERVER_BUILD=${CMD_WEBSERVER_BUILD:-0}
CMD_WEBSERVER_START=${CMD_WEBSERVER_START:-0}
CMD_WEBSERVER_STOP=${CMD_WEBSERVER_STOP:-0}
CMD_WEBSERVER_LOG=${CMD_WEBSERVER_LOG:-0}
CMD_DB_START=${CMD_DB_START:-0}
CMD_DB_STOP=${CMD_DB_STOP:-0}
CMD_DB_LOG=${CMD_DB_LOG:-0}
CMD_DB_CLI=${CMD_DB_CLI:-0}
CMD_DB_CREATE=${CMD_DB_CREATE:-0}

webserver_build() {
	podman build -t $WEBSERVER_IMAGE backend
}

webserver_start() {
	podman run -d -p 8000:8000 --name $WEBSERVER_CONTAINER $WEBSERVER_IMAGE
}

webserver_stop() {
	podman stop $WEBSERVER_CONTAINER
	podman rm $WEBSERVER_CONTAINER
}

webserver_log() {
	podman logs -f $WEBSERVER_CONTAINER
}

db_start() {
	podman run -d -p 3306:3306 -e MYSQL_ROOT_PASSWORD=root \
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
	podman exec -it $DB_CONTAINER mysql -u root -proot "$@"
}

db_create() {
	podman exec -i "$DB_CONTAINER" mysql -u root -proot \
		< db/schema-0.sql
}

[ "$CMD_WEBSERVER_BUILD" == 1 ] && webserver_build
[ "$CMD_WEBSERVER_START" == 1 ] && webserver_start
[ "$CMD_WEBSERVER_STOP" == 1 ] && webserver_stop
[ "$CMD_WEBSERVER_LOG" == 1 ] && webserver_log
[ "$CMD_DB_START" == 1 ] && db_start
[ "$CMD_DB_STOP" == 1 ] && db_stop
[ "$CMD_DB_LOG" == 1 ] && db_log
[ "$CMD_DB_CLI" == 1 ] && db_cli "$@"
[ "$CMD_DB_CREATE" == 1 ] && db_create

