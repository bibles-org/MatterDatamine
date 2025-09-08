let {nestWatched} = require("%dngscripts/globalState.nut")

let soundOutputDevicesList = nestWatched("soundOutputDevicesList", [])
let soundOutputDevicesListUpdate = @(v) soundOutputDevicesList.set(v)
let soundRecordDevicesList = nestWatched("soundRecordDevicesList", [])
let soundRecordDevicesListUpdate = @(v) soundRecordDevicesList.set(v)
let soundOutputDevice = nestWatched("soundOutputDevice")
let soundOutputDeviceUpdate = @(v) soundOutputDevice.set(v)
let soundRecordDevice = nestWatched("soundRecordDevice")
let soundRecordDeviceUpdate = @(v) soundRecordDevice.set(v)

return {
  soundOutputDevicesList, soundOutputDevicesListUpdate,
  soundRecordDevicesList, soundRecordDevicesListUpdate,
  soundOutputDevice, soundOutputDeviceUpdate,
  soundRecordDevice, soundRecordDeviceUpdate
}
