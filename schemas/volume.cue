package schemas

#Volume: {
    mount!: string
    type!: *"emptyDir" | "hostPath"
}

#VolumeDir: #Volume & {
    type: "emptyDir"
}

#VolumeBind: #Volume & {
    type: "hostPath"
    source!: string
}
