#!/bin/bash

PODMAN_NETWORK=sd-net

WEBSERVER_IMAGE=localhost/sd:latest
WEBSERVER_CONTAINER=sd-backend

DB_IMAGE=docker.io/library/mysql:8.4.11
DB_CONTAINER=sd-db

LB_IMAGE=docker.io/library/nginx:stable-alpine
LB_CONTAINER=sd-lb

CMD_NETWORK_CREATE=${CMD_NETWORK_CREATE:-0}
CMD_NETWORK_DELETE=${CMD_NETWORK_DELETE:-0}
CMD_WEBSERVER_BUILD=${CMD_WEBSERVER_BUILD:-0}
CMD_WEBSERVER_START=${CMD_WEBSERVER_START:-0}
CMD_WEBSERVER_STOP=${CMD_WEBSERVER_STOP:-0}
CMD_WEBSERVER_LOG=${CMD_WEBSERVER_LOG:-0}
CMD_WEBSERVER=${CMD_WEBSERVER:-0}

CMD_DB_START=${CMD_DB_START:-0}
CMD_DB_STOP=${CMD_DB_STOP:-0}
CMD_DB_LOG=${CMD_DB_LOG:-0}
CMD_DB_CLI=${CMD_DB_CLI:-0}
CMD_DB_CREATE=${CMD_DB_CREATE:-0}
CMD_DB=${CMD_DB:-0}

CMD_LB_START=${CMD_LB_START:-0}
CMD_LB_STOP=${CMD_LB_STOP:-0}
CMD_LB_LOG=${CMD_LB_LOG:-0}
CMD_LB=${CMD_LB:-0}

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
	for i in {0..1}; do
		podman run -d --net=$PODMAN_NETWORK \
			--name $WEBSERVER_CONTAINER-$i \
			--hostname $WEBSERVER_CONTAINER-$i \
			$WEBSERVER_IMAGE
	done
}

webserver_stop() {
	podman stop $WEBSERVER_CONTAINER-{0..1}
	podman rm $WEBSERVER_CONTAINER-{0..1}
}

webserver_log() {
	podman logs -f $WEBSERVER_CONTAINER-0
}

webserver() {
	trap webserver_stop EXIT

	webserver_build || return
	webserver_start || return
	webserver_log
}

db_start() {
	# server id cannot start with 0
	podman run --net=$PODMAN_NETWORK -d \
		-e MYSQL_ROOT_PASSWORD=root \
		--name $DB_CONTAINER-0 $DB_IMAGE \
			--server-id=1 \
			--gtid-mode=ON \
			--enforce-gtid-consistency=ON

	podman run --net=$PODMAN_NETWORK -d \
		-e MYSQL_ROOT_PASSWORD=root \
		--name $DB_CONTAINER-1 $DB_IMAGE \
			--server-id=2 \
			--gtid-mode=ON \
			--enforce-gtid-consistency=ON
}

db_stop() {
	podman stop $DB_CONTAINER-{0..1}
	podman rm $DB_CONTAINER-{0..1}
}

db_log() {
	podman logs -f $DB_CONTAINER-0
}

db_cli() {
	podman exec -it $DB_CONTAINER-0 \
		mysql -u root -proot "$@"
}

db_create() {
	podman exec -i "$DB_CONTAINER-0" mysql -u root -proot \
		< db/replication-master.sql

	podman exec -i "$DB_CONTAINER-1" mysql -u root -proot \
		< db/replication-slave.sql

	podman exec -i "$DB_CONTAINER-0" mysql -u root -proot \
		< db/schema-0.sql
}

db() {
	trap db_stop EXIT

	db_start || return

	local exit_code=1
	for i in {0..100}; do
		db_cli -e "SELECT 1"
		exit_code=$?
		[ "$exit_code" == 0 ] && break
		sleep 1s
	done

	[ $exit_code != 0 ] && return

	db_create || return
	db_log
}

lb_start() {
	podman run -d \
		--name $LB_CONTAINER \
		--net=$PODMAN_NETWORK \
		-p 8000:8000 \
		-v "$PWD/lb/default.conf:/etc/nginx/conf.d/default.conf:ro" \
		$LB_IMAGE
}

lb_stop() {
	podman stop $LB_CONTAINER
	podman rm $LB_CONTAINER
}

lb_log() {
	podman logs -f $LB_CONTAINER
}

lb() {
	trap lb_stop EXIT

	lb_start || return
	lb_log
}

[ "$CMD_NETWORK_CREATE" == 1 ] && network_create
[ "$CMD_NETWORK_DELETE" == 1 ] && network_delete

[ "$CMD_WEBSERVER_BUILD" == 1 ] && webserver_build
[ "$CMD_WEBSERVER_START" == 1 ] && webserver_start
[ "$CMD_WEBSERVER_STOP" == 1 ] && webserver_stop
[ "$CMD_WEBSERVER_LOG" == 1 ] && webserver_log
[ "$CMD_WEBSERVER" == 1 ] && webserver

[ "$CMD_DB_START" == 1 ] && db_start
[ "$CMD_DB_STOP" == 1 ] && db_stop
[ "$CMD_DB_LOG" == 1 ] && db_log
[ "$CMD_DB_CLI" == 1 ] && db_cli "$@"
[ "$CMD_DB_CREATE" == 1 ] && db_create
[ "$CMD_DB" == 1 ] && db

[ "$CMD_LB_START" == 1 ] && lb_start
[ "$CMD_LB_STOP" == 1 ] && lb_stop
[ "$CMD_LB_LOG" == 1 ] && lb_log
[ "$CMD_LB" == 1 ] && lb

