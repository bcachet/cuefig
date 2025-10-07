package schemas

#Volume: {
    mount!: string
    type!: "emptyDir" | "hostPath"
    if type == "hostPath" {
        source!: string
    }
}

#VolumeDir: #Volume & {
    type: "emptyDir"
}

#VolumeBind: #Volume & {
    type: "hostPath"
    
}
