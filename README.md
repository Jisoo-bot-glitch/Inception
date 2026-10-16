*This activity has been created as part of the 42 curriculum by jisobaek.*

# Inception

## Description

Inception is a system administration project. The goal is to set up a small web
infrastructure made of several services, each running in its own Docker
container, inside a Debian virtual machine.

The stack serves a WordPress website over HTTPS:

- **NGINX** — the only entry point, listening on port 443 with TLSv1.2 / TLSv1.3 only
- **WordPress + PHP-FPM** — runs the WordPress PHP code (no NGINX inside)
- **MariaDB** — stores the WordPress database (no NGINX inside)

Every image is built from my own Dockerfile on top of `debian:bookworm`.
No ready-made service images are pulled.

```
        Browser
           │  443 (HTTPS, TLS 1.2/1.3)
           ▼
   ┌──────────────────── Docker network "inception" ────────────────────┐
   │   NGINX  ──── 9000 (FastCGI) ────▶  WordPress + PHP-FPM  ── 3306 ──▶  MariaDB   │
   └──────┬───────────────────────────────────┬────────────────────────────┬────┘
          └────────── wordpress_data ─────────┘                       mariadb_data
                  (/home/jisobaek/data/wordpress)                (/home/jisobaek/data/mariadb)
```

## Instructions

### Requirements

- A Debian virtual machine
- Docker Engine with the Compose plugin (`docker compose`)
- `make`

### Setup

1. Add the domain to the VM's hosts file:
   ```
   127.0.0.1   jisobaek.42.fr
   ```
2. Create the files that are **not** stored in Git (`srcs/.env` and `secrets/`).
   See [DEV_DOC.md](DEV_DOC.md) for the exact contents.
3. Build and start everything:
   ```bash
   make
   ```
4. Open `https://jisobaek.42.fr` in the VM's browser.
   The certificate is self-signed, so the browser shows a warning: accept it to continue.

### Makefile targets

| Command       | Effect                                                         |
|---------------|----------------------------------------------------------------|
| `make`        | Create the data folders, build the images, start the containers |
| `make down`   | Stop and remove the containers (data is kept)                  |
| `make re`     | `down` then `up`                                               |
| `make clean`  | `down` and remove the images                                   |
| `make fclean` | `clean`, remove the volumes and delete `/home/jisobaek/data`   |

## Project description

### Use of Docker and sources

```
.
├── Makefile
├── secrets/                     # not in Git
│   ├── credentials.txt
│   ├── db_password.txt
│   └── db_root_password.txt
└── srcs/
    ├── .env                     # not in Git
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/   (Dockerfile, conf/50-server.cnf, tools/init.sh)
        ├── wordpress/ (Dockerfile, conf/www.conf,      tools/init.sh)
        └── nginx/     (Dockerfile, conf/nginx.conf)
```

