package backends

import (
	"text/template"
	"github.com/bcachet/cuefig/workloads"
)

// Generate Mermaid flowchart showing workload dependencies
mermaid: {
	// Prepare data for template
	let data = {
		dependencies: [
			for k, deployment in workloads.workloads
			for dep in deployment.deps {
				from: k
				to:   dep.name
			},
		]
	}

	// Template for Mermaid flowchart
	let tmpl = """
		flowchart TD
		{{- range .dependencies}}
		    {{.from}} --> {{.to}}
		{{- end}}
		"""

	// Execute template
	output: template.Execute(tmpl, data)
}
