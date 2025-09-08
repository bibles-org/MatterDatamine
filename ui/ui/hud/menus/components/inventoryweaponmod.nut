from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { tiny_txt } = require("%ui/fonts_style.nut")
let { draggedData, focusedData, getSlotOpacity, isAltPressed } = require("%ui/hud/state/inventory_state.nut")
let {setTooltip} = require("%ui/components/cursors.nut")
let dropMarker = require("dropMarker.nut")
let {moveMarker} = require("moveMarker.nut")
let {BtnBgHover, BtnBdHover, ItemBgColor, BtnBdSelected, noItemContainerBg } = require("%ui/components/colors.nut")
let {isSpectator} = require("%ui/hud/state/spectator_state.nut")
let { buildInventoryItemTooltip } = require("%ui/hud/menus/components/inventoryItemTooltip.nut")
let { itemHeight } = require("%ui/hud/menus/components/inventoryStyle.nut")
let { mkCheckAmmoButton, mkStopCheckAmmoButton, mkItemCheckAmmoProgress, needShowQuickSlotPurchase,
  purchaseItemsToSlot } = require("%ui/hud/menus/components/inventoryItemUtils.nut")
let { chargesIndicator, corruptedItemImageBackground } = require("%ui/hud/menus/components/inventoryItem.nut")
let { get_equipped_magazine_current_ammo_count } = require("%ui/hud/state/item_info.nut")
let {entityToUse} = require("%ui/hud/state/entity_use_state.nut")
let { openChocolateWnd } = require("%ui/components/chocolateWnd.nut")
let { hoverPcHotkeysPresentation } = require("%ui/hud/menus/components/inventoryActionsHints.nut")
let { WEAPON_MOD } = require("%ui/hud/menus/components/slotTypes.nut")
let { hoverHotkeysWatchedList } = require("%ui/components/pcHoverHotkeyHitns.nut")
let faComp = require("%ui/components/faComp.nut")
let { mkVertPaginatorList } = require("%ui/components/mkDotPaginatorList.nut")
let { mkText } = require("%ui/components/commonComponents.nut")
let { inventoryItemClickActions } = require("%ui/hud/menus/inventoryActions.nut")
let { getItemPriceToShow, mkItemPrice } = require("%ui/mainMenu/market/inventoryToMarket.nut")
let { isPreparationOpened, mintEditState } = require("%ui/mainMenu/raid_preparation_window_state.nut")
let { previewPreset } = require("%ui/equipPresets/presetsState.nut")
let { logerr } = require("dagor.debug")
let { weaponSlotsKeys } = require("%ui/types/weapon_slots.nut")

let modFillDragColor = ItemBgColor
let modBorderColor = Color(30,30,30,5)
let defItemColor = Color(138, 138, 138)
const MAX_MODS_TO_SHOW = 3
let activeModsSlots = Watched({})

let mkPriceBlock = @(mod, weapon) function() {
  let watch = isPreparationOpened
  if (!isPreparationOpened.get() || weapon == null)
    return { watch }
  let weaponPrice = getItemPriceToShow(weapon) ?? 0
  if (weaponPrice <= 0)
    return { watch }
  let price = getItemPriceToShow(mod) ?? 0
  if (price <= 0)
    return { watch }
  return {
    watch
    hplace = ALIGN_RIGHT
    children = mkItemPrice(price)
  }
}

