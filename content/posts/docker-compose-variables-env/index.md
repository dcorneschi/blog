---
title: "Defining Variables in Docker Compose: Interpolation, environment, env_file and .env"
date: 2026-10-25T14:30:00+02:00
draft: false
description: "The two layers of Compose variables: ${VAR} interpolation from the shell and the project .env, and the container environment from environment, env_file and image ENV. Defaults, build args, precedence, secrets and debugging with docker compose config, with TZ as the running example."
tags: ["docker", "compose", "containers"]
categories: ["devops"]
---

Docker Compose has several ways to configure a service, and they operate at two distinct layers that are easy to confuse:

- **Interpolation** substitutes `${VAR}` inside the Compose file itself, before the file is parsed. Values come from your shell or the project `.env` file.
- **Container environment** sets variables inside the running container, using `environment` or `env_file`.

This guide walks through both layers using timezone (`TZ`) as the running example, then covers build arguments, precedence, and debugging. Every `docker compose config` result described here was checked with Docker Compose v5.6.1.

> **The most common mistake:** assuming the project `.env` file is passed into containers. It is not. `.env` feeds `${...}` interpolation in the Compose file. To put a value inside the container you must reference it under `environment`, or load a file with `env_file`.

[![Two layers: the shell and the project .env fill the ${...} placeholders in compose.yaml, the shell winning over .env; the container environment is built from docker compose run -e, environment, env_file and image ENV, highest first; build args exist only during the build unless promoted to ENV; .env itself never reaches the container](compose-variables-layers.svg)](compose-variables-layers.svg "Open the diagram full size")

## Methods Overview

| Method | Layer | Use for |
|--------|-------|---------|
| `environment` | Container | Runtime variables the app reads, such as `TZ` |
| `env_file` | Container | Loading many container variables from a file |
| Project `.env` | Interpolation | Filling `${...}` in the Compose file |
| `build.args` | Build time | Values needed while building the image |
| Compose variables | Interpolation | Image tag, ports, project name |

## Method 1: Container Environment Variables

`environment` sets variables inside the container. It accepts two equivalent forms.

List form:

```yaml
services:
  app:
    image: alpine:3.20
    environment:
      - TZ=America/New_York
      - LOG_LEVEL=debug
```

Map form:

```yaml
services:
  app:
    image: alpine:3.20
    environment:
      TZ: "America/New_York"
      LOG_LEVEL: "debug"
```

### With defaults from interpolation

`${TZ:-UTC}` is resolved by Compose before the container starts, using the shell or project `.env`. If `TZ` is unset or empty, the default `UTC` is used:

```yaml
services:
  app:
    image: alpine:3.20
    environment:
      - TZ=${TZ:-UTC}
      - NODE_ENV=${NODE_ENV:-production}
      - PORT=${PORT:-3000}
```

Interpolation default forms:

| Form | Behavior |
|------|----------|
| `${VAR}` | Value of `VAR`, or empty if unset |
| `${VAR:-default}` | `default` if `VAR` is unset **or empty** |
| `${VAR-default}` | `default` only if `VAR` is **unset** |
| `${VAR:?error}` | Fail with `error` if `VAR` is unset or empty |

### Passing a variable through from the shell

Listing a key with no value passes it from the environment Compose was run in:

```yaml
services:
  app:
    image: alpine:3.20
    environment:
      - TZ          # inherits TZ from the shell/.env, if set
```

## Method 2: The Project .env File

Compose automatically reads a file named `.env` in the project directory and uses it for `${...}` interpolation. This is interpolation only; it does not inject variables into containers by itself.

```env
# .env (same directory as the compose file)
TZ=Europe/London
IMAGE_TAG=1.27.1
APP_PORT=8080
```

```yaml
services:
  app:
    image: nginx:${IMAGE_TAG}
    ports:
      - "${APP_PORT}:80"
    environment:
      - TZ=${TZ}          # .env value reaches the container only via this line
```

Without the `TZ=${TZ}` line under `environment`, the container would not receive `TZ` even though it is defined in `.env`. `docker compose config` shows it: a service without the line has no `environment` key at all, while one with it shows `TZ: Europe/London`.

