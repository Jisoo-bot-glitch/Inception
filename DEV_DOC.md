# Developer documentation

This document explains how to set up, build and manage the Inception stack.

## 1. Prerequisites

- A Debian virtual machine
- Docker Engine with the Compose plugin, installed from Docker's official apt repository
  (`docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`)
- `make` and `git`
- The user is in the `docker` group (`sudo usermod -aG docker $USER`, then log in again)
- The domain points to the VM itself. Add this line to `/etc/hosts`:
  ```
  127.0.0.1   jisobaek.42.fr
  ```

## 2. Configuration files and secrets (not in Git)

After cloning the repository, these files must be created by hand.
Running `make` without them fails with `env file .../srcs/.env not found`.

### `srcs/.env` — non-secret settings

```
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
DOMAIN_NAME=jisobaek.42.fr
WP_TITLE=Inception
WP_ADMIN_USER=concierge
WP_ADMIN_EMAIL=concierge@example.com
WP_USER=jisoo
WP_USER_EMAIL=jisoo@example.com
```

The administrator name must not contain `admin` or `administrator`.

### `secrets/` — passwords

| File                   | Content                                   |
|------------------------|-------------------------------------------|
| `db_root_password.txt` | one line: the MariaDB root password       |
| `db_password.txt`      | one line: the password of `MYSQL_USER`    |
| `credentials.txt`      | two lines, in this exact format:          |

```
WP_ADMIN_PASSWORD=<choose a password>
WP_USER_PASSWORD=<choose a password>
```

Use letters and digits only, to avoid quoting problems in the scripts.
Both `srcs/.env` and `secrets/` are listed in `.gitignore`.

## 3. Build and launch

```bash
make
```

This runs:

1. `mkdir -p /home/jisobaek/data/mariadb /home/jisobaek/data/wordpress`
   (the volume folders must exist before Compose creates the volumes)
2. `docker compose -f srcs/docker-compose.yml up -d --build`

Compose then:

- builds the images `mariadb:1.0`, `wordpress:1.0`, `nginx:1.0` from the Dockerfiles
  in `srcs/requirements/`
- creates the network `inception` and the volumes `mariadb_data` and `wordpress_data`
- starts **mariadb**, waits until its healthcheck reports `healthy`,
  then starts **wordpress**, then **nginx**

On the first start, the init scripts create the database, the DB user, and the
WordPress installation with its two users. On later starts they detect the existing
data and skip this step.

| Target        | Effect                                                     |
|---------------|------------------------------------------------------------|
| `make`        | create data folders, build, start                          |
| `make down`   | stop and remove the containers and the network             |
| `make re`     | `down` then `up`                                           |
| `make clean`  | `down` and remove the images                               |
| `make fclean` | `clean`, remove the volumes and delete `/home/jisobaek/data` |

## 4. Managing containers and volumes

```bash
# status and logs
docker compose -f srcs/docker-compose.yml ps
docker compose -f srcs/docker-compose.yml logs
docker logs wordpress 2>&1 | grep init.sh

# open a shell or run a command inside a container
docker exec -it mariadb mariadb -u root -p
docker exec -it mariadb mariadb -u wpuser -p
docker exec wordpress wp user list --allow-root
docker exec nginx ps aux

# network and volumes
docker network ls
docker network inspect srcs_inception
docker volume ls
docker volume inspect srcs_mariadb_data
docker volume inspect srcs_wordpress_data

# simulate a crash (the container must restart by itself)
docker exec nginx sh -c "kill 1"
docker ps
```

## 5. Where the data is stored and how it persists

| Volume           | Path in the container | Path on the VM                    | Content                       |
|------------------|-----------------------|-----------------------------------|-------------------------------|
| `mariadb_data`   | `/var/lib/mysql`      | `/home/jisobaek/data/mariadb`     | Database files                |
| `wordpress_data` | `/var/www/html`       | `/home/jisobaek/data/wordpress`   | WordPress files and uploads   |

Both are Docker **named volumes** (local driver). Their `driver_opts` set the storage
location on the VM to `/home/jisobaek/data`.

- `make down` / `make re`: containers are recreated, data is kept.
- VM reboot: the containers start again automatically (`restart: unless-stopped`),
  data is kept.
- `make fclean`: volumes and `/home/jisobaek/data` are deleted. The next `make`
  reinstalls everything from scratch.

The init scripts use these markers to know whether the setup was already done:

- MariaDB: the folder `/var/lib/mysql/wordpress`
- WordPress: the file `/var/www/html/wp-config.php`
