package workloads

import (
	"encoding/json"
	schemas "github.com/bcachet/cuefig/schemas:schemas"
)

workloads: schemas.#Workloads & {
	redis: schemas.#Workload & {
		expose: {
			ports: service: {containerPort: 6379}
		}
		container: {
			registry: "docker.io"
			name:     "redis"
		}
		secrets: creds: schemas.#SecretFile & {
			name:   "redis/password"
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
