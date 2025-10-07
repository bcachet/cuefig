package schemas

#Workload: {
	name!:      string
	container!: #Container
	expose!:    #Expose
	probes:  [#ProbeType]:  #Probe
	configs: [string]: 		#Config
	secrets: [string]: 		#Secret
	volumes: [string]: 		#Volume
	envs:    [string]: 		string
	deps: [...#Workload]
}

#Workloads: [Name=string]: #Workload & {
	name: Name
}
