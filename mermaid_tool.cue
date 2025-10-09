package tools

import (
	"tool/cli"
	"github.com/bcachet/cuefig/backends"
)

command: mermaid: {
	print: cli.Print & {
		text: backends.mermaid.output
	}
}
