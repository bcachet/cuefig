package tools

import (
	"encoding/yaml"
	"tool/cli"
    "github.com/bcachet/cuefig/backends"
)

command: kube: {
	print: cli.Print & {
		text: yaml.Marshal(backends.manifests)
	}
}
