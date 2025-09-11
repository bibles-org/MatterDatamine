from "%dngscripts/sound_system.nut" import sound_set_callbacks, sound_get_output_devices, sound_get_record_devices, sound_set_output_device

from "%sqstd/string.nut" import startsWith

from "%ui/sound_state.nut" import soundOutputDeviceUpdate, soundOutputDevicesListUpdate, soundRecordDeviceUpdate, soundRecordDevicesListUpdate

from "settings" import get_setting_by_blk_path

from "%ui/ui_library.nut" import *

let { soundOutputDevice, soundOutputDevicesList, soundRecordDevice, soundRecordDevicesList } = require("%ui/sound_state.nut")


function findBestOutputDevice(devs_list) {
  return devs_list?[0] 
}

function findBestRecordDevice(devs_list) {
  let filterfunc = function(d) {
    
    
    return !startsWith(d.name, "Monitor of") 
  }
  let suitable = devs_list.filter(filterfunc)
  return suitable?[0] ?? devs_list?[0]
}

function get_output_devices() {
  let sysDevs = sound_get_output_devices()
  if (sysDevs.len() > 0)
    return sysDevs
  return [{
    name = "No Output"
    id = -1
  }]
}

function get_record_devices() {
  let sysDevs = sound_get_record_devices()
  if (sysDevs.len() > 0)
    return sysDevs
  return [{
    name = "No Record"
    id = -1
  }]
}


if (soundOutputDevicesList.get().len() == 0)
  soundOutputDevicesListUpdate(get_output_devices())

if (soundRecordDevicesList.get().len() == 0)
  soundRecordDevicesListUpdate(get_record_devices())


function isDeviceInList(dev, devs_list) {
  if (dev == null)
    return false
  foreach (d in devs_list)
    if (d.name == dev?.name && d.id == dev?.id)
      return true
  return false
}

soundOutputDevice.subscribe(function(dev) {
  log($"[sound] set output device {dev?.name}")
  sound_set_output_device(dev ? dev.id: 0)
})

soundRecordDevice.subscribe(function(dev) {
  log($"[sound] set record device {dev?.name}")
})

soundOutputDevicesList.subscribe(function(dlist) {
  log(dlist)
})

soundRecordDevicesList.subscribe(function(dlist) {
  log(dlist)
})

if (soundOutputDevice.get() == null) {
  local dev = get_setting_by_blk_path("sound/output_device")
  if (!isDeviceInList(dev, soundOutputDevicesList.get()))
    dev = findBestOutputDevice(soundOutputDevicesList.get())
  soundOutputDeviceUpdate(dev)

}

if (soundRecordDevice.get() == null) {
  local dev = get_setting_by_blk_path("sound/record_device")
  if (!isDeviceInList(dev, soundRecordDevicesList.get()))
    dev = findBestRecordDevice(soundRecordDevicesList.get())
  soundRecordDeviceUpdate(dev)
}

sound_set_callbacks({
  function on_record_devices_list_changed() {
    soundRecordDevicesListUpdate(get_record_devices())
    if (!isDeviceInList(soundRecordDevice.get(), soundRecordDevicesList.get()))
      soundRecordDeviceUpdate(findBestRecordDevice(soundRecordDevicesList.get()))
  }

  function on_output_devices_list_changed() {
    soundOutputDevicesListUpdate(get_output_devices())
    if (!isDeviceInList(soundOutputDevice.get(), soundOutputDevicesList.get()))
      soundOutputDeviceUpdate(findBestOutputDevice(soundOutputDevicesList.get()))
  }
})
