# Docker Run GitHub Action

[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/Scalified/docker-run-action/blob/master/LICENSE)
[![Release](https://img.shields.io/github/v/release/Scalified/docker-run-action?style=flat-square)](https://github.com/Scalified/docker-run-action/releases/latest)

## Overview

A simple GitHub Action to execute `docker run` commands with customizable inputs

## Usage

```yaml
- name: Run Docker container
  uses: scalified/docker-run-action@v1
  with:
    args: --network host --restart unless-stopped
    command: echo "Hello World"
    detach: false
    entrypoint: ""
    env: >-
      NODE_ENV=production
      PORT=3000
    health-cmd: "curl -f http://localhost:3000/health || exit 1"
    health-interval: 30s
    health-retries: 3
    health-start-interval: 5s
    health-start-period: 10s
    health-timeout: 5s
    image: ubuntu:latest
    links: >-
      postgres
      redis:cache
    name: my-container
    privileged: false
    rm: true
    volumes: >-
      ./src:/app
      ./logs:/var/log:rw
      ./data:/data:ro
    workdir: /app
```

## Inputs

| Input                   | Description                                                                                          | Required | Default                   |
|-------------------------|------------------------------------------------------------------------------------------------------|----------|---------------------------|
| `args`                  | Additional docker run arguments                                                                      | No       | `""`                      |
| `command`               | Command to execute in the container                                                                  | No       | `""`                      |
| `detach`                | Run container in background                                                                          | No       | `false`                   |
| `entrypoint`            | Overwrite the default ENTRYPOINT of the image                                                        | No       | `""`                      |
| `env`                   | Set environment variables (space-separated KEY=VALUE pairs)                                          | No       | `""`                      |
| `health-cmd`            | Command to run to check health                                                                       | No       | `""`                      |
| `health-interval`       | Time between running the check (ms\|s\|m\|h)                                                         | No       | `5s`                      |
| `health-retries`        | Consecutive failures needed to report unhealthy                                                      | No       | `5`                       |
| `health-start-interval` | Time between running the check during the start period (ms\|s\|m\|h)                                 | No       | `0s`                      |
| `health-start-period`   | Start period for the container to initialize before starting health-retries countdown (ms\|s\|m\|h)  | No       | `0s`                      |
| `health-timeout`        | Maximum time to allow one check to run (ms\|s\|m\|h)                                                 | No       | `0s`                      |
| `image`                 | Docker image to run                                                                                  | Yes      |                           |
| `links`                 | Add link to another container (space-separated)                                                      | No       |                           |
| `name`                  | Assign a name to the container (uses the first 7 characters of the commit hash when no value is set) | No       |                           |
| `privileged`            | Give extended privileges to this container                                                           | No       | `false`                   |
| `volumes`               | Bind mount a volume (space-separated)                                                                | No       | `${{ github.workspace }}` |
| `workdir`               | Working directory inside the container                                                               | No       | `/workspace`              |

## Outputs

| Output           | Description                                                           |
|------------------|-----------------------------------------------------------------------|
| `container-id`   | ID of the created container (empty when running in foreground)        |
| `container-name` | Name of the created container                                         |
| `post-cmd`       | Post-execution command that shows container logs and performs cleanup |

---

**Made with ❤️ by [Scalified](http://www.scalified.com)**
