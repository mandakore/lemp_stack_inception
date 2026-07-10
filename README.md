*This project has been created as part of the 42 curriculum by atashiro.*

# Inception

## Description

`Inception` is a system administration project whose goal is to deploy a small, production-style
web infrastructure entirely with Docker, where every service runs in its own container built
from a **custom Dockerfile** (no pre-built application images from Docker Hub, no `latest` tags).

The stack reproduces a classic LEMP-style setup:

- **NGINX** — the single entry point of the stack, terminating TLS (TLSv1.2/TLSv1.3 only) on
  port 443 and reverse-proxying PHP requests to WordPress.
- **WordPress + PHP-FPM** — renders the site and the admin panel; not reachable from outside
  the Docker network.
- **MariaDB** — stores the WordPress database; only reachable from the WordPress container.

Each service lives in its own container, they are orchestrated together with Docker Compose,
and everything is driven from a single `Makefile` at the root of the repository.

## Project Description

### Sources included in the project

```
.
├── Makefile                          # wraps `docker compose` (all/down/clean/fclean/re)
├── secrets/                          # secret files mounted as Docker secrets (not versioned)
└── srcs/
    ├── .env                          # configuration (domain, DB, WordPress accounts)
    ├── docker-compose.yml            # 3 services + volumes + network definition
    └── requirements/
        ├── nginx/                    # Dockerfile + nginx.conf (HTTPS vhost, proxy_pass to wordpress:9000)
        ├── wordpress/                # Dockerfile + setup.sh (wp-cli install, PHP-FPM entrypoint)
        └── mariadb/                  # Dockerfile + init.sh (DB/user/privileges init, mariadbd entrypoint)
```

Full details on each file's role are documented in [DEV_DOC.md](DEV_DOC.md) (developer/maintainer
point of view) and [USER_DOC.md](USER_DOC.md) (end-user/administrator point of view).

### Main design choices

- **One service per container, one Dockerfile per service.** Each Dockerfile builds its image
  from a base Linux image, installing only what that service needs (nginx, php83-fpm + wp-cli,
  mariadb), so the containers stay minimal and independently rebuildable.
- **A single entry point.** Only `nginx` publishes a port to the host (443). `wordpress` and
  `mariadb` are only reachable from inside the dedicated `inception` Docker network, reducing
  the attack surface.
- **Foreground entrypoint scripts.** `mariadb/tools/init.sh` and `wordpress/tools/setup.sh`
  perform one-time initialization (DB/user creation, WordPress install via `wp-cli`) and then
  exec the real service process (`mariadbd`, `php-fpm83`) in the foreground, as required for a
  container's PID 1.
- **Everything configurable through `.env`**, loaded by all three services via `env_file`, so no
  domain name, database name or WordPress account is hardcoded in a Dockerfile or in
  `docker-compose.yml`.

### Virtual Machines vs Docker

A **VM** virtualizes an entire machine: a hypervisor emulates hardware and each VM runs its own
full guest OS kernel on top of it. This gives strong isolation but is heavy (minutes to boot,
GBs of disk/RAM per instance) and wastes resources when all you need is to isolate a handful of
processes.

**Docker** containers share the host's kernel and only isolate the process at the userland level
(namespaces + cgroups). Images are built in layers from a lightweight base, start in seconds, and
use a fraction of the disk/RAM a VM would. This project uses Docker rather than VMs because the
goal is to isolate and reproduce three cooperating *services* (nginx, PHP-FPM, MariaDB), not to
run three independent, fully separate operating systems — Docker gives the required isolation
between services at a much lower operational cost, and makes the whole stack trivially
reproducible (`make` rebuilds it identically on any Docker host).

### Secrets vs Environment Variables

**Environment variables** (as used in `srcs/.env`, loaded via `env_file`) are simple and
convenient, but they end up in the process environment of the container and are visible to
anything able to inspect it (`docker inspect`, `/proc/<pid>/environ`), and they are also easy to
leak into logs or `docker-compose.yml` diffs if not careful.

**Docker secrets** (`db_root_password`, `db_password`, `credentials` in `docker-compose.yml`,
sourced from files under `secrets/`) are mounted read-only as files under `/run/secrets/<name>`
inside only the containers that declare them, and are never exposed through `docker inspect` or
the container's environment. In this project the actual passwords (MariaDB root password, the
WordPress DB password, and admin credentials) are distributed as Docker secrets rather than
plain `.env` variables, while non-sensitive configuration (domain name, database name, WordPress
titles/usernames) stays in `.env` — reserving secrets for the values that must not leak.

