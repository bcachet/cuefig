package workloads

import (
    schemas "github.com/bcachet/cuefig/schemas:schemas"
)

workloads: schemas.#Workloads & {
    vote: schemas.#Workload & {
        expose: {
            ports: "5000": {}
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
