package tools

import (
	"list"
	"encoding/yaml"
	"tool/cli"
	"github.com/bcachet/cuefig/backends"
)

command: kube: {
	print: cli.Print & {
		text: yaml.Marshal({
			kind:       "List"
			apiVersion: "v1"
			items: list.FlattenN([for _, wl in backends.manifests {
				list.Concat([
					[for _, m in wl.deployments {m}],
					[for _, m in wl.configmaps {m}],
					[for _, m in wl.secrets {m}],
					[for _, m in wl.services {m}],
				])
			}], 1)
		})
	}
}
