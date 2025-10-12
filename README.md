# Cuefig

Use [CUE](https://cuelang.org/) to define your workloads.

Hide complexity of your Kubernetes platform to your users by implementing secrets/certificates/configuration retrieval or service/health-check definition through CUE.

As a bonus we can leverage those workloads to generate docker-compose environment for local development or dependecy graph via mermaid.


### Key Features

- **Single Source of Truth**: Define workloads once, deploy anywhere
- **Type Safety**: Leverage CUE's powerful type system for validation
- **Secret/Certificate Management**: Integrated Vault
- **Dependency Management**: Declare workload dependencies explicitly
- **Configuration as Code**: Version control your entire deployment configuration
- **Multiple Backend Support**: Generate configurations for Docker Compose and Kubernetes

## Core Concepts

### Workload

A workload is the fundamental unit that combines:
- **Container**: Image specification (registry, name, tag)
- **Expose**: Port mappings and TLS certificates
- **Configs**: Configuration files with inline data
- **Secrets**: Vault-backed secrets (environment variables or files)
- **Volumes**: Persistent or ephemeral storage mounts
- **Dependencies**: Explicit dependencies on other workloads
- **Probes**: Health check definitions (liveness, readiness, startup)

### Backend Generators

- **Docker Compose**: Transforms workloads into `docker-compose.yaml`, writes ConfigMaps to `.generated/` directory
- **Kubernetes**: Generates Deployments, ConfigMaps, ExternalSecrets, and SecretStore manifests
- **Mermaid**: Generates state diagrams showing workload dependencies

## Getting Started

### Prerequisites

- [CUE](https://cuelang.org/docs/install/) v0.14.1 or later
- Kubernetes cluster (for Kubernetes deployments)
- Vault with KV & PKI backends (for secrets and TLS certificates)
- Docker (for Compose deployments)

### Defining a Workload

Create a new file in [workloads/](workloads/) directory:

```cue
package workloads

import (
    schemas "github.com/bcachet/cuefig/schemas:schemas"
)

workloads: schemas.#Workloads & {
    myapp: schemas.#Workload & {
        container: {
            registry: "docker.io"
            name:     "myorg/myapp"
            tag:      "latest"
        }

        expose: {
            ports: "8080": {}
        }

        configs: appconfig: {
            mount: "/etc/myapp/config.json"
            data: """
                {
                    "setting": "value"
                }
                """
        }

        volumes: data: schemas.#VolumeDir & {
            mount: "/data"
        }

        probes: liveness: schemas.#ProbeTcp & {
            port: 8080
        }
    }
}
```

## Usage

### Generate Docker Compose Configuration

```bash
cue cmd compose
```

This command:
- Generates `docker-compose.yaml` to stdout
- Creates configuration files in `.generated/<workload>-<configname>/`

Deploy with Docker Compose:
```bash
cue cmd compose | docker compose -f - up -d
```

### Generate Kubernetes Manifests

```bash
cue cmd kube
```

Apply to your cluster:
```bash
cue cmd kube | kubectl apply -f -
```

### Generate Dependency Diagram

```bash
cue cmd mermaid
```

This generates a Mermaid state diagram showing workload dependencies.

### Validate Configuration

```bash
cue vet ./...
```

### Export Evaluated Data

```bash
# Export Docker Compose backend
cue export ./backends/compose.cue

# Export Kubernetes backend
cue export ./backends/kube.cue
```

## Configuration Guide

### Secrets

Secrets must use typed definitions:

**Environment Variable Secret:**
```cue
secrets: dbpassword: schemas.#SecretEnv & {
    path: "database/password"
}
```

**File-Based Secret:**
```cue
secrets: credentials: schemas.#SecretFile & {
    path:  "app/credentials"
    mount: "/run/secrets/credentials"
}
```

For Kubernetes deployments, secrets are retrieved from Vault using the CSI driver.

### Volumes

**Ephemeral Volume (emptyDir):**
```cue
volumes: tmp: schemas.#VolumeDir & {
    mount: "/tmp"
}
```

**Host Path Volume:**
```cue
volumes: hostdata: schemas.#VolumeBind & {
    source: "/host/path"
    mount:  "/container/path"
}
```

### TLS Certificates

Certificates are retrieved from Vault PKI backend:

```cue
expose: {
    ports: "443": {}
    certs: "tls": {
        pki:        "pki"
        commonName: "myapp.default.svc.cluster.local"
        altNames:   ["myapp", "localhost"]
        ttl:        "720h"
    }
}
```

### Dependencies

Declare explicit dependencies between workloads:

```cue
workloads: {
    webapp: schemas.#Workload & {
        // ...
        deps: [workloads.redis, workloads.postgres]
    }
}
```

### Health Probes

Define liveness, readiness, and startup probes:

**TCP Probe:**
```cue
probes: liveness: schemas.#ProbeTcp & {
    port: 6379
}
```

**HTTP Probe:**
```cue
probes: readiness: schemas.#ProbeHttp & {
    port: 8080
    path: "/health"
}
```

## Examples

See the example workloads in [workloads/](workloads/):

- [redis.cue](workloads/redis.cue): Redis with TLS, secrets, config files, and volumes
- [vote.cue](workloads/vote.cue): Voting app with Redis dependency

## Backend-Specific Behavior

### Kubernetes

- Generates Deployment, ConfigMap, and SecretStore resources
- ConfigMaps are mounted as volumes
- Port exposure requires separate Service definitions (not generated)
- Secrets are synced from Vault via CSI driver
- Certificates are mounted via CSI driver from Vault PKI

### Docker Compose

- Ports are mapped to host
- ConfigMaps are written to `.generated/` and bind-mounted
- Dependencies use `depends_on`
- Secrets are not currently handled