FROM debian:bookworm
RUN apt-get update && apt-get install -y mariadb-server
RUN mkdir -p /run/mysqld && chown mysql:mysql /run/mysqld
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh
ENTRYPOINT ["/usr/local/bin/init.sh"]
