# Developer Documentation

This document explains how to set up, build, run and maintain the `inception` stack
(NGINX + WordPress/PHP-FPM + MariaDB, each in its own Docker container, orchestrated with
Docker Compose and a Makefile).

## 1. Setting up the environment from scratch

### 1.1 Prerequisites

- Docker Engine and the Docker Compose plugin (`docker compose`).
- `make`.
- `sudo` rights (used by `make fclean` to remove the host data directory).
- A resolvable domain name for the site, e.g. by adding it to `/etc/hosts`:
  ```
  127.0.0.1   atashiro.42.fr
  ```

### 1.2 Repository layout

```
.
├── Makefile
└── srcs/
    ├── .env                          # all configuration/secrets (not committed publicly)
    ├── docker-compose.yml            # the 3 services + volumes + network
    └── requirements/
        ├── nginx/
        │   ├── Dockerfile            # builds NGINX + self-signed TLS cert
        │   └── conf/nginx.conf       # HTTPS vhost, proxies *.php to wordpress:9000
        ├── wordpress/
        │   ├── Dockerfile            # PHP83 + PHP-FPM + wp-cli
        │   └── tools/setup.sh        # entrypoint: waits for DB, installs WordPress
        └── mariadb/
            ├── Dockerfile            # builds MariaDB
            ├── conf/50-server.cnf    # datadir / bind-address / port
            └── tools/init.sh         # entrypoint: initializes DB, users, privileges
```

### 1.3 Configuration files and secrets

Everything is configured through **`srcs/.env`**, loaded by every service via `env_file:
.env` in `docker-compose.yml`. It must define:

| Variable              | Used by            | Purpose                                                |
|------------------------|--------------------|---------------------------------------------------------|
| `DOMAIN_NAME`          | (site access)      | Domain used to reach the site, e.g. `atashiro.42.fr`     |
| `MYSQL_DATABASE`       | mariadb, wordpress | Name of the WordPress database                          |
| `MYSQL_USER`           | mariadb, wordpress | MySQL user WordPress connects with                       |
| `MYSQL_PASSWORD`       | mariadb, wordpress | Password for `MYSQL_USER`                                |
| `MYSQL_ROOT_PASSWORD`  | mariadb            | Password for the MariaDB `root` account                  |
| `WP_URL`               | wordpress/setup.sh | Site URL passed to `wp core install`                      |
| `WP_TITLE`             | wordpress/setup.sh | Site title passed to `wp core install`                    |
| `WP_ADMIN_USER`        | wordpress/setup.sh | WordPress administrator username (must not contain "admin") |
| `WP_ADMIN_PASSWORD`    | wordpress/setup.sh | WordPress administrator password                          |
| `WP_ADMIN_EMAIL`       | wordpress/setup.sh | WordPress administrator email                             |
| `WP_USER`              | wordpress/setup.sh | Second, non-admin WordPress user (role: author)            |
| `WP_USER_EMAIL`        | wordpress/setup.sh | Email for the second user                                  |
| `WP_USER_PASSWORD`     | wordpress/setup.sh | Password for the second user                                |

`srcs/requirements/wordpress/tools/setup.sh` reads the `WP_*` variables directly, so they
must all be present in `srcs/.env` (in addition to the `MYSQL_*`/`DOMAIN_NAME` ones already
there) for the automatic install to succeed.

No secret is hardcoded in a Dockerfile or committed config file — everything sensitive goes
through `.env`, which should never be pushed to a public remote.

## 2. Building and launching the project

The `Makefile` wraps `docker compose -f srcs/docker-compose.yml`:

```sh
make        # == make all: creates host data dirs, then `docker compose up -d --build`
make down   # docker compose down (stop + remove containers, keep images/volumes)
make clean  # docker compose down --rmi all (also remove built images)
make fclean # docker compose down -v --rmi all, then delete the host data dir,
            # then `docker system prune -af` (also removes volumes and ALL local data)
make re     # fclean, then all — full rebuild from a clean state
```

Startup order is enforced with `depends_on` in `docker-compose.yml`:
`mariadb` → `wordpress` → `nginx`. Note `depends_on` only waits for the container to
start, not for the service inside to be ready — actual readiness is handled by the
entrypoint scripts:
- `mariadb/tools/init.sh` initializes the DB (first run only) and creates the database,
  the app user and the root password, before starting `mariadbd` in the foreground.
- `wordpress/tools/setup.sh` polls MariaDB with `mariadb -h mariadb ... -e "SELECT 1"`
  until it responds, then runs `wp core download/config/install` and creates the two
  WordPress users (only if `wp-config.php` doesn't already exist), before starting
  `php-fpm83` in the foreground.

## 3. Managing containers and volumes

Common `docker compose` commands (run from the repo root, pointing at `srcs/docker-compose.yml`):

```sh
docker compose -f srcs/docker-compose.yml ps                 # status of the 3 services
docker compose -f srcs/docker-compose.yml logs -f <service>  # tail logs (nginx/wordpress/mariadb)
docker compose -f srcs/docker-compose.yml exec <service> sh  # shell into a running container
docker compose -f srcs/docker-compose.yml restart <service>  # restart one service
docker compose -f srcs/docker-compose.yml build <service>    # rebuild one service's image
docker compose -f srcs/docker-compose.yml down               # stop and remove containers
docker volume ls                                              # list volumes (db_data, wp_data)
docker volume inspect srcs_db_data srcs_wp_data                # inspect volume mount points
```

To reset only the database while keeping the WordPress files, remove just the `db_data`
volume (stack must be down first):
```sh
docker compose -f srcs/docker-compose.yml down
docker volume rm srcs_db_data
make        # mariadb/tools/init.sh re-initializes an empty datadir
```

## 4. Where project data is stored and how it persists

Data is persisted with two named Docker volumes, both using the `local` driver with a bind
mount to fixed paths on the host (declared in `srcs/docker-compose.yml`):

| Volume     | Mounted in container at | Bound to host path              | Contents                        |
|------------|--------------------------|----------------------------------|----------------------------------|
| `db_data`  | `mariadb:/var/lib/mysql` | `/home/atashiro/data/mariadb`    | MariaDB datadir (all DB files)   |
| `wp_data`  | `wordpress:/var/www/html` and `nginx:/var/www/html` | `/home/atashiro/data/wordpress` | WordPress core files, themes, plugins, uploads |

`wp_data` is shared between `wordpress` and `nginx` so NGINX can serve static assets
directly while PHP files are proxied to PHP-FPM.

Because these are bind-mounted to fixed host paths (created by `make all` via
`mkdir -p $(DATA)/wordpress $(DATA)/mariadb`), data survives `make down` and `make clean`
(containers/images removed, data untouched) but is **permanently deleted** by `make fclean`,
which removes both the Docker volumes and the `$(DATA)` directory itself
(`/home/atashiro/data` by default — see the `DATA` variable at the top of the `Makefile`).
