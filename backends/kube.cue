package backends

import (
	"path"
	"list"
	appsv1 "cue.dev/x/k8s.io/api/apps/v1@v0"
	corev1 "cue.dev/x/k8s.io/api/core/v1@v0"
	"github.com/bcachet/cuefig/workloads"
)

manifests: {
	kind: "List"
	apiVersion: "v1"
	items: [
	for k, deployment in workloads.workloads if len(deployment["configs"]) > 0 {
		for kc, config in deployment.configs {
			corev1.#ConfigMap & {
				metadata: name: "\(k)-\(kc)"
				data: {
					"\(path.Base(config.mount, path.Unix))": config.data
				}
			}
		}
	},

	for k, deployment in workloads.workloads {
		appsv1.#Deployment & {
			metadata: {
				name: k
				labels: app: k
			}
			spec: {
				selector: matchLabels: app: k
				template: {
					metadata: labels: app: k
					spec: {
						containers: [{
							image: "\(deployment.container.registry)/\(deployment.container.name):\(deployment.container.tag)"
							name:  k
							volumeMounts: list.Concat([
								if len(deployment.volumes) > 0 {
									[for kv, volume in deployment.volumes {
										name:      "\(k)-\(kv)"
										mountPath: volume.mount
									}]
								},
								if len(deployment.configs) > 0 {
									[for kc, config in deployment.configs {
										name:      "\(k)-\(kc)"
										mountPath: path.Dir(config.mount)
									}]
								}])
							ports: [for port in deployment.expose.ports {
								containerPort: port.containerPort
							}]
							// for kp, probe in deployment.probes {
							// 	"\(kp)Probe": probe
							// }
							// envFrom: [for ks, secret in deployment.secrets if secret.type == "env" {
							// 	secretRef: name: "\(k)-\(ks)"
							// }]
						}]
						volumes: list.Concat([
							[for kv, volume in deployment.volumes {
								name: "\(k)-\(kv)"
								if volume.type == "emptyDir" {
									emptyDir: {}
								}
								if volume.type == "hostPath" {
									"path": volume.source
									if path.Dir(volume.source) == volume.source {
										type: "DirectoryOrCreate"
									}
									if path.Dir(volume.source) != volume.source {
										type: "FileOrCreate"
									}
								}
							}],
							[for kc, config in deployment.configs {
								name: "\(k)-\(kc)"
								configMap: {
									name: "\(k)-\(kc)"
								}
							}],
						])
					}
				}
			}
		}
	},
]
}
