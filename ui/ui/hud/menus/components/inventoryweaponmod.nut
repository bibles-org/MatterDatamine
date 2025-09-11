from "%ui/hud/menus/components/inventoryItemUtils.nut" import mkCheckAmmoButton, mkStopCheckAmmoButton, mkItemCheckAmmoProgress, needShowQuickSlotPurchase,
  purchaseItemsToSlot, mkStopLoadUnloadAmmoButton

from "%ui/fonts_style.nut" import tiny_txt
from "%ui/hud/state/inventory_state.nut" import getSlotOpacity
from "%ui/components/cursors.nut" import setTooltip
import "%ui/hud/menus/components/dropMarker.nut" as dropMarker
from "%ui/hud/menus/components/moveMarker.nut" import moveMarker
from "%ui/components/colors.nut" import BtnBgHover, BtnBdFocused, ItemBgColor, BtnBdSelected, noItemContainerBg
from "%ui/hud/menus/components/inventoryItemTooltip.nut" import buildInventoryItemTooltip
from "%ui/hud/menus/components/inventoryStyle.nut" import itemHeight
from "%ui/hud/menus/components/inventoryItem.nut" import chargesIndicator, corruptedItemImageBackground
from "%ui/hud/state/item_info.nut" import get_equipped_magazine_current_ammo_count
from "%ui/components/chocolateWnd.nut" import openChocolateWnd
from "%dngscripts/sound_system.nut" import sound_play
import "%ui/components/faComp.nut" as faComp
from "%ui/components/mkDotPaginatorList.nut" import mkVertPaginatorList
from "%ui/components/commonComponents.nut" import mkText
from "%ui/mainMenu/market/inventoryToMarket.nut" import getItemPriceToShow, mkItemPrice
from "%ui/hud/state/entity_use_state.nut" import calcItemUseProgress
from "%ui/hud/menus/components/inventoryItemNexusPointPriceComp.nut" import nexusPointsCostComp
from "dagor.debug" import logerr

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { draggedData, focusedData, isAltPressed, mutationForbidenDueToInQueueState } = require("%ui/hud/state/inventory_state.nut")
let { isSpectator } = require("%ui/hud/state/spectator_state.nut")
let { entityToUse } = require("%ui/hud/state/entity_use_state.nut")
let { curTime } = require("%ui/hud/state/time_state.nut")
let { hoverPcHotkeysPresentation } = require("%ui/hud/menus/components/inventoryActionsHints.nut")
let { WEAPON_MOD } = require("%ui/hud/menus/components/slotTypes.nut")
let { hoverHotkeysWatchedList } = require("%ui/components/pcHoverHotkeyHitns.nut")
let { inventoryItemClickActions } = require("%ui/hud/menus/inventoryActions.nut")
let { mintEditState } = require("%ui/mainMenu/raid_preparation_window_state.nut")
let { previewPreset } = require("%ui/equipPresets/presetsState.nut")
let { weaponSlotsKeys } = require("%ui/types/weapon_slots.nut")
let { HERO_ITEM_CONTAINER } = require("%ui/hud/menus/components/inventoryItemTypes.nut")

let activeModsSlots = Watched({})
#allow-auto-freeze

let modFillDragColor = ItemBgColor
let modBorderColor = Color(30,30,30,5)
let defItemColor = Color(138, 138, 138)
const MAX_MODS_TO_SHOW = 3

function mkPriceBlock(mod, weapon) {
  if (weapon == null)
    return null
  let weaponPriceData = getItemPriceToShow(weapon) ?? 0
  if ((weaponPriceData?.price ?? 0) <= 0)
    return null
  let price = getItemPriceToShow(mod) ?? 0
  if (price <= 0)
    return null
  return {
    hplace = ALIGN_RIGHT
    children = mkItemPrice(price)
  }
}

