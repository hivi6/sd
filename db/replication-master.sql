CREATE USER 'repl'@'%' IDENTIFIED BY 'repl-lab-password';

GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';