## Method 3: Loading Container Variables from a File with env_file

`env_file` loads variables directly into the container, without needing a matching `environment` line for each one. This is the file-based counterpart to `environment`.

```env
# app.env
TZ=Asia/Tokyo
LOG_LEVEL=debug
DATABASE_URL=postgres://localhost/app
```

```yaml
services:
  app:
    image: alpine:3.20
    env_file:
      - app.env
      - secrets.env
```

`env_file` differs from the project `.env`:

| Aspect | Project `.env` | `env_file` |
|--------|----------------|------------|
| Purpose | Interpolation in the Compose file | Variables inside the container |
| Loaded | Automatically, one file | Explicitly, one or more files |
| Reaches container | Only if referenced under `environment` | Directly |

When multiple `env_file` entries define the same key, later files win. Values set under `environment` override values from `env_file`.

```yaml
services:
  app:
    image: alpine:3.20
    env_file:
      - ./base.env         # loaded first
      - ./override.env     # overrides base.env
    environment:
      - TZ=UTC             # overrides both files for TZ
```

## Method 4: Build Arguments

Build arguments are available only while the image is built, not at runtime. Set runtime values separately with `environment`.

```yaml
services:
  app:
    build:
      context: .
      args:
        - TIMEZONE=${TZ:-UTC}
        - USER_ID=${DOCKER_UID:-1000}
    environment:
      - TZ=${TZ:-UTC}       # runtime timezone for the app
```

```dockerfile
# Dockerfile
FROM alpine:3.20
ARG TIMEZONE=UTC
RUN apk add --no-cache tzdata && \
    cp /usr/share/zoneinfo/$TIMEZONE /etc/localtime && \
    echo "$TIMEZONE" > /etc/timezone
ENV TZ=$TIMEZONE
```

A build `ARG` does not persist into the running container unless you promote it to an `ENV`, as shown with `ENV TZ=$TIMEZONE`.

## Method 5: Compose Configuration Variables

Interpolation also configures the Compose file itself: image tags, ports, and Compose's own settings such as `COMPOSE_PROJECT_NAME`.

```env
# .env
COMPOSE_PROJECT_NAME=myapp
IMAGE_TAG=1.0.0
APP_PORT=3000
TZ=Europe/Berlin
```

```yaml
services:
  app:
    image: myapp:${IMAGE_TAG}
    ports:
      - "${APP_PORT}:3000"
    environment:
      - TZ=${TZ}
```

## Timezone Example: Four Approaches

### A. Environment variable (recommended, most portable)

```yaml
services:
  gitlab-runner:
    image: gitlab/gitlab-runner:16.11.0
    environment:
      - TZ=${TZ:-UTC}
```

Most applications and language runtimes honor `TZ`. This requires the image to include the timezone database (`tzdata`); minimal images such as `alpine` may need it installed.

### B. Volume mount of host timezone files

```yaml
services:
  gitlab-runner:
    image: gitlab/gitlab-runner:16.11.0
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
```

This mirrors the host clock configuration into the container. Mount the files read-only. Note `/etc/timezone` is Debian-family specific and may not exist on all hosts, so mounting it can fail on non-Debian systems.

### C. Both (belt and suspenders)

```yaml
services:
  gitlab-runner:
    image: gitlab/gitlab-runner:16.11.0
    environment:
      - TZ=${TZ:-UTC}
    volumes:
      - /etc/localtime:/etc/localtime:ro
```

`TZ` covers applications that read the variable; the mount covers tools that read `/etc/localtime`.

### D. Host network mode

```yaml
services:
  gitlab-runner:
    image: gitlab/gitlab-runner:16.11.0
    network_mode: host
```

`network_mode: host` shares the host network namespace. It does not by itself set the timezone; still use `TZ` or the mount. Host networking has broad security and portability implications, so use it only when the workload genuinely needs it.

## Advanced Interpolation Patterns

Compose supports only a subset of Bash's operators (no replacement, case or substring), and a literal `$` must be written as `$$`.

### Compose nested defaults

