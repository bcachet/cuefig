package tools

import (
	"encoding/yaml"
	"tool/cli"
    "github.com/bcachet/cuefig/backends"
)

command: kube: {
	print: cli.Print & {
		text: yaml.Marshal({
			kind: "List"
			apiVersion: "v1"
			items: [for _, manifest in backends.manifests {manifest}]
		})
	}
}
