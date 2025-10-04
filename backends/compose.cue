package backends

import (
	"list"
	"path"
	compose "cue.dev/x/dockercompose@v0"
	"github.com/bcachet/cuefig/workloads"
)

composefile: compose.#Schema & {
	services: {
		for k, deployment in workloads.workloads {
			"\(k)": {
				image: "\(deployment.container.registry)/\(deployment.container.name):\(deployment.container.tag)"
				ports: [for port in deployment.expose.ports {
					if port.exposedPort != _|_ {
						"\(port.exposedPort):\(port.containerPort)"
					}
					if port.exposedPort == _|_ {
						"\(port.containerPort)"
					}
				}]
				volumes: list.Concat([
					[for path, volume in deployment.volumes if volume.type == "hostPath" {
						type: "bind"
						source: volume.source
						target: volume.mount
					}],
					[for kv, volume in deployment.volumes if volume.type == "emptyDir" {
						type: "volume"
						source: "\(k)-\(kv)"
						target: volume.mount
					}],
					[for kc, config in deployment.configs {
						type: "bind"
						source: ".generated/\(k)-\(kc)/\(path.Base(config.mount))"
						target: config.mount
					}]
				])
                depends_on: [for kw, workload in workloads.workloads if list.Contains(deployment.deps, workload) {
                    kw
                }]
			}
		}
	}
	volumes: {
		for k, deployment in workloads.workloads {
			for kv, volume in deployment.volumes if volume.type == "emptyDir" {
				"\(k)-\(kv)": {}
			}
		}
	}
}
