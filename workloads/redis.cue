package workloads

import (
	"encoding/json"
	schemas "github.com/bcachet/cuefig/schemas:schemas"
)

workloads: schemas.#Workloads & {
	redis: schemas.#Workload & {
		container: {
			registry: "docker.io"
			name:     "redis"
		}

		expose: {
			ports: "6379": {}
			certs: "tls": {
				pki: "pki"
				commonName: "redis.default.svc.cluster.local"
				altNames: ["redis", "localhost"]
				ttl: "720h"
			}
		}

		secrets: creds: schemas.#SecretFile & {
			path:   "redis/password"
		  	mount:  "/run/secrets/redis_password"
		}

		configs: config: {
			mount: "/etc/redis/redis.json"
			data: json.Marshal(
				{
					foo: "bar"
				})
		}

		volumes: data: schemas.#VolumeDir & {
				mount: "/data"
			}

		probes: liveness: schemas.#ProbeTcp & {
			port: 6379
		}
	}
}