function weaponModWidgetContent(slotData, dropData, image, text, isUnloadable, getFittingMods,
  onDrop, needBlink, weapon, modSlotName
) {
  let opacity = getSlotOpacity(dropData)
  let { rmbAction = null, lmbAltAction = null } = inventoryItemClickActions?[WEAPON_MOD.name]

  let stateFlags = Watched(0)
  return function() {
    let hint = buildInventoryItemTooltip(slotData)

    let isChargesIndicatorVisible = (dropData != null && dropData?.eid != null &&
      entityToUse.get() != dropData.eid && !(dropData?.isDelayedMoveMod ?? false)) || (dropData?.isLoadingAmmo ?? false)

    let ammoCountSource = (dropData?.isBuiltInAmmo ?? false) ? dropData.__merge({
        eid = dropData?.weaponEid ?? ecs.INVALID_ENTITY_ID}) : dropData

    function itemUseProgressComp(){
      let showProgress = dropData?.eid != null && entityToUse.get() == dropData.eid && (dropData?.isLoadingAmmo ?? false)
      let progressVal = showProgress ? clamp(calcItemUseProgress(curTime.get()).tointeger(), 0, 100) : 0.0
      return {
        rendObj = ROBJ_SOLID
        size = [pw(progressVal), pw(1) ]
        color = Color(100,120,90,40)
        vplace = ALIGN_BOTTOM
        margin = fsh(0.1)
        watch = showProgress ? [curTime, entityToUse] : entityToUse
      }
    }

    return  {
      watch = [stateFlags, mutationForbidenDueToInQueueState]
      rendObj = ROBJ_WORLD_BLUR_PANEL
      size = static flex()
      transform = {}
      behavior = isUnloadable && !isSpectator.get() ? Behaviors.DragAndDrop : Behaviors.Button
      onElemState = @(sf) stateFlags.set(sf)
      fillColor = 0x22000000
      onClick = function(event) {
        if (mutationForbidenDueToInQueueState.get()) {
          return
        }
        if ("allowed_items" not in slotData) {
          let slotTemplate = slotData?.template ?? slotData?.itemTemplate
          if (slotTemplate == null) {
            logerr("[inventoryWeaponMod] null slot data")
            print("[inventoryWeaponMod] Slot data:")
            print(slotData)
            return
          }
          let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(slotTemplate)
          let ammoName = template?.getCompValNullable("boxed_item__template")
          slotData.__update({ allowed_items = [ammoName] })
        }
        if (event.button == 1 && !previewPreset.get()) {
          rmbAction?(slotData.__merge({
            charges = get_equipped_magazine_current_ammo_count(dropData)
          }), event)
        }
        if(event.button == 0 && !needBlink) {
          if (isAltPressed.get() && lmbAltAction != null)
            lmbAltAction(slotData)
          else {
            let fittingMods = getFittingMods()
            openChocolateWnd({
              event,
              itemsDataArr = fittingMods,
              onClick = function(item, actions) {
                if ((actions ?? {}).len() > 0) {
                  local slotName = modSlotName
                  let slotIdx = weaponSlotsKeys.findindex(@(v) v == weapon.currentWeaponSlotName)
                  if (slotName == null) {
                    slotName = weapon?.mods.findindex(@(v) v.allowed_items.contains(item.itemTemplate))
                  }
                  actions?.weapons[slotIdx].onDropToMod(item, slotIdx, slotName, null)
                  return
                }
                onDrop(item)
              }
              itemInSlot = dropData
              shopData = mintEditState.get() ? null
                : needShowQuickSlotPurchase(slotData) ? purchaseItemsToSlot(slotData, event) : null
            })
          }
        }
      }
      function onHover(on) {
        if (on && (dropData?.ammoCount ?? 0) == 0) {
          focusedData.set(isUnloadable ? slotData : {
            allowed_items = slotData?.allowed_items
            weaponModAmmo = slotData?.ammoHolders
            weapModSlotName = slotData?.weapModSlotName
          })
        }
        else
          focusedData.set(null)

        if (on) {
          if (slotData?.slotTooltip && slotData?.slotTooltip != "") {
            setTooltip(loc(slotData.slotTooltip))
          }
          else if (!(dropData?.isDelayedMoveMod ?? false))
            setTooltip(hint != "" ? hint : null)
          let pcHotkeysHints = hoverPcHotkeysPresentation?[WEAPON_MOD.name]?(slotData)
          hoverHotkeysWatchedList.set(pcHotkeysHints)
        }
        else {
          setTooltip(null)
          hoverHotkeysWatchedList.set(null)
        }
      }
      onDragMode = function(on, item) {
        draggedData.set(on ? item : null)
        if (on)
          sound_play("ui_sounds/inventory_item_take")
      }
      dropData = mutationForbidenDueToInQueueState.get() ? null : dropData
      stopHover = true
      children = {
        rendObj = ROBJ_BOX
        size = static flex()
        fillColor = (slotData?.noSuitableItemForPresetFoundCount ?? 0) > 0 ? noItemContainerBg
          : (stateFlags.get() & S_DRAG) ? modFillDragColor
          : (stateFlags.get() & S_HOVER) && isUnloadable ? BtnBgHover : Color(0,0,0,0)
        borderColor = (stateFlags.get() & S_DRAG) ? modBorderColor
          : (stateFlags.get() & S_HOVER) ? BtnBdFocused
          : Color(67, 67, 67)
        borderWidth = (stateFlags.get() & S_HOVER) && !isUnloadable ? hdpxi(2) : 0
        padding = static hdpx(1)
        children = [
          slotData?.isCorrupted ? corruptedItemImageBackground : null
          {
            vplace = ALIGN_CENTER
            hplace = ALIGN_CENTER
            opacity
            children = image
          }
          {
            behavior = isUnloadable ? [Behaviors.Marquee] : null
            vplace = ALIGN_BOTTOM
            hplace = ALIGN_CENTER
            maxWidth = static pw(100)
            children = {
              rendObj = ROBJ_TEXT
              text
              vplace = ALIGN_BOTTOM
              fontFxColor = static Color(30,30,30)
              fontFx = FFT_BLUR
              margin = fsh(0.3)
            }.__update(tiny_txt)
          }
          isChargesIndicatorVisible ? chargesIndicator(
            get_equipped_magazine_current_ammo_count(dropData),
            dropData?.maxCharges,
            dropData?.countKnown ?? true,
            "") : null
          nexusPointsCostComp(slotData?.nexusCost)
          itemUseProgressComp
          mkCheckAmmoButton(ammoCountSource)
          mkStopCheckAmmoButton(ammoCountSource)
          mkItemCheckAmmoProgress(ammoCountSource)
          mkStopLoadUnloadAmmoButton(dropData, HERO_ITEM_CONTAINER)
        ]
      }
    }
  }
}

