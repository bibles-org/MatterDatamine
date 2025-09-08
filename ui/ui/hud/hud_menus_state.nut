import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { nestWatched } = require("%dngscripts/globalState.nut")
let { EventGameTrigger, broadcastNetEvent,
      CmdShowUiMenu, CmdToggleUiMenu,
      CmdHideUiMenu, CmdHideAllUiMenus,
      EventEntityDied } = require("dasevents")
let { removeInteractiveElement, addInteractiveElement, freeInteractiveState } = require("%ui/hud/state/interactive_state.nut")
let { sound_play } = require("%dngscripts/sound_system.nut")
let { eventbus_subscribe } = require("eventbus")
let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")

function convertMenuId(id){
  let submenus = []
  if (type(id)=="string" && id.len()>0 && id.contains("/")) {
    let idpath = id.split("/")
    id = idpath[0]
    submenus.replace(idpath.slice(1))
  }
  return [id, submenus]
}

let currentMenuId = nestWatched("currentMenuId", null)
let curentHudMenusIds = nestWatched("curentHudMenusIds", {}) 
let curentHudMenus = {}

let areHudMenusOpened = Computed(function() {
  if (currentMenuId.get() == null)
    return false
  let [id, _] = convertMenuId(currentMenuId.get())
  return id in curentHudMenusIds.get()
})

local prev_id = null
currentMenuId.subscribe(function(v) {
  if (v==null && prev_id!=null)
    freeInteractiveState()
  prev_id = v
})

function replaceCurrentHudMenus(menus) {
  let newMenus = menus.map(@(_, key) key)
  if (!isEqual(curentHudMenusIds.get(), newMenus))
    curentHudMenusIds.set(newMenus) 
  curentHudMenus.clear()
  curentHudMenus.__update(menus)
}

let isCurrentMenuInteractive = Computed(function(){
  if (!areHudMenusOpened.get())
    return false
  let id = convertMenuId(currentMenuId.get())[0]
  return curentHudMenus?[id]?.isInteractive ?? true

})

function closeMenu(sid, sound=true){
  let id = convertMenuId(sid)[0]
  removeInteractiveElement(id)
  if (currentMenuId.get() == id || currentMenuId.get()==sid)
    log($"HudMenus: Close {sid}")
  else
    return
  let menu = curentHudMenus?[id]
  menu?.onClose()
  currentMenuId.set(null)
  if (sound)
    sound_play(menu?.openSound ?? "ui_sounds/interface_close")
}

function closeAllMenus(sound=true) {
  log($"HudMenus: Request close all menus")
  let id = currentMenuId.get()
  if (id != null)
    closeMenu(id, sound)
}

function openMenu(sid, sound=true, interactive=null){
  let [id, submenus] = convertMenuId(sid)
  let menu = curentHudMenus?[id]
  log($"HudMenus: request open {id}")
  if (menu==null) {
    currentMenuId.set(null)
    log($"HudMenus: {id} not found")
    return
  }
  if (currentMenuId.get() == sid) {
    log($"HudMenus: Already opened {id}")
    return
  }
  closeMenu(currentMenuId.get(), false)
  if ((submenus.len() > 0) && ((menu?.onOpen.getfuncinfos()?.parameters.len() ?? 0) > 1)) {
    menu?.onOpen(submenus)
    let subid = $"{id}/{submenus[0]}"
    currentMenuId.set(subid)
  }
  else{
    menu?.onOpen()
    currentMenuId.set(id)
  }
  if (interactive)
    addInteractiveElement(id)
  log($"HudMenus: Open {currentMenuId.get()}")
  if (menu?.onOpenTriggerHash != null) {
    broadcastNetEvent(EventGameTrigger({
      source=ecs.INVALID_ENTITY_ID,
      triggerHash=menu.onOpenTriggerHash,
      target=controlledHeroEid.get()
    }))
  }
  if (sound)
    sound_play(menu?.closeSound ?? "ui_sounds/interface_open")
}

function openMenuInteractive(sid, sound=true){
  openMenu(sid, sound, true)
}
eventbus_subscribe("hud_menus.open", @(v) openMenu(v.id, v?.sound ?? true))
eventbus_subscribe("hud_menus.close", @(v) closeMenu(v.id, v?.sound ?? true))

function toggleMenu(id, sound=true){
  let menu = curentHudMenus?[id]
  if (menu == null)
    return
  if (currentMenuId.get()!=id){
    openMenu(id, sound)
  }
  else
    closeMenu(id, sound)
}

ecs.register_es("hud_menus",
  {
    [CmdShowUiMenu] = @(evt, _eid, _comp) openMenu(evt.menuName),
    [CmdToggleUiMenu] = @(evt, _eid, _comp) toggleMenu(evt.menuName),
    [CmdHideUiMenu] = @(evt, _eid, _comp) closeMenu(evt.menuName),
    [CmdHideAllUiMenus] = @(...) closeAllMenus(),
  }
  {}
  {tags = "gameClient"}
)

ecs.register_es("close_menus_on_watched_death",
  {
    [EventEntityDied] = @(...) closeAllMenus()
  },
  {
    comps_rq = ["watchedByPlr"]
  },
  {tags = "gameClient"}
)

return {
  currentMenuId
  curentHudMenusIds
  replaceCurrentHudMenus
  closeMenu
  closeAllMenus
  openMenu
  openMenuInteractive
  toggleMenu
  areHudMenusOpened
  isCurrentMenuInteractive
  convertMenuId
}
