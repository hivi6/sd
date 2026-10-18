# sd

Learning basic system design

## Deploying

For deploying the webserver, run the following in a given terminal:

```bash
CMD_WEBSERVER=1 bash deploy.sh
```

To deploy the database, run the following in another terminal:

```bash
CMD_DB=1 bash deploy.sh
```

To deploy load balancer, run the following in another terminal:

```bash
CMD_LB=1 bash deploy.sh
```

## Current configuration

Webserver configuration:
- 2 webserver

Database configuration:
- 1 write database
- 1 read database

Loadbalancer configuration:
- 1 load balancer connected to 2 webserver

