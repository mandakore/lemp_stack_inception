# User Documentation

This document explains, from an end-user / administrator point of view, how to use the
`inception` stack: a WordPress website served over HTTPS, backed by MariaDB, behind an
NGINX reverse proxy.

## 1. What services does the stack provide?

The stack is made of three containers, each running a single service, connected through a
dedicated `inception` Docker network:

| Container   | Service                          | Role                                                                 |
|-------------|-----------------------------------|-----------------------------------------------------------------------|
| `nginx`     | NGINX (TLSv1.2 / TLSv1.3 only)    | Single entry point of the stack. Terminates HTTPS on port 443 and forwards PHP requests to WordPress. It is the only container exposing a port to the host. |
| `wordpress` | WordPress + PHP-FPM (php83)       | Renders the website / admin panel and executes PHP. It does not listen on any host port; it is only reachable from `nginx` inside the Docker network. |
| `mariadb`   | MariaDB                           | Stores the WordPress database (posts, users, settings, etc.). Only reachable from `wordpress` inside the Docker network. |

## 2. Starting and stopping the project

All operations are driven by the `Makefile` at the root of the repository, which wraps
`docker compose -f srcs/docker-compose.yml`.

- **Start (build + run in the background):**
  ```sh
  make
  # or
  make all
  ```
  This creates the data directories on the host and builds/starts all three containers.

- **Stop the containers (keeps images, volumes and data):**
  ```sh
  make down
  ```

- **Stop and remove the containers' images too (keeps volumes/data):**
  ```sh
  make clean
  ```

- **Full reset — stop everything, remove containers, images, volumes AND all
  website/database data on disk:**
  ```sh
  make fclean
  ```
  ⚠️ This permanently deletes the WordPress files and the database content.

- **Rebuild everything from scratch:**
  ```sh
  make re
  ```

## 3. Accessing the website and the administration panel

The site is served over HTTPS only (plain HTTP is not exposed).

- **Website:** `https://<DOMAIN_NAME>/`
- **WordPress administration panel:** `https://<DOMAIN_NAME>/wp-admin/`

`<DOMAIN_NAME>` is defined by the `DOMAIN_NAME` variable in `srcs/.env` (for example
`atashiro.42.fr`). For the domain name to resolve on your machine, add an entry pointing it
to the host running the stack, e.g. in `/etc/hosts`:

```
127.0.0.1   atashiro.42.fr
```

Because NGINX uses a self-signed TLS certificate, your browser will show a security
warning on first visit — this is expected; accept/continue past it to reach the site.

Log in to the admin panel with one of the WordPress accounts described below.

## 4. Locating and managing credentials

All credentials and configuration secrets live in a single file: **`srcs/.env`**
(this file is not committed to a public repository and should be kept private).

It currently defines the database credentials:

| Variable              | Purpose                                              |
|------------------------|-------------------------------------------------------|
| `DOMAIN_NAME`          | Domain name used to access the site (e.g. `atashiro.42.fr`) |
| `MYSQL_DATABASE`       | Name of the WordPress database                       |
| `MYSQL_USER`           | Regular MySQL user used by WordPress to read/write data |
| `MYSQL_PASSWORD`       | Password for `MYSQL_USER`                             |
| `MYSQL_ROOT_PASSWORD`  | Password for the MariaDB `root` account               |

The WordPress site itself also needs its admin/author account credentials
(`WP_ADMIN_USER`, `WP_ADMIN_PASSWORD`, `WP_ADMIN_EMAIL`, `WP_USER`, `WP_USER_PASSWORD`,
`WP_USER_EMAIL`, `WP_URL`, `WP_TITLE`) — see [DEV_DOC.md](DEV_DOC.md) for the full list, as
these must also be set in `srcs/.env` for the automatic WordPress installation to work.

To change a credential: edit `srcs/.env`, then rebuild the stack (`make re`) so the
containers pick up the new values.

## 5. Checking that the services are running correctly

- **List the running containers and their status:**
  ```sh
  docker compose -f srcs/docker-compose.yml ps
  ```
  All three services (`nginx`, `wordpress`, `mariadb`) should show as `Up`/`running`.

- **Follow the logs of a specific service** (useful to see startup errors):
  ```sh
  docker compose -f srcs/docker-compose.yml logs -f nginx
  docker compose -f srcs/docker-compose.yml logs -f wordpress
  docker compose -f srcs/docker-compose.yml logs -f mariadb
  ```

- **Verify the website responds:**
  ```sh
  curl -vk https://<DOMAIN_NAME>/
  ```
  (`-k` is required because of the self-signed certificate.) A valid HTML response means
  NGINX, PHP-FPM and the database connection are all working.

- **Verify a container restarts on failure:** all three services are configured with
  `restart: always`, so if the Docker daemon or a container crashes, it should come back up
  automatically; `docker compose ps` will show a low uptime if that happened recently.
