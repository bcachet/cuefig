package tools

import (
	"encoding/yaml"
	"tool/cli"
    "tool/file"
    "path"
    "github.com/bcachet/cuefig/workloads"
    "github.com/bcachet/cuefig/backends"
)

command: compose: {
    
    generateConfig: {
		for k, deployment in workloads.workloads {
			for kc, config in deployment.configs {
                mkdir: file.Mkdir & {
                    createParents: true
                    path: ".generated/\(k)-\(kc)/"
                }
				write: file.Create & {
                    $dep: mkdir.$done
                    filename: ".generated/\(k)-\(kc)/\(path.Base(config.mount))"
                    contents: config.data
                }
			}
		}
	}

	print: cli.Print & {
        $dep: generateConfig.$done
		text: yaml.Marshal(backends.composefile)
	}
}
