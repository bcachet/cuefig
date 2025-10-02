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
	protocol:       *"tcp" | "udp" | "grpc" | "http" | "https"
	containerPort!: int
	exposedPort?:   int | *containerPort
}

#Certificate: {
	pki?:  string
	ca?:   string
	cert?: string
	key?:  string
}