```yaml
services:
  app:
    image: alpine:3.20
    environment:
      - DATABASE_URL=postgres://${DB_USER:-user}:${DB_PASS:-pass}@${DB_HOST:-localhost}:${DB_PORT:-5432}/${DB_NAME:-app}
```

### Profiles for environment-specific services

```yaml
services:
  app:
    image: alpine:3.20
    profiles: ["production"]
    environment:
      - TZ=UTC
      - LOG_LEVEL=warn

  app-dev:
    image: alpine:3.20
    profiles: ["development"]
    environment:
      - TZ=America/New_York
      - LOG_LEVEL=debug
```

Activate a profile with `docker compose --profile production up`. Profiles select which services run; Compose does not compute one variable's default from another variable's value, so keep conditional logic in the application or in the `.env` you choose.

## Precedence

When the same container variable is set in more than one place, Compose resolves it in this order (highest wins):

1. Values set in the shell and passed via `docker compose run -e` or the process environment for a passthrough key.
2. `environment` in the service.
3. `env_file` in the service (later files override earlier ones).
4. Image `ENV` defaults from the Dockerfile.

The project `.env` file does not appear here because it feeds interpolation, not the container environment directly.

## Handling Secrets

Keep sensitive values out of the committed Compose file and out of build arguments, since build args are visible in image history.

```yaml
services:
  app:
    image: alpine:3.20
    environment:
      - TZ=${TZ:-UTC}       # non-sensitive
    env_file:
      - secrets.env          # sensitive values, git-ignored
```

Add secret files to `.gitignore`. For stronger handling, use Docker secrets or an external secrets manager rather than plain environment variables.

## Debugging Variables

`docker compose config` renders the fully interpolated configuration, which is the fastest way to see what a `${...}` resolved to:

```bash
# Show the resolved, merged configuration
docker compose config

# Validate syntax quietly (non-zero exit on error)
docker compose config --quiet

# Inspect a service's resolved environment as JSON
docker compose config --format json | jq '.services.app.environment'
```

Check what actually reached a running container:

```bash
# Environment inside the container
docker compose exec app env | grep TZ

# Confirm the effective time and zone
docker compose exec app date
```

If `docker compose config` shows an empty value, the variable was unset during interpolation. If `config` shows the value but the container does not have it, you likely set it in the project `.env` without referencing it under `environment` or `env_file`.

## Real-World Example: GitLab Runner

```yaml
services:
  gitlab-runner:
    image: gitlab/gitlab-runner:16.11.0
    container_name: gitlab-runner
    restart: always
    environment:
      - TZ=${TZ:-UTC}
      - CI_SERVER_URL=${CI_SERVER_URL}
      - RUNNER_DEBUG=${RUNNER_DEBUG:-false}
    env_file:
      - .env.runner
    volumes:
      - ./config.toml:/etc/gitlab-runner/config.toml:ro
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock
```

This combines interpolation defaults (`${TZ:-UTC}`), a container variable file (`env_file`), and a read-only timezone mount. The top-level `version:` key is intentionally omitted; it is obsolete in current Compose and now only produces a warning.

## Quick Reference

```yaml
services:
  app:
    image: myapp:${IMAGE_TAG:-latest}      # interpolation from shell/.env
    environment:
      - TZ=${TZ:-UTC}                       # container variable with default
      - CI_SERVER_URL                       # passthrough from shell
    env_file:
      - app.env                             # bulk container variables
    build:
      args:
        - TIMEZONE=${TZ:-UTC}               # build-time only
```

```bash
# Resolve and inspect
docker compose config
docker compose config --format json | jq '.services.app.environment'

# Verify inside the container
docker compose exec app env | grep TZ
docker compose exec app date
```

## See Also

- [Docker Compose Cheatsheet]({{< ref "/cheatsheet/docker-compose" >}})
- [Docker Cheatsheet]({{< ref "/cheatsheet/docker-cheatsheet" >}})
- [How Docker Images Are Built: Layers, Cache and the Container on Top]({{< ref "/posts/docker-image-layers" >}}) (`ARG` vs `ENV` in the Dockerfile)
