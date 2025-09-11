from "%dngscripts/globalState.nut" import nestWatched
from "%dngscripts/sound_system.nut" import sound_play
from "dasevents" import EventGameTrigger, broadcastNetEvent, CmdShowUiMenu, CmdToggleUiMenu,
  CmdHideUiMenu, CmdHideAllUiMenus, EventEntityDied
from "%ui/hud/state/interactive_state.nut" import removeInteractiveElement, addInteractiveElement, freeInteractiveState
from "eventbus" import eventbus_subscribe
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


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
function setCurrentMenuId(id) {















  currentMenuId.set(id)
}
currentMenuId.whiteListMutatorClosure(setCurrentMenuId)
let curentHudMenusIds = nestWatched("curentHudMenusIds", {}) 
let curentHudMenus = {}

let areHudMenusOpened = Computed(function() {
  if (currentMenuId.get() == null)
    return false
  let [id, _] = convertMenuId(currentMenuId.get())
  return id in curentHudMenusIds.get()
})

local prev_id = null
currentMenuId.subscribe_with_nasty_disregard_of_frp_update(function(v) {
  if (v==null && prev_id!=null)
    freeInteractiveState()
  prev_id = v
})

let use = @(...) null

let isCurrentMenuInteractive = Computed(function(){
  if (!areHudMenusOpened.get())
    return false
  let id = convertMenuId(currentMenuId.get())[0]
  use(curentHudMenusIds.get())
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
  setCurrentMenuId(null)
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
    setCurrentMenuId(null)
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
    setCurrentMenuId(subid)
  }
  else{
    menu?.onOpen()
    setCurrentMenuId(id)
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

function replaceCurrentHudMenus(menus) {
  let newMenus = menus.map(@(_, key) key)
  let menusUpdated = !isEqual(curentHudMenusIds.get(), newMenus)
  curentHudMenus.clear()
  curentHudMenus.__update(menus)
  if (menusUpdated) {
    curentHudMenusIds.set(newMenus) 
  }
  if (menusUpdated)
    closeAllMenus(false)
}

return {
  currentMenuId
  setCurrentMenuId
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
