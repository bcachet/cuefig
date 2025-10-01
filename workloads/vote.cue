package workloads

import (
    "github.com/bcachet/cuefig/schemas"
)

workloads: schemas.#Workloads & {
    vote: schemas.#Workload & {
        expose: {
            ports: service: {containerPort: 5000}
        }
        container: {
            registry: "docker.io"
            name:     "voting/vote"
        }
        deps: [workloads.redis]
        volumes: tmp: schemas.#VolumeDir & {
            mount: "/tmp"
        }
    }
}
