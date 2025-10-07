package workloads

import (
	"encoding/json"
	schemas "github.com/bcachet/cuefig/schemas:schemas"
)

workloads: schemas.#Workloads & {
	redis: schemas.#Workload & {
		expose: {
			ports: "6379": {
				probes: liveness: {
					path: "/healthz"
				}
			}
		}
		container: {
			registry: "docker.io"
			name:     "redis"
		}
		secrets: creds: schemas.#SecretFile & {
		  path:   "redis/password"
			mount:  "/run/secrets/redis_password"
		}
		configs: {
			config: {
				mount: "/etc/redis/redis.json"
				data: json.Marshal(
					{
						foo: "bar"
					})
			}
		}
	}
}