let nullFunc = @(...) null
let mkWeaponModWidget = kwarg(
  function mkWeaponModWidget(size=[itemHeight, itemHeight], text="", isUnloadable=true, slotData=null,
    isActionForbided = false, dropData=null, onDrop=nullFunc, canDropDragged=nullFunc, image=null, children=null,
    getFittingMods = @() null, weapon = null, modSlotName=null ) {
      let needBlink = (dropData?.isDelayedMoveMod ?? false)
      let opacity = getSlotOpacity(dropData)

      if (dropData != null) {
        dropData = dropData.__merge({
          RMB = "item/action/unequip"
        })
      }
      let cont = weaponModWidgetContent(slotData, dropData, image, text, isUnloadable,
        getFittingMods, onDrop, needBlink, weapon, modSlotName)
      let stateFlags = Watched(0)
      children = type(children)=="array" ? children : [children]
      function weaponModWidget() {
        let needMark = ((draggedData.get() != null) && canDropDragged(draggedData.get()))
        let sf = stateFlags.get()
        return {
          watch = [draggedData, stateFlags]
          size
          clipChildren = true
          onElemState = @(s) stateFlags.set(s)
          behavior = isActionForbided ? Behaviors.Button : [Behaviors.Button, Behaviors.DragAndDrop]
          canDrop = canDropDragged
          onDrop
          children = [cont]
            .extend(children)
            .append(needBlink ? moveMarker(sf, opacity) : null,
              needMark ?
                (
                  mutationForbidenDueToInQueueState.get() ?
                    dropMarker(sf, true, "") :
                    dropMarker(sf)
                )
              : null,
              mkPriceBlock(slotData, weapon))
        }
      }
      return weaponModWidget
    }
)

