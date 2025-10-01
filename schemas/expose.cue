package schemas

// Define how workload is exposed
#Expose: {
	ports!: [string]: #Port
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
