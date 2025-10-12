# Cuefig

Let your users define their workloads with simple [CUE](https://cuelang.org/) schemas.

Hide complexity of your deployment platform by implementing wrappers around configuration definition, secrets/certificates retrieval, monitoring ... 

Key Features:

- **Single Source of Truth**: Define workloads once, deploy anywhere (thanks to dedicated backends)
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

- **Docker Compose**: Transforms workloads into `docker-compose.yaml`
- **Kubernetes**: Generates Deployments, ConfigMaps, ExternalSecrets, and SecretStore manifests
- **Mermaid**: Generates state diagrams showing workload dependencies


## Usage

### Generate Kubernetes Manifests

```bash
cue cmd kube
```

Apply to your cluster:
```bash
cue cmd kube | kubectl apply -f -
```

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


### Generate Dependency Diagram

```bash
cue cmd mermaid
```

This generates a Mermaid state diagram showing workload dependencies.

### Validate Configuration

Ensure data match specifications
```bash
cue vet ./...
```

Visualize specific manifest
```bash
cue export ./backends/kube.cue --out yaml -e manifests.service_redis
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

## Kubernetes

The Kubernetes backend behaviors:
- Automatically generates standard manifests (Deployments, ConfigMaps, Services, SecretProviderClass) from your workload definitions
- ConfigMaps are mounted as volumes
- Port exposure requires separate Service definitions (not generated)
- Secrets are synced from Vault via CSI driver
- Certificates are mounted via CSI driver from Vault PKI

 You can customize or extend these manifests using the `manifests` field (in the `backends` package).

### Adding Custom Manifests

You can add additional Kubernetes resources by defining them in the `manifests` field in [backends/kube.cue](backends/kube.cue):

```cue
manifests: {
    // Generated manifests (ConfigMaps, Deployments, etc.)
    // ...

    // Add a custom Ingress resource
    "ingress_myapp": networkingv1.#Ingress & {
        metadata: {
            name: "myapp-ingress"
            annotations: {
                "nginx.ingress.kubernetes.io/rewrite-target": "/"
            }
        }
        spec: {
            rules: [{
                host: "myapp.example.com"
                http: paths: [{
                    path: "/"
                    pathType: "Prefix"
                    backend: service: {
                        name: "myapp"
                        port: number: 80
                    }
                }]
            }]
        }
    }
}
```

### Replacing Generated Manifests

You can override any generated manifest by using the same key. For example, to customize the Service for a workload:

```cue
manifests: {
    // This replaces the auto-generated LoadBalancer service for "myapp"
    "service_myapp": corev1.#Service & {
        metadata: {
            name: "myapp"
            labels: app: "myapp"
            annotations: {
                "service.beta.kubernetes.io/aws-load-balancer-type": "nlb"
            }
        }
        spec: {
            type: "ClusterIP"  // Change from LoadBalancer to ClusterIP
            selector: app: "myapp"
            ports: [{
                name:       "http"
                port:       80
                targetPort: 8080
            }]
        }
    }
}
```

### Manifest Key Conventions

Generated manifests follow these naming conventions:
- `config-map_<workload>_<configname>`: ConfigMap resources
- `secret-provider-class_<workload>`: SecretProviderClass resources
- `deployment_<workload>`: Deployment resources
- `service_<workload>`: Service resources

Use these keys to replace generated manifests or create new ones with custom keys.

## Docker Compose

Behaviors:
- Writes ConfigMaps to `.generated/` directory to mount it in a volume

