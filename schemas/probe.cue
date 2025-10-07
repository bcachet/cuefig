package schemas

// Probe types available in Kubernetes
#ProbeType: "liveness" | "readiness" | "startup"

// Probe configuration for health checking
#Probe: {
	// Probe mechanism type
	type!: *"http" | "tcp" | "grpc" | "exec"

	// HTTP/HTTPS probe configuration
	if type == "http" {
		path!:   string
		scheme?: "HTTP" | "HTTPS" | *"HTTP"
		httpHeaders?: [...{
			name:  string
			value: string
		}]
	}

	// gRPC probe configuration
	if type == "grpc" {
		service?: string // gRPC service name (optional)
	}

	// Exec probe configuration
	if type == "exec" {
		command!: [...string] // Command to execute
	}

	// TCP probe has no additional config (just checks port connectivity)

	// Timing configuration (all optional with Kubernetes defaults)
	initialDelaySeconds?: int & >=0 // Default: 0
	periodSeconds?:       int & >=1 // Default: 10
	timeoutSeconds?:      int & >=1 // Default: 1
	successThreshold?:    int & >=1 // Default: 1
	failureThreshold?:    int & >=1 // Default: 3
}
