package backends

import (
	"strings"
	"github.com/bcachet/cuefig/workloads"
)

// Generate Mermaid state diagram showing workload dependencies
mermaid: {
	let header = "stateDiagram-v2"

	// Generate state definitions (workload names)
	let states = strings.Join([for k, _ in workloads.workloads {k}], "\n    ")

	// Generate transitions (dependencies)
	let transitions = strings.Join([
		for k, deployment in workloads.workloads
		for dep in deployment.deps {
			"\(k) --> \(dep.name)"
		}
	], "\n    ")

	// Build complete diagram
	output: """
	\(header)
	    \(states)
	    \(transitions)
	"""
}
