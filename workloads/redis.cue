package workloads

import (
	"encoding/json"
	"github.com/bcachet/cuefig/schemas"
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
