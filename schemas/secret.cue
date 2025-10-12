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

// SecretProviderClass defines the schema for Secrets Store CSI Driver
// Used to retrieve secrets from Vault without storing them in etcd
#SecretProviderClass: {
	apiVersion: "secrets-store.csi.x-k8s.io/v1"
	kind:       "SecretProviderClass"
	metadata:   metav1.#ObjectMeta
	spec: {
		provider: string | *"vault"
		parameters?: {
			vaultAddress?: string
			vaultNamespace?: string
			roleName?: string
			vaultKubernetesMountPath?: string
			vaultCACertPath?: string
			vaultCADirectory?: string
			vaultSkipTLSVerify?: string
			// YAML string containing array of secret objects to fetch
			objects?: string
		}
		// Optional: sync secrets to Kubernetes Secret objects
		secretObjects?: [...{
			secretName: string
			type?: string | *"Opaque"
			data?: [...{
				objectName: string
				key: string
			}]
		}]
	}
}