- Each service has its own **Dockerfile** (installation, done once at build time),
  a **conf/** file that replaces the default configuration, and, when needed,
  a **tools/init.sh** script that runs every time the container starts.
- `docker-compose.yml` builds the three images, connects them on one network,
  attaches the volumes and secrets, and defines the start order.
- The `Makefile` wraps the `docker compose` commands.

### Main design choices

- **Base image `debian:bookworm`.** The subject requires the penultimate stable
  version. The current Debian stable is 13 (trixie), so I used 12 (bookworm).
- **Real service as PID 1.** Each container runs its service in the foreground
  (`mariadbd`, `php-fpm8.2 -F`, `nginx -g "daemon off;"`). The init scripts end
  with `exec`, which replaces the shell with the service, so the service itself is
  PID 1. It receives Docker's stop signal directly, and if it dies the container
  dies and is restarted (`restart: unless-stopped`). No `tail -f`, `sleep infinity`
  or `while true`.
- **First-run setup at container start, not at build time.** The init scripts
  create the database, the DB user and the WordPress install only if they do not
  exist yet (`/var/lib/mysql/wordpress` and `wp-config.php` are used as markers).
  Passwords are read from Docker secrets at runtime, so they never end up in an image.
- **No wait loop.** MariaDB has a `healthcheck` (`mariadb-admin ping`), and
  WordPress uses `depends_on: condition: service_healthy`. Compose waits until
  the database is ready before starting WordPress, so the scripts contain no loop.
- **Explicit image tags (`:1.0`).** Using `image: <service>:1.0` avoids the
  default `latest` tag, which the subject forbids.
- **Self-signed TLS certificate** generated with `openssl` at build time, used
  only by NGINX, the single entry point.
- **WordPress users:** an administrator (`concierge`, without "admin" in the name)
  and a regular author user.

### Virtual Machines vs Docker

A virtual machine emulates a whole computer: it has its own operating system and
its own kernel, running on a hypervisor. A Docker container is an isolated box for
one program. It has no kernel of its own and shares the kernel of the host (here,
the VM). This makes containers much lighter and faster to start than VMs.
In this project both are used: VirtualBox runs a Debian VM, and Docker runs the
three containers inside that VM.

### Secrets vs Environment Variables

Environment variables are easy to use, but they are visible to anyone inside the
container (`env`) and in `docker inspect`, and every service that loads the
`.env` file receives all of them. Docker secrets are mounted as files under
`/run/secrets/`, are not shown by `docker inspect`, and are given only to the
services that list them (for example, WordPress does not receive the MariaDB root
password). I put non-sensitive settings (database name, user names, domain) in
`.env`, and all passwords in `secrets/`. Both `.env` and `secrets/` are ignored
by Git.

### Docker Network vs Host Network

With `network: host`, a container uses the host's network directly: every port it
opens (for example MariaDB on 3306) would be reachable from outside, and there is
no isolation between services. With a Docker bridge network (`inception`), the
containers are isolated from the outside and can reach each other by service name
(`mariadb`, `wordpress`) thanks to Docker's internal DNS. Only NGINX publishes a
port (`443:443`), so it is the only way into the infrastructure.

### Docker Volumes vs Bind Mounts

A bind mount links a path chosen on the host directly into a container. Docker
does not manage it: it does not appear in `docker volume ls` and depends on the
host's folder layout. A named volume is created and managed by Docker (it has a
name, it can be listed, inspected and removed with `docker volume` commands, and
Compose creates it automatically). In both cases the data stays on the host disk
when the container is removed. This project uses two **named volumes**
(`mariadb_data`, `wordpress_data`). Their `driver_opts` set the storage location
to `/home/jisobaek/data/...`, as required, while they remain Docker-managed volumes.

## Resources

- Docker — Dockerfile reference: https://docs.docker.com/reference/dockerfile/
- Docker — Compose file reference: https://docs.docker.com/reference/compose-file/
- Docker — Secrets in Compose: https://docs.docker.com/compose/how-tos/use-secrets/
- Docker — Volumes: https://docs.docker.com/engine/storage/volumes/
- Docker — Networking: https://docs.docker.com/engine/network/
- NGINX — SSL module: https://nginx.org/en/docs/http/ngx_http_ssl_module.html
- NGINX — FastCGI module: https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html
- PHP-FPM configuration: https://www.php.net/manual/en/install.fpm.configuration.php
- MariaDB — CREATE USER: https://mariadb.com/kb/en/create-user/
- WP-CLI commands: https://developer.wordpress.org/cli/commands/

### How AI was used

I used an AI assistant as a tutor. It helped me understand the overall structure
of the project and how the services relate to each other, and it explained the
concepts and commands I did not know (PID 1 and `exec`, Docker secrets, named
volumes, FastCGI, TLS). I installed each service by hand inside a test container
first, then wrote the Dockerfiles, configuration files and scripts myself, line by
line, and debugged the errors by reading the logs. The AI also helped me turn my
own explanations of the four comparisons into English for this README.
