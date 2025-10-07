package schemas

import (
  "strconv"
)

// Define how a Workload is exposed to others
#Expose: {
	ports!: [Port=string]: #Port & {
	  containerPort: strconv.Atoi(Port)
	}
	certs?: [string]: #Certificate
}

#Port: {
	// Port the application listens on inside the container
	containerPort!: int

	// External port to expose (defaults to containerPort if not specified)
	exposedPort?: int

	// Optional health check probes for this port
	// Keys must be one of: "liveness", "readiness", "startup"
	probes?: [#ProbeType]: #Probe
}

#Certificate: {
	// Vault PKI mount path (e.g., "pki" or "pki_int")
	pki: string | *"pki"

	// Common Name for the certificate
	commonName: string

	// Subject Alternative Names (SANs)
	altNames?: [...string]

	// Certificate TTL (e.g., "720h", "30d")
	ttl?: string
}