### Docker Network vs Host Network

With **host networking**, a container shares the host's network namespace directly: no isolation,
every exposed port is a host port, and containers can freely reach anything the host can reach —
convenient but insecure, and it makes container-to-container communication ambiguous (everything
looks like `localhost`).

This project instead defines a dedicated **bridge network** (`inception`, declared under
`networks:` in `docker-compose.yml`). All three containers join it and can resolve each other by
service name (`mariadb`, `wordpress`, `nginx`) through Docker's embedded DNS, while staying
isolated from the host's network and from other Docker networks on the same machine. Only
`nginx` publishes a port to the host (`443:443`); `wordpress` and `mariadb` are reachable *only*
from within this network, which is what actually enforces "WordPress only reachable from nginx,
MariaDB only reachable from WordPress."

### Docker Volumes vs Bind Mounts

A **bind mount** maps an arbitrary host path directly into a container; it is simple but
depends on that exact path existing on the host and is managed entirely outside Docker.

A **named volume** is a storage area created and managed by Docker itself (normally under
`/var/lib/docker/volumes/...`), independent of any particular host path, which makes it more
portable and is the mechanism Docker expects you to use for persistent data.

This project uses named volumes (`db_data`, `wp_data`) declared with the `local` driver, but
configured with `driver_opts: { type: none, o: bind, device: ... }` to bind them to fixed host
paths (`/home/atashiro/data/mariadb` and `/home/atashiro/data/wordpress`, created by `make all`).
This combines the two: data is addressed through Docker volume names in `docker-compose.yml`
(`db_data:/var/lib/mysql`, `wp_data:/var/www/html`), while still landing at a known, inspectable
location on the host — `wp_data` is in turn shared between `wordpress` and `nginx` so NGINX can
serve static files directly while PHP is proxied to PHP-FPM. Data therefore survives
`make down`/`make clean`, and is only removed on `make fclean`.

## Instructions

### Prerequisites

- Docker Engine and the Docker Compose plugin (`docker compose`).
- `make`.
- `sudo` rights (used by `make fclean` to remove the host data directory).
- A resolvable domain name for the site, e.g. by adding it to `/etc/hosts`:
  ```
  127.0.0.1   atashiro.42.fr
  ```
- A configured `srcs/.env` (see `srcs/.env.example`) and the secret files under `secrets/`
  referenced by `srcs/docker-compose.yml`.

### Build and run

```sh
make        # creates the host data directories, then `docker compose up -d --build`
```

### Other targets

```sh
make down   # stop and remove the containers (images, volumes and data are kept)
make clean  # like `down`, also removes the built images
make fclean # like `clean` with volumes removed too, deletes the host data directory,
            # and prunes the Docker system — permanently deletes all data
make re     # fclean, then all — full rebuild from a clean state
```

### Accessing the site

Once the stack is up, the website is served over HTTPS only:

- Website: `https://<DOMAIN_NAME>/`
- WordPress admin panel: `https://<DOMAIN_NAME>/wp-admin/`

The browser will warn about the self-signed TLS certificate on first visit — this is expected.

For day-to-day operation (checking status, following logs, resetting only the database, etc.),
see [USER_DOC.md](USER_DOC.md); for the full technical breakdown of the configuration, the
entrypoint scripts and how startup ordering/readiness is handled, see [DEV_DOC.md](DEV_DOC.md).

## Resources

- [Docker documentation](https://docs.docker.com/)
- [Docker Compose file reference](https://docs.docker.com/compose/compose-file/)
- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [WordPress `wp-cli` handbook](https://make.wordpress.org/cli/handbook/)


### AI usage

An AI assistant (Claude) was used during this project as a documentation and review tool, not to
generate the infrastructure logic itself:

- Reviewing the Dockerfiles, `nginx.conf` and the shell entrypoint scripts (`init.sh`,
  `setup.sh`) for mistakes and for alignment with the subject's constraints (single entry point,
  no `latest` tag, foreground process, etc.).
- Drafting and structuring the project documentation (`DEV_DOC.md`, `USER_DOC.md` and this
  `README.md`), based on the actual configuration already present in the repository.
- Explaining and comparing the underlying concepts documented in the "Project Description"
  section above (VMs vs containers, Docker secrets vs environment variables, bridge vs host
  networking, named volumes vs bind mounts).
