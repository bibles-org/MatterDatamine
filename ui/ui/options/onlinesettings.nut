from "%sqstd/timers.nut" import throttle
import "%ui/state/shutdownHandler.nut" as shutdownHandler
from "eventbus" import eventbus_subscribe
from "%ui/ui_library.nut" import *
import "onlineStorage" as online_storage

let logOS = require("%sqGlob/library_logs.nut").with_prefix("[ONLINE_SETTINGS] ")
let userInfo = require("%sqGlob/userInfo.nut")

let onlineSettingUpdated = mkWatched(persist, "onlineSettingUpdated", false)
let onlineSettingsInited = mkWatched(persist, "onlineSettingsInited", false)
let settings = mkWatched(persist, "onlineSettings", online_storage.get_table_from_online_storage("GBT_GENERAL_SETTINGS"))

const SEND_PENDING_TIMEOUT_SEC = 600 

function onUpdateSettings(_userId) {
  let fromOnline = online_storage.get_table_from_online_storage("GBT_GENERAL_SETTINGS")
  settings.set(fromOnline)
  onlineSettingUpdated.set(true)
  onlineSettingsInited.set(true)
}

if (userInfo.get()?.chardToken!=null && userInfo.get()?.get()!=null && !onlineSettingsInited.get()){ 
  onUpdateSettings(userInfo.get()?.userId)
}

local isSendToSrvTimerStarted = false

function sendToServer() {
  if (!isSendToSrvTimerStarted)
    return 

  if (userInfo.get()==null || userInfo.get()?.chardToken==null || !onlineSettingsInited.get())
    return
  logOS("Send to server")
  gui_scene.clearTimer(callee())
  isSendToSrvTimerStarted = false
  online_storage.send_to_server()
}

function startSendToSrvTimer() {
  if (isSendToSrvTimerStarted) {
    logOS("Timer to send is already on")
    return
  }

  isSendToSrvTimerStarted = true
  logOS("Start timer to send")
  gui_scene.setTimeout(SEND_PENDING_TIMEOUT_SEC, sendToServer)
}

userInfo.subscribe(function (new_val) {
  if (new_val != null)
    return
  sendToServer()
  onlineSettingUpdated.set(false)
})

function save() {
  if (userInfo.get()==null || userInfo.get()?.chardToken==null || !onlineSettingsInited.get())
    return
  logOS("Save settings")
  online_storage.save_table_to_online_storage(settings.get(), "GBT_GENERAL_SETTINGS")
}

let lazySave = throttle(save, 10)

settings.subscribe(function(_new_val) {
  logOS("Queue setting to save")
  lazySave()
  startSendToSrvTimer()
})

function loadFromCloud(userId, cb) {
  online_storage.load_from_cloud(userId, cb)
}

eventbus_subscribe("onlineSettings.sendToServer", @(_) sendToServer())

shutdownHandler.add(function() {
  if (userInfo.get()==null || userInfo.get()?.chardToken==null || !onlineSettingsInited.get())
    return
  logOS("Save and send online settings on shutdown")
  save()
  online_storage.send_to_server()
})

console_register_command(@() settings.set({}), "online_settings.clear")

function changeSettingsWithPath(path, value){
  path = type(path)=="array" ? path : path.split("/")
  settings.mutate(function(v){
    local c = v
    foreach (i, subpath in path){
      if (i == path.len()-1) {
        c[path]<-value
        break
      }
      if (!path.blockExists(subpath))
        v.addBlock(subpath)
      c = v.getBlock(subpath)
    }
  })
}

return {
  onUpdateSettings
  onlineSettingUpdated
  settings
  loadFromCloud
  startSendToSrvTimer
  sendToServer
  changeSettingsWithPath
}
