from "%ui/ui_library.nut" import *

from "%ui/components/uiHotkeysHint.nut" import mkHotkey
from "%ui/hud/tips/tipComponent.nut" import tipCmp
import "%ui/mainMenu/contacts/mkContactsButton.nut" as mkContactsButton
from "%ui/mainMenu/contacts/mkSquadWidget.nut" import squadWidget
import "%ui/mainMenu/mailboxButton.ui.nut" as mailboxButton
import "%ui/hud/state/notes.nut" as notesState


let { mkNotificationMark } = require("%ui/mainMenu/notificationMark.nut")
let { isSpectator } = require("%ui/hud/state/spectator_state.nut")
let { isInBattleState } = require("%ui/state/appState.nut")
let { safeAreaHorPadding, safeAreaVerPadding } = require("%ui/options/safeArea.nut")
let { playerBaseHudMenus, battleHudMenus, playerBaseHudMenuTabs, battleHudMenuTabs } = require("am_hud_menus.nut")
let { isBurning } = require("%ui/hud/state/burning_state_es.nut")
let { isAlive } = require("%ui/hud/state/health_state.nut")
let { showDebriefing } = require("%ui/mainMenu/debriefing/debriefingState.nut")
let { body_txt } = require("%ui/fonts_style.nut")
let { mkSmoothBWGradientY } = require("%ui/helpers/gradients.nut")
let { showCursor } = require("%ui/cursorState.nut")
let { HUD_TIPS_HOTKEY_FG, BtnBdSelected, BtnBdHover } = require("%ui/components/colors.nut")
let { isContactsVisible } = require("%ui/mainMenu/contacts/contactsListWnd.nut")
let { mkDropDownMenuBtn, mkDropDownMenu } = require("%ui/mainMenu/dropDownMenu.nut")
let { currencyPanel } = require("%ui/mainMenu/currencyPanel.nut")
let { profileWidget } = require("%ui/mainMenu/player_profile_widget.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let hideHud = require("%ui/hud/state/hide_hud.nut")
let { isNexus } = require("%ui/hud/state/nexus_mode_state.nut")
let { currentMenuId,
      convertMenuId,
      replaceCurrentHudMenus,
      openMenuInteractive,
      closeMenu,
      toggleMenu,
      areHudMenusOpened } = require("%ui/hud/hud_menus_state.nut")
let { BaseDebriefingMenuId } = require("%ui/mainMenu/baseDebriefing.nut")
let { isOnboarding, onboardingStateMachineCurrentStateEid, onboardingStateMachineBaseKeyInsertionStateEid } = require("%ui/hud/state/onboarding_state.nut")
let { inShootingRange } = require("%ui/hud/state/shooting_range_state.nut")


function mkMenuEventHandlers(menu) {
  let eventName = menu?.event
  if (eventName==null)
    return {}
  let holdToToggleDurMsec = menu?.holdToToggleDurMsec ?? 500
  function endEvent(event){
    if ((event?.dur ?? 0) > holdToToggleDurMsec || event?.appActive==false)
      closeMenu(menu.id)
  }
  return {
    [eventName] = @(_event) (menu?.isAvailable?.get() ?? true) ? toggleMenu(menu.id) : null,
    [$"{eventName}:end"] = endEvent
  }
}

let underline = freeze({rendObj = ROBJ_SOLID color = BtnBdSelected size = [flex(), hdpx(5)] vplace = ALIGN_BOTTOM})
let empty = freeze({size = [flex(), hdpx(5)] vplace = ALIGN_BOTTOM})
let prevUnderline = freeze({rendObj = ROBJ_SOLID color = BtnBdHover size = [flex(), hdpx(5)] vplace = ALIGN_BOTTOM})

let mkHotkeyComp = @(hotkey, action) mkHotkey(hotkey, action, { padding = [hdpx(8), hdpx(5), hdpx(15), hdpx(5)] })
let hotkeyPlaceholder = function(hotkey) {
  let size = calc_comp_size(mkHotkeyComp(hotkey, null))
  return {
    size
    rendObj = ROBJ_SOLID
    color = Color(0,0,0,0)
  }
}

let topBarHeight = hdpx(80)

let bgGradient = @(height) {
  rendObj = ROBJ_IMAGE
  size = flex()
  color = Color(0, 0, 0)
  image = mkSmoothBWGradientY({ height })
}


function mkMenu(menu, id){
  if ("getMenu" in menu)
    return menu.getMenu().__merge({id, isAvailable = menu?.isAvailable})
  return menu
}

let battleAvailable = Watched([])
let playerBaseAvailable = Watched([])

let updateBattleAvailable = @(...) battleAvailable.set(battleHudMenuTabs
  .filter(@(id) battleHudMenus?[id].isAvailable.get() ?? true)
)

let updatePlayerBaseAvailable = @(...) playerBaseAvailable.set(playerBaseHudMenuTabs
  .filter(@(id) playerBaseHudMenus?[id].isAvailable.get() ?? true)
)

battleAvailable.whiteListMutatorClosure(updateBattleAvailable)
playerBaseAvailable.whiteListMutatorClosure(updatePlayerBaseAvailable)

updateBattleAvailable()
updatePlayerBaseAvailable()

battleHudMenuTabs.each(function(id) {
  let isAvailable = battleHudMenus?[id]?.isAvailable
  if (isAvailable != null)
    isAvailable.subscribe(updateBattleAvailable)
})

playerBaseHudMenuTabs.each(function(id) {
  let isAvailable = playerBaseHudMenus?[id]?.isAvailable
  if (isAvailable != null)
    isAvailable.subscribe(updatePlayerBaseAvailable)
})

isInBattleState.subscribe(function(v) {
  if (!v && convertMenuId(currentMenuId.get())[0] != BaseDebriefingMenuId)
    closeMenu(currentMenuId.get())
})

inShootingRange.subscribe(@(_) closeMenu(currentMenuId.get()))

let lastTabId = Computed(function(prev) {
  let availableTabs = isInBattleState.get() || inShootingRange.get() ? battleAvailable : playerBaseAvailable
  let id = convertMenuId(currentMenuId.get())[0]
  return availableTabs.get().contains(id) ? id
       : availableTabs.get().contains(prev) ? prev
       : availableTabs.get()?[0]
})

function toggleTopBarMenu(){
  let id = currentMenuId.get()
  if (id != null)
    closeMenu(id)
  else
    openMenuInteractive(lastTabId.get())
}

function mkAllEventHandlers(menus) {
  let res = {}
  foreach (menu in menus) {
    if (menu?.event != null)
      res.__update(mkMenuEventHandlers(menu))
  }
  res["HUD.GameMenu:end"] <- @(_) toggleTopBarMenu()
  return res
}

let openMenuTip = tipCmp({
  inputId = "HUD.GameMenu"
  animations = []
  style = {
    rendObj = ROBJ_BOX
    padding = [hdpx(8), hdpx(5), hdpx(15), hdpx(5)]
    fillColor = Color(0,0,0,0)
  }
})

let openMenuTipSize = calc_comp_size(openMenuTip)

function menusUi() {
  let isInBattle = isInBattleState.get()
  let isInShootingRange = inShootingRange.get()
  let battleHud = isInBattle || isInShootingRange

  let availableTabs = battleHud ? battleAvailable : playerBaseAvailable

  function nextTab() {
    let curTab = convertMenuId(currentMenuId.get())[0]
    let idx = availableTabs.get().findindex(@(v) v==curTab)
    if (idx != null && availableTabs.get().len() != 0){
      let next = (idx + 1) % availableTabs.get().len()
      openMenuInteractive(availableTabs.get()[next])
    }
  }

  function prevTab() {
    let curTab = convertMenuId(currentMenuId.get())[0]
    let idx = availableTabs.get().findindex(@(v) v==curTab)
    if (idx != null && availableTabs.get().len() != 0){
      let prev = (idx - 1 + availableTabs.get().len()) % availableTabs.get().len()
      openMenuInteractive(availableTabs.get()[prev])
    }
  }


  let needMenu = !hideHud.get() && (isNexus.get() || isSpectator.get() || (!isBurning.get() && isAlive.get())) && !showDebriefing.get()

  replaceCurrentHudMenus(isInBattle ? battleHudMenus : playerBaseHudMenus) 
  let hudMenus = (!needMenu ? {} : battleHud ? battleHudMenus : playerBaseHudMenus).map(mkMenu)

  let hudMenuTabs = battleHud ? battleHudMenuTabs : playerBaseHudMenuTabs


  function mkSectionBtn(menuId) {
    let {name = null, notifications = null} = hudMenus[menuId]
    let text = name ?? loc(menuId)
    let stateFlags = Watched(0)
    let notificationsWatch = type(notifications) == "function" ? notifications() : notifications
    let cid = convertMenuId(currentMenuId.get())[0]
    let content = {
      flow = FLOW_HORIZONTAL
      children = [
        @() {
          text, watch = stateFlags
          rendObj = ROBJ_TEXT
          color = stateFlags.get() & S_HOVER ? Color(255,255,255,200) : Color(200,200,200,160)
          fontFxColor = Color(0, 0, 0, 70)
          fontFxFactor = min(64, hdpx(64))
          fontFx = FFT_GLOW
        }.__update(body_txt)
        notificationsWatch != null ? mkNotificationMark(notificationsWatch) : null
      ]
    }

    return function() {
      let isCurrent = cid == menuId
      let prevActive = lastTabId.get() == menuId

      return {
        watch = [notificationsWatch, lastTabId, currentMenuId, showCursor, inShootingRange, playerBaseAvailable, battleAvailable]
        behavior = showCursor.get() ? Behaviors.Button : null
        onClick = @() openMenuInteractive(menuId)
        flow = FLOW_VERTICAL
        gap = hdpx(5)
        skipDirPadNav = true
        onElemState = @(s) stateFlags.set(s)
        children = [
          content
          isCurrent
            ? underline
            : prevActive ? prevUnderline : empty
        ]
        sound = const {
          click  = "ui_sounds/menu_enter"
          hover  = "ui_sounds/menu_highlight"
        }
      }
    }
  }

  let topBarButtons = function() {
    let buttons = availableTabs.get().map(@(id) mkSectionBtn(id))

    let prevHotkey = showCursor.get() && !notesState.editMode.get() ? mkHotkeyComp("Q | J:LB", prevTab) : hotkeyPlaceholder("Q | J:LB")
    let nextHotkey = showCursor.get() && !notesState.editMode.get() ? mkHotkeyComp("E | J:RB", nextTab) : hotkeyPlaceholder("E | J:RB")

    let activateBtnRect = {r=hdpx(20), b=hdpx(20)}
    function onAttachActivateBtn(elem){
      let x = elem.getScreenPosX()
      let y = elem.getScreenPosY()
      let height = elem.getContentHeight()
      let width = elem.getWidth()
      activateBtnRect.__update({x, y, height, width,
        r = x + width,
        b = y + height
      })
    }

    function activateBtn(){
      return {
        onAttach = onAttachActivateBtn
        watch = areHudMenusOpened
        vplace = ALIGN_CENTER
        hotkeys = !areHudMenusOpened.get()
          ? null
          : [["J:Start", { action = @() mkDropDownMenu()({targetRect = activateBtnRect}) }]]
      }
    }

    let children = [!areHudMenusOpened.get() ? openMenuTip : const {size = openMenuTipSize}]
    if (buttons.len() != 0)
      if (buttons.len() > 1)
        children
          .append(prevHotkey)
          .extend(buttons)
          .append(nextHotkey)
      else if (buttons.len() == 1)
        children.extend(buttons)

    let serviceButtons = []
    if (!isInBattle){
      let contactsButton = mkContactsButton(@() isContactsVisible.set(true))
      serviceButtons.extend(
        isOnboarding.get() ? [] : [profileWidget]
        !isOnboarding.get() || onboardingStateMachineCurrentStateEid.get() == onboardingStateMachineBaseKeyInsertionStateEid.get() ? currencyPanel : []
        !isOnboarding.get() ? [mailboxButton, contactsButton] : []
      )
    }
    serviceButtons.append(mkDropDownMenuBtn(), activateBtn)
    children.append({size = flex()}).extend(serviceButtons)

    let cid = convertMenuId(currentMenuId.get())[0]
    let showTopBar = ( cid != null && hudMenuTabs.contains(cid)) || !isInBattle
    return {
      size = [flex(), SIZE_TO_CONTENT]
      gap = hdpx(12)
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      padding = [fsh(1), fsh(2)]
      watch = [currentMenuId, showCursor, isInBattleState, notesState.editMode, availableTabs, isOnboarding]
      children = showTopBar ? children : null
    }
  }

  let topBar = function() {
    let cid = convertMenuId(currentMenuId.get())[0]
    return {
      watch = [showCursor, currentMenuId, safeAreaVerPadding, safeAreaHorPadding]
      size = [flex(), topBarHeight + safeAreaVerPadding.get()]
      vplace = ALIGN_TOP
      children = [
        (cid != null && hudMenuTabs.contains(cid))
          ? bgGradient(topBarHeight + safeAreaVerPadding.get()) : null
        {
          size = [flex(), topBarHeight]
          padding = [safeAreaVerPadding.get(), safeAreaHorPadding.get()]
          children = topBarButtons
        }
      ]
    }
  }
  function squad(){
    return {
      children = squadWidget
      pos = [0, fsh(5)]
      padding = [0, fsh(3)]
      size = [flex(), SIZE_TO_CONTENT]
    }
  }
  let content = @() {
    size = flex()
    watch = currentMenuId
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = hudMenus?[convertMenuId(currentMenuId.get())[0]].getContent()
  }
  let inventoryTip = tipCmp({
    text = loc("controls/HUD.Inventory")
    inputId = "HUD.Inventory"
    textColor = HUD_TIPS_HOTKEY_FG
    style = const {
      rendObj=null
      vplace = ALIGN_BOTTOM
      padding = [sh(2), sh(5)]
    }
  })

  let showDropDownMenu = function() {
    mkDropDownMenu()({targetRect = {r=hdpx(20), b=hdpx(20)}})
  }

  return {
    watch = [isNexus, hideHud, isSpectator, isBurning, isAlive, isInBattleState, inShootingRange]
    size = flex()
    eventHandlers = needMenu ? mkAllEventHandlers(hudMenus) : null
    children = needMenu ? [
      @() {
        watch = [safeAreaVerPadding, safeAreaHorPadding]
        size = flex()
        padding = [safeAreaVerPadding.get(), safeAreaHorPadding.get()]
        children = [
          content
          squad
          !isInBattle && isGamepad.get() ? inventoryTip : null
        ]
      }
      topBar
    ] : {
      hotkeys = [["Esc | J:Start", {action = showDropDownMenu}]]
    }
  }
}

return {
  menusUi
}
