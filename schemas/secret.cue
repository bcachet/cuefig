package schemas


// Define Vault secret to be mounted (file)/injected (env var) into the workload
#Secret:
{
	name!:     string
	engine:    string | *"kv"
	type!:     "env" | "file"
	template?: string
}

#SecretEnv: #Secret & {
	type: "env"
}

#SecretFile: #Secret & {
	type: "file"
	mount!: string
	mode?:  int | *0o400
}