#!/bin/bash

IMAGE_NAME=localhost/sd:latest
CONTAINER_NAME=sd

CMD_WEBSERVER_BUILD=${CMD_WEBSERVER_BUILD:-0}
CMD_WEBSERVER_START=${CMD_WEBSERVER_START:-0}
CMD_WEBSERVER_STOP=${CMD_WEBSERVER_STOP:-0}
CMD_WEBSERVER_LOG=${CMD_WEBSERVER_LOG:-0}

webserver_build() {
	podman build -t $IMAGE_NAME backend
}

webserver_run() {
	podman run -d -p 8000:8000 --name $CONTAINER_NAME $IMAGE_NAME
}

webserver_stop() {
	podman stop $CONTAINER_NAME
	podman rm $CONTAINER_NAME
}

webserver_log() {
	podman logs -f $CONTAINER_NAME
}

[ "$CMD_WEBSERVER_BUILD" == 1 ] && webserver_build
[ "$CMD_WEBSERVER_START" == 1 ] && webserver_run
[ "$CMD_WEBSERVER_STOP" == 1 ] && webserver_stop
[ "$CMD_WEBSERVER_LOG" == 1 ] && webserver_log

