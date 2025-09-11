from "%dngscripts/sound_system.nut" import sound_play

from "%sqstd/table.nut" import getValInTblPath as getByPath

from "dagor.time" import get_time_msec

from "%ui/ui_library.nut" import *


let equalIgnore = { ttl = true, key = true, num = true }
let countNotIgnoreKeys = @(event) event.keys().reduce(@(res, key) equalIgnore?[key] ? res + 1 : res, 0)

function isEventSame(event1, event2) {
  if (countNotIgnoreKeys(event1) != countNotIgnoreKeys(event2))
    return false
  foreach(key, value in event1)
    if (!equalIgnore?[key] && event2?[key] != value)
      return false
  return true
}

function speedUpRemoveSame(eventList, event, maxTime) {
  for (local i = eventList.len() - 1; i >= 0; i--) {
    let eventToRemove = eventList[i]
    if (isEventSame(eventToRemove, event)) {
      eventToRemove.ttl = min(eventToRemove.ttl, maxTime)
      break;
    }
  }
}

function playEventSound(event){
  if ("sound" in event)
    sound_play(event?.sound ?? "", event?.volume ?? 1)
}

let events = Watched([])
local idCounter = 0
let clearTime = 0.15
const defTtl = 5.0
const maxEvents = 3
const updateDt = 1.1
local timerSet = false

local update
update = function() {
  let ct = get_time_msec()
  let newEvents = events.get().filter(@(e) e.ctime + e.ttl * 1000 >= ct)
  let len = newEvents.len()
  if (len != events.get().len())
    events.set(newEvents)
  if (len == 0) {
    gui_scene.clearTimer(update)
    timerSet = false
  }
}

function pushPlayerEvent(eventSrc, collapseBy=null) {
  let key = ++idCounter
  let ev_ = events.get()
  let lastev  = ev_?[ev_.len()-1]
  let event = {
    ttl = eventSrc?.ttl ?? defTtl
    ctime = get_time_msec()
    key
    text = type(eventSrc)=="string" ? eventSrc : eventSrc?.text
    unique = type(eventSrc)=="string" ? eventSrc : eventSrc?.unique
  }
  local funcCollapseBy = null
  if (type(collapseBy)=="array"){
    funcCollapseBy = @(levt, evt) getByPath(levt, collapseBy) == getByPath(evt, collapseBy)
  }

  events.mutate(function(ev) {
    let unique = event?.unique
    if (unique != null)
      for (local idx = ev.len() - 1; idx >= 0; --idx) {
        if (ev[idx]?.unique == unique)
          ev.remove(idx)
      }
    if (funcCollapseBy == null || !funcCollapseBy(lastev, event) || ev.len() == 0) {
      if (clearTime >= 0)
        speedUpRemoveSame(ev, event, clearTime)
      ev.append(event)
      playEventSound(event)
    }
    else {
      let num = (lastev?.num != null) ? lastev.num+1 : 2
      event.num <- num
      event.key <- lastev?.key ?? key
      ev[ev.len()-1] = event
    }
    if (ev.len() > maxEvents)
      ev.remove(0)
  })
  if (!timerSet) {
    gui_scene.setInterval(updateDt, update)
    timerSet = true
  }
}

console_register_command(@(hotkey) pushPlayerEvent({
    event = {}, text = $"hotkey sample: {hotkey}", hotkey, unique = "tutorial", ttl = 10
  }), "ui.add_player_hotkey")

console_register_command(@() pushPlayerEvent({
    event = {}, text = $"block of hotkeys with two lines", unique = "tutorial", ttl = 10,
    hotkey = ["Vehicle.Steer", "Vehicle.Throttle", "Vehicle.Accel", "Vehicle.Brake", "Vehicle.HandBrake"]
  }), "ui.add_player_hotkeys_block")

console_register_command(@(text) pushPlayerEvent({
    event = {}, text = text ?? "sample event"
  }), "ui.add_player_event")

return {playerEvents = events, pushPlayerEvent}
