package backends

import (
	"path"
	"list"
	appsv1 "cue.dev/x/k8s.io/api/apps/v1@v0"
	corev1 "cue.dev/x/k8s.io/api/core/v1@v0"
	"github.com/bcachet/cuefig/workloads"
	"github.com/bcachet/cuefig/schemas"
)

// Vault configuration (can be overridden)
vaultConfig: {
	server:  string | *"https://vault.default.svc.cluster.local:8200"
	path:    string | *"secret"
	version: string | *"v2"
	auth: {
		kubernetes: {
			mountPath: string | *"kubernetes"
			role:      string | *"default"
		}
	}
}

manifests: {
	kind: "List"
	apiVersion: "v1"
	items: [
		// Generate SecretStore for Vault backend
		schemas.#SecretStore & {
			metadata: {
				name: "vault-backend"
			}
			spec: {
				provider: {
					vault: {
						server:  vaultConfig.server
						path:    vaultConfig.path
						version: vaultConfig.version
						auth:    vaultConfig.auth
					}
				}
			}
		},

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

	for k, deployment in workloads.workloads if len(deployment["secrets"]) > 0 {
		for ks, secret in deployment.secrets {
			schemas.#ExternalSecret & {
				metadata: {
					name: "\(k)-\(ks)"
				}
				spec: {
					secretStoreRef: {
						name: "vault-backend"
						kind: "SecretStore"
					}
					refreshInterval: "1h"
					target: {
						name:           "\(k)-\(ks)"
					}
					data: [
						{
							secretKey: "data"
							remoteRef: {
								key: secret.path
							}
						}
					]
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
								},
								if len(deployment.secrets) > 0 {
									[for ks, secret in deployment.secrets if secret.type == "file" {
										name:      "\(k)-\(ks)"
										mountPath: path.Dir(secret.mount)
									}]
								}])
							ports: [for port in deployment.expose.ports {
								containerPort: port.containerPort
							}]
							envFrom: [for ks, secret in deployment.secrets if secret.type == "env" {
								secretRef: name: "\(k)-\(ks)"
							}]
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
							[for ks, secret in deployment.secrets if secret.type == "file" {
								name: "\(k)-\(ks)"
								secret: {
									secretName: "\(k)-\(ks)"
								}
							}],
						])
					}
				}
			}
		}
	},

	// Generate LoadBalancer Services for workloads with exposed ports
	for k, deployment in workloads.workloads if len(deployment.expose.ports) > 0 {
		corev1.#Service & {
			metadata: {
				name: k
				labels: app: k
			}
			spec: {
				type: "LoadBalancer"
				selector: app: k
				ports: [for portName, portDef in deployment.expose.ports {
					let exposedPort = portDef.exposedPort | portDef.containerPort
					{
						name:       portName
						port:       exposedPort
						targetPort: portDef.containerPort
					}
				}]
			}
		}
	},
]
}
