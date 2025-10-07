package schemas

import (
	metav1 "cue.dev/x/k8s.io/apimachinery/pkg/apis/meta/v1@v0"
)


// Define Vault secret to be mounted (file)/injected (env var) into the workload
#Secret:
{
	path!:     string
	engine:    string | *"kv"
	type!:     "env" | "file"
	template?: string
	if type == "file" {
		mount!:  string
		mode?:   int | *0o400
	}
}

#SecretEnv: #Secret & {
	type: "env"
}

#SecretFile: #Secret & {
	type: "file"
}

// Our secrets are stored in Vault and retrieved
// via [_External Secrets Operator_](external-secrets.io)
// We are specifying shape of associated CRDs

#ExternalSecret: {
	apiVersion: "external-secrets.io/v1beta1"
	kind:       "ExternalSecret"
	metadata:   metav1.#ObjectMeta
	spec: {
		secretStoreRef: {
			name: string
			kind: string | *"SecretStore"
		}
		refreshInterval?: string
		target: {
			name:           string
			creationPolicy: string | *"Owner"
			template?: {
				type?: string
				engineVersion?: string
				data?: [string]: string
				metadata?: {
					annotations?: [string]: string
					labels?: [string]: string
				}
			}
		}
		data?: [...{
			secretKey: string
			remoteRef: {
				key:       string
				property?: string
			}
		}]
		dataFrom?: [...{
			extract?: {
				key: string
			}
		}]
	}
}

#SecretStore: {
	apiVersion: "external-secrets.io/v1beta1"
	kind:       "SecretStore"
	metadata:   metav1.#ObjectMeta
	spec: {
		provider: {
			vault: {
				server:  string
				path:    string
				version: string | *"v2"
				auth: {
					kubernetes?: {
						mountPath: string
						role:      string
					}
					tokenSecretRef?: {
						name: string
						key:  string
					}
				}
			}
		}
	}
}
