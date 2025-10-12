package backends

import (
	"path"
	"list"
	"strings"
	"encoding/yaml"
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

// Helper to check if workload has dependencies with certs
_workloadHasDepsWithCerts: {
	for k, deployment in workloads.workloads {
		"\(k)": len([for dep in deployment.deps
			if dep.expose.certs != _|_ && len(dep.expose.certs) > 0 {
				true
			}]) > 0
	}
}

// Helper to check if workload has its own certs
_workloadHasOwnCerts: {
	for k, deployment in workloads.workloads {
		"\(k)": len([if deployment.expose.certs != _|_ {
			if len(deployment.expose.certs) > 0 {
				true
			}
		}]) > 0
	}
}

manifests: {

	// Generate ConfigMaps for workload configs
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

	// Generate SecretProviderClass for workload secrets and dependency CA certificates
	for k, deployment in workloads.workloads {
		let hasSecrets = len(deployment.secrets) > 0
		let hasDepsWithCerts = _workloadHasDepsWithCerts[k]
		let hasOwnCerts = _workloadHasOwnCerts[k]

		if hasSecrets || hasDepsWithCerts || hasOwnCerts {
			"secret-provider-class_\(k)": schemas.#SecretProviderClass & {
				metadata: name: "\(k)-secrets"
				spec: {
					provider: "vault"
					parameters: {
						vaultAddress: vaultConfig.server
						roleName: vaultConfig.auth.kubernetes.role
						vaultKubernetesMountPath: vaultConfig.auth.kubernetes.mountPath

						// Build objects array for secrets and CA certs
						let secretObjects = [
							for ks, secret in deployment.secrets {
								objectName: "\(ks)"
								secretPath: "\(vaultConfig.path)/data/\(secret.path)"
								secretKey: "data"
							}
						]

						// Workload's own certificates (issued from PKI)
						// Note: CSI driver issues cert once and extracts different keys
						let ownCertObjects = list.FlattenN([
							if deployment.expose.certs != _|_ {
								if len(deployment.expose.certs) > 0 {
									[for certName, cert in deployment.expose.certs
									for part in [
										{key: "certificate", name: "cert"},
										{key: "private_key", name: "key"},
										{key: "issuing_ca", name: "ca"},
										{key: "ca_chain", name: "ca-chain"}
									] {
										objectName: "\(part.name)-\(certName)"
										secretPath: "\(cert.pki)/issue/\(k)-role"
										secretKey: part.key
										method: "PUT"
										secretArgs: {
											common_name: cert.commonName
											if cert.altNames != _|_ {
												alt_names: strings.Join(cert.altNames, ",")
											}
											if cert.ttl != _|_ {
												ttl: cert.ttl
											}
										}
									}]
								}
							}
						], 2)

						// Dependency CA certificates (read from PKI)
						let depCaObjects = list.FlattenN([
							for dep in deployment.deps
							if dep.expose.certs != _|_ && len(dep.expose.certs) > 0 {
								[for certName, cert in dep.expose.certs {
									objectName: "dep-ca-\(dep.name)-\(certName)"
									secretPath: "\(cert.pki)/cert/ca"
									secretKey: "certificate"
								}]
							}
						], 1)

						objects: yaml.Marshal(list.Concat([secretObjects, ownCertObjects, depCaObjects]))
					}

					// Sync env secrets to Kubernetes Secret objects for envFrom
					if len([for ks, secret in deployment.secrets if secret.type == "env" {secret}]) > 0 {
						secretObjects: [
							for ks, secret in deployment.secrets if secret.type == "env" {
								secretName: "\(k)-\(ks)"
								type: "Opaque"
								data: [{
									objectName: "\(ks)"
									key: "data"
								}]
							}
						]
					}
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
							// User-defined volumes
							if len(deployment.volumes) > 0 {
								[for kv, volume in deployment.volumes {
									name:      "\(k)-\(kv)"
									mountPath: volume.mount
								}]
							},
							// ConfigMap mounts
							if len(deployment.configs) > 0 {
								[for kc, config in deployment.configs {
									name:      "\(k)-\(kc)"
									mountPath: path.Dir(config.mount)
								}]
							},
							// CSI volume mounts for file secrets
							if len([for ks, secret in deployment.secrets if secret.type == "file" {secret}]) > 0 {
								[for ks, secret in deployment.secrets if secret.type == "file" {
									name:      "\(k)-csi-secrets"
									mountPath: path.Dir(secret.mount)
									subPath:   "\(ks)"
									readOnly:  true
								}]
							},
							// CSI volume mounts for workload's own certificates
							if _workloadHasOwnCerts[k] {
								[{
									name:      "\(k)-csi-secrets"
									mountPath: "/etc/certs"
									readOnly:  true
								}]
							},
							// CSI volume mounts for dependency CA certificates
							if _workloadHasDepsWithCerts[k] {
								[{
									name:      "\(k)-csi-secrets"
									mountPath: "/etc/ssl/certs/deps"
									readOnly:  true
								}]
							},
						])
						ports: [for port in deployment.expose.ports {
							containerPort: port.containerPort
						}]
						envFrom: [for ks, secret in deployment.secrets if secret.type == "env" {
							secretRef: name: "\(k)-\(ks)"
						}]
						// Generate probes from port definitions
						for probeType, probe in deployment.probes {
							"\(probeType)Probe": {
								if probe.type == "http" {
									httpGet: {
										path:   probe.path
										port:   probe.port
										scheme: probe.scheme | "HTTP"
										if probe.httpHeaders != _|_ {
											httpHeaders: probe.httpHeaders
										}
									}
								}
								if probe.type == "grpc" {
									grpc: {
										port: probe.port
										if probe.service != _|_ {
											service: probe.service
										}
									}
								}
								if probe.type == "tcp" {
									tcpSocket: {
										port: probe.port
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
						}]
					volumes: list.Concat([
						// User-defined volumes (emptyDir, hostPath)
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
						// ConfigMap volumes
						[for kc, config in deployment.configs {
							name: "\(k)-\(kc)"
							configMap: {
								name: "\(k)-\(kc)"
							}
						}],
						// CSI volume for secrets, own certs, and dependency CA certs
						if len(deployment.secrets) > 0 || _workloadHasDepsWithCerts[k] || _workloadHasOwnCerts[k] {
							[{
								name: "\(k)-csi-secrets"
								csi: {
									driver: "secrets-store.csi.k8s.io"
									readOnly: true
									volumeAttributes: {
										secretProviderClass: "\(k)-secrets"
									}
								}
							}]
						},
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
