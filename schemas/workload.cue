package schemas

#Workload: {
	container!: #Container
	expose!:    #Expose
	configs: [string]: #Config
	secrets: [string]: #Secret
	volumes: [string]: #Volume
	deps: [...#Workload]
}

#Workloads: [string]: #Workload