function mkToggleIcon(modsData, weaponSlot) {
  let isActive = Computed(@() weaponSlot in activeModsSlots.get())
  local opacity = 1
  local isCurrentWeapon = false
  foreach (mod in modsData) {
    let { dropData = null, isCurrent = false } = mod
    if (opacity == 1)
      opacity = getSlotOpacity(dropData)
    if (isCurrent && !isCurrentWeapon)
      isCurrentWeapon = true
  }
  let equippedMods = modsData.reduce(function(res, v) {
    if (v.dropData != null)
      return res + 1
    return res
  }, 0)
  let needBlik = modsData.findvalue(@(mod) mod?.dropData.isDelayedMoveMod) != null
  let stateFlags = Watched(0)
  return function() {
    let sf = stateFlags.get()
    let markIdx = modsData.findindex(@(mod)
      draggedData.get() != null && mod.canDropDragged(draggedData.get()))
    let curMod = modsData?[markIdx]
    let { canDropDragged = null, onDrop = null, dropData = null } = curMod
    return {
      watch = [stateFlags, isActive, draggedData, isSpectator]
      onElemState = @(s) stateFlags.set(s)
      rendObj = ROBJ_BOX
      size = [itemHeight, itemHeight]
      fillColor = (sf & S_DRAG) ? modFillDragColor
        : sf & S_HOVER? BtnBgHover
        : isActive.get() ? ItemBgColor
        : Color(0,0,0,0)
      borderColor = isCurrentWeapon ? BtnBdSelected : Color(67, 67, 67)
      borderWidth = hdpx(1)
      transform = {}
      behavior = !isSpectator.get() ? Behaviors.DragAndDrop : Behaviors.Button
      onClick = function() {
        if (isActive.get())
          anim_start($"{weaponSlot}")
        else
          activeModsSlots.mutate(@(v) v[weaponSlot] <- true )
      }
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      stopMouse = true
      onDragMode = function(on, item) {
        draggedData.set(on ? item : null)
        if (on)
          sound_play("ui_sounds/inventory_item_take")
      }
      function onHover(on) {
        if (draggedData.get() != null)
          return
        setTooltip(on && isActive.get() ? loc("mods/hide") : loc("mods/show"))
      }
      stopHover = true
      dropData
      canDrop = canDropDragged
      onDrop
      children = [
        faComp("cog", {
          fontSize = hdpx(32)
          color = defItemColor
        })
        mkText($"{equippedMods}/{modsData.len()}", {
          vplace = ALIGN_BOTTOM
          fontFxColor = Color(30,30,30)
          fontFx = FFT_BLUR
          padding = hdpx(3)
        }.__update(tiny_txt))
        needBlik ? moveMarker(sf, opacity) : null
        markIdx != null ? dropMarker(sf) : null
      ]
    }
  }
}

function mkModsToggler(mods, modsData, weaponSlot) {
  let curPage = Watched(0)
  let listChildren = mkVertPaginatorList(mods, MAX_MODS_TO_SHOW, curPage,
    {
      flow = FLOW_HORIZONTAL
      gap = hdpx(5)
    }, {
        style = {
          transform = {}
          animations = [
            static { prop=AnimProp.translate, from = [sw(-20), 0], to = [0,0], duration = 0.1, play = true }
            { prop=AnimProp.translate, from = static [0, 0], to = static [-sw(10), 0], playFadeOut = true,
              duration = 0.1, trigger = $"{weaponSlot}",
              onFinish = @() activeModsSlots.mutate(@(v) v.$rawdelete(weaponSlot)) }
          ]
          stopMouse = true
        }
    })

  return {
    flow = FLOW_HORIZONTAL
    halign = ALIGN_LEFT
    gap = hdpx(5)
    children = [
      mkToggleIcon(modsData, weaponSlot)
      @() {
        watch = activeModsSlots
        halign = ALIGN_LEFT
        clipChildren = true
        children = weaponSlot in activeModsSlots.get() ? listChildren : null
      }
    ]
  }
}

return {
  mkWeaponModWidget
  mkModsToggler
}
