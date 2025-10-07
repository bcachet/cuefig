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
	
	// Generate SecretStore for Vault backend
	"secret-store": schemas.#SecretStore & {
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
			"config-map_\(k)_\(kc)": corev1.#ConfigMap & {
				metadata: name: "\(k)-\(kc)"
				data: {
					"\(path.Base(config.mount, path.Unix))": config.data
				}
			}
		}
	},

for k, deployment in workloads.workloads if len(deployment["secrets"]) > 0 {
	for ks, secret in deployment.secrets {
		"external-secret_\(k)_\(ks)": schemas.#ExternalSecret & {
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
	"deployment_\(k)": appsv1.#Deployment & {
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

						// Generate probes from port definitions
						if len([for portName, portDef in deployment.expose.ports if portDef.probes != _|_ if portDef.probes["liveness"] != _|_ {portName}]) > 0 {
							livenessProbe: {
								// Find the first port with a liveness probe
								for portName, portDef in deployment.expose.ports if portDef.probes != _|_ if portDef.probes["liveness"] != _|_ {
									let probe = portDef.probes["liveness"]
									if probe.type == "http" {
										httpGet: {
											path:   probe.path
											port:   portDef.containerPort
											scheme: probe.scheme | "HTTP"
											if probe.httpHeaders != _|_ {
												httpHeaders: probe.httpHeaders
											}
										}
									}
									if probe.type == "grpc" {
										grpc: {
											port: portDef.containerPort
											if probe.service != _|_ {
												service: probe.service
											}
										}
									}
									if probe.type == "tcp" {
										tcpSocket: {
											port: portDef.containerPort
										}
									}
									if probe.type == "exec" {
										exec: {
											command: probe.command
										}
									}
									if probe.initialDelaySeconds != _|_ {
										initialDelaySeconds: probe.initialDelaySeconds
									}
									if probe.periodSeconds != _|_ {
										periodSeconds: probe.periodSeconds
									}
									if probe.timeoutSeconds != _|_ {
										timeoutSeconds: probe.timeoutSeconds
									}
									if probe.successThreshold != _|_ {
										successThreshold: probe.successThreshold
									}
									if probe.failureThreshold != _|_ {
										failureThreshold: probe.failureThreshold
									}
								}
							}
						}

						if len([for portName, portDef in deployment.expose.ports if portDef.probes != _|_ if portDef.probes["readiness"] != _|_ {portName}]) > 0 {
							readinessProbe: {
								for portName, portDef in deployment.expose.ports if portDef.probes != _|_ if portDef.probes["readiness"] != _|_ {
									let probe = portDef.probes["readiness"]
									if probe.type == "http" {
										httpGet: {
											path:   probe.path
											port:   portDef.containerPort
											scheme: probe.scheme | "HTTP"
											if probe.httpHeaders != _|_ {
												httpHeaders: probe.httpHeaders
											}
										}
									}
									if probe.type == "grpc" {
										grpc: {
											port: portDef.containerPort
											if probe.service != _|_ {
												service: probe.service
											}
										}
									}
									if probe.type == "tcp" {
										tcpSocket: {
											port: portDef.containerPort
										}
									}
									if probe.type == "exec" {
										exec: {
											command: probe.command
										}
									}
									if probe.initialDelaySeconds != _|_ {
										initialDelaySeconds: probe.initialDelaySeconds
									}
									if probe.periodSeconds != _|_ {
										periodSeconds: probe.periodSeconds
									}
									if probe.timeoutSeconds != _|_ {
										timeoutSeconds: probe.timeoutSeconds
									}
									if probe.successThreshold != _|_ {
										successThreshold: probe.successThreshold
									}
									if probe.failureThreshold != _|_ {
										failureThreshold: probe.failureThreshold
									}
								}
							}
						}

						if len([for portName, portDef in deployment.expose.ports if portDef.probes != _|_ if portDef.probes["startup"] != _|_ {portName}]) > 0 {
							startupProbe: {
								for portName, portDef in deployment.expose.ports if portDef.probes != _|_ if portDef.probes["startup"] != _|_ {
									let probe = portDef.probes["startup"]
									if probe.type == "http" {
										httpGet: {
											path:   probe.path
											port:   portDef.containerPort
											scheme: probe.scheme | "HTTP"
											if probe.httpHeaders != _|_ {
												httpHeaders: probe.httpHeaders
											}
										}
									}
									if probe.type == "grpc" {
										grpc: {
											port: portDef.containerPort
											if probe.service != _|_ {
												service: probe.service
											}
										}
									}
									if probe.type == "tcp" {
										tcpSocket: {
											port: portDef.containerPort
										}
									}
									if probe.type == "exec" {
										exec: {
											command: probe.command
										}
									}
									if probe.initialDelaySeconds != _|_ {
										initialDelaySeconds: probe.initialDelaySeconds
									}
									if probe.periodSeconds != _|_ {
										periodSeconds: probe.periodSeconds
									}
									if probe.timeoutSeconds != _|_ {
										timeoutSeconds: probe.timeoutSeconds
									}
									if probe.successThreshold != _|_ {
										successThreshold: probe.successThreshold
									}
									if probe.failureThreshold != _|_ {
										failureThreshold: probe.failureThreshold
									}
								}
							}
						}
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
	"service_\(k)": corev1.#Service & {
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
}