function weaponModWidgetContent(slotData, dropData, image, text, isUnloadable, getFittingMods,
  onDrop, needBlink, weapon, modSlotName
) {
  let opacity = getSlotOpacity(dropData)
  let { rmbAction = null, lmbAltAction = null } = inventoryItemClickActions?[WEAPON_MOD.name]
  return watchElemState(function(sf) {
    let hint = buildInventoryItemTooltip(slotData)

    let isChargesIndicatorVisible = (dropData != null && dropData?.eid != null &&
      entityToUse.get() != dropData.eid && !(dropData?.isDelayedMoveMod ?? false))

    let ammoCountSource = (dropData?.isBuiltInAmmo ?? false) ? dropData.__merge({
        eid = dropData?.weaponEid ?? ecs.INVALID_ENTITY_ID}) : dropData

    return  {
      behavior = isUnloadable && !isSpectator.get() ? Behaviors.DragAndDrop : Behaviors.Button
      transform = {}
      rendObj = ROBJ_BOX
      fillColor =
        (slotData?.noSuitableItemForPresetFoundCount ?? 0) > 0 ? noItemContainerBg
        : (sf & S_DRAG) ? modFillDragColor
        : (sf & S_HOVER) && isUnloadable ? BtnBgHover : Color(0,0,0,0)
      borderColor = (sf & S_DRAG) ? modBorderColor : (sf & S_HOVER) ?
                    BtnBdHover : Color(67, 67, 67)
      borderWidth = (sf & S_HOVER) && !isUnloadable ? hdpx(2.0) : 0
      key = {}
      size = flex()
      clipChildren = true
      padding = hdpx(1)
      onClick = function(event) {
        if (event.button == 1 && !previewPreset.get()) {
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
              shopData =  mintEditState.get() ? null
                : needShowQuickSlotPurchase(slotData) ? purchaseItemsToSlot(slotData, event) : null
            })
          }
        }
      }
      children = [
        slotData?.isCorrupted ? corruptedItemImageBackground : null
        {
          vplace=ALIGN_CENTER
          hplace=ALIGN_CENTER
          size=SIZE_TO_CONTENT
          children = image
          opacity
        }
        {
          transform = {}
          behavior = isUnloadable ? [Behaviors.Marquee] : null
          vplace = ALIGN_BOTTOM
          hplace = ALIGN_CENTER
          maxWidth = pw(100)
          children = {
            rendObj = ROBJ_TEXT
            text
            vplace = ALIGN_BOTTOM
            fontFxColor = Color(30,30,30)
            fontFx = FFT_BLUR
            margin = fsh(0.3)
          }.__update(tiny_txt)
        }
        isChargesIndicatorVisible ? chargesIndicator(
          get_equipped_magazine_current_ammo_count(dropData),
          dropData?.maxCharges,
          dropData?.countKnown ?? true,
          "") : null
        mkCheckAmmoButton(ammoCountSource)
        mkStopCheckAmmoButton(ammoCountSource)
        mkItemCheckAmmoProgress(ammoCountSource)
      ]
      function onHover(on) {
        if (on && (dropData?.ammoCount ?? 0) == 0)
          focusedData.set(isUnloadable ? dropData : {weaponModItems = slotData?.allowed_items, weaponModAmmo = slotData?.ammoHolders})
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
        draggedData.update(on ? item : null)
      }
      dropData
      stopHover=true
    }
  }
)}

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
      let needMark = ((draggedData.value != null) && canDropDragged(draggedData.value))
      let sf = stateFlags.get()
      return {
        size
        clipChildren = true
        onElemState = @(s) stateFlags.set(s)

        children = [cont]
          .extend(children)
          .append(needBlink ? moveMarker(sf, opacity) : null,
            needMark ? dropMarker(sf) : null,
            mkPriceBlock(slotData, weapon))
        behavior = isActionForbided ? Behaviors.Button : [Behaviors.Button, Behaviors.DragAndDrop]
        watch = [draggedData, stateFlags]
        canDrop = canDropDragged
        onDrop
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
  return watchElemState(function(sf) {
    let markIdx = modsData.findindex(@(mod)
      draggedData.get() != null && mod.canDropDragged(draggedData.get()))
    let curMod = modsData?[markIdx]
    let { canDropDragged = null, onDrop = null, dropData = null } = curMod
    return {
      watch = [isActive, draggedData, isSpectator]
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
        draggedData.update(on ? item : null)
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
  })
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
            { prop=AnimProp.translate, from = [sw(-20), 0], to = [0,0], duration = 0.1, play = true }
            { prop=AnimProp.translate, from = [0, 0], to = [-sw(10), 0], playFadeOut = true,
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
