# User documentation

This document explains how to use the Inception stack as an end user or administrator.

## Services provided

| Service   | Role                                                                | Reachable from outside? |
|-----------|---------------------------------------------------------------------|-------------------------|
| NGINX     | HTTPS web server, the single entry point (port 443, TLS 1.2 / 1.3)  | Yes, port 443 only      |
| WordPress | The website itself, executed by PHP-FPM                             | No (only through NGINX) |
| MariaDB   | The database that stores posts, users and settings                  | No                      |

The website is available at **https://jisobaek.42.fr** (from inside the VM).

## Start and stop

Run these commands from the root of the repository:

| Action                               | Command      |
|--------------------------------------|--------------|
| Start (build if needed)              | `make`       |
| Stop (data is kept)                  | `make down`  |
| Restart                              | `make re`    |
| Delete everything, including data    | `make fclean`|

The containers restart automatically if they crash, and they start again
automatically after the VM reboots.

## Access the website and the administration panel

- Website: `https://jisobaek.42.fr`
- Administration panel: `https://jisobaek.42.fr/wp-admin`

The TLS certificate is self-signed, so the browser shows a security warning the
first time. Click **Advanced → Accept the Risk and Continue**.

Two WordPress users exist:

| User        | Role          |
|-------------|---------------|
| `concierge` | Administrator |
| `jisoo`     | Author        |

## Locate and manage credentials

Credentials are **not** stored in Git. They are kept locally on the VM:

| File                           | Contains                                        |
|--------------------------------|-------------------------------------------------|
| `secrets/db_root_password.txt` | MariaDB root password                           |
| `secrets/db_password.txt`      | MariaDB password of the WordPress DB user       |
| `secrets/credentials.txt`      | WordPress administrator and author passwords    |
| `srcs/.env`                    | Non-secret settings (domain, DB name, user names, emails) |

These values are used only the **first time** the stack is installed. To change a
WordPress password later, use the administration panel (Users → Edit). To reinstall
everything with new values, edit the files and run `make fclean` then `make`.

## Check that the services are running

```bash
docker compose -f srcs/docker-compose.yml ps
```

All three containers should be `Up`, and `mariadb` should show `(healthy)`.

Other checks:

```bash
docker logs nginx
docker logs wordpress
docker logs mariadb
curl -kI https://jisobaek.42.fr        # should answer HTTP/1.1 200 OK
```
