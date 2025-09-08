import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { addInteractiveElement, removeInteractiveElement } = require("%ui/hud/state/interactive_state.nut")
let { WorkBenchMenuId, encounterWorkbenchEid,
  encounterWorkbenchCharges, encounterWorkbenchMaxCharges,
  encounterWorkbenchItemsToRepair } = require("%ui/hud/state/encounter_workbench_state.nut")
let { CmdEncounterWorkbenchMenuRequest, RequestEncounterWorkbenchRepairItemAction, sendNetEvent } = require("dasevents")
let { EncounterWorkbenchMenuState } = require("%sqGlob/dasenums.nut")
let { h2_txt, body_txt } = require("%ui/fonts_style.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { fontIconButton } = require("%ui/components/button.nut")
let { itemsPanelList, setupPanelsData } = require("%ui/hud/menus/components/inventoryItemsList.nut")
let { get_controlled_hero } = require("%dngscripts/common_queries.nut")
let { REPAIR } = require("%ui/hud/menus/components/slotTypes.nut")

function close(){
  ecs.g_entity_mgr.broadcastEvent(CmdEncounterWorkbenchMenuRequest({state = EncounterWorkbenchMenuState.NONE}))
}

let containerAnims = [
  { prop=AnimProp.opacity, from=0, to=1, duration=0.25, play=true, easing=OutCubic }
  { prop=AnimProp.scale, from=[1,1], to=[1,0.01], duration=0.25, playFadeOut=true, easing=OutCubic }
  { prop=AnimProp.opacity, from=1, to=0, duration=0.25, playFadeOut=true, easing=OutCubic }
]

let closebutton = fontIconButton("icon_buttons/x_btn.svg", close, {
  size = [fsh(5), fsh(5)]
  halign = ALIGN_RIGHT
  valign = ALIGN_TOP
  hplace = ALIGN_RIGHT
  vplace = ALIGN_TOP
  pos = [-sh(2), sh(2)]
})


function patchItem(item) {
  return item == null ? null : item.__update(
    {
      canTake = false
      isDragAndDropAvailable = false
    })
}

const itemsInRow = 6
let processItems = @(items) items.map(patchItem)

let panelsData = setupPanelsData(encounterWorkbenchItemsToRepair,
                                 itemsInRow,
                                 [encounterWorkbenchItemsToRepair],
                                 processItems)

function encounterWorkbenchRepairMenu() {
  panelsData.resetScrollHandlerData()
  let itemsToRepair = encounterWorkbenchItemsToRepair.get()
  let numItems = itemsToRepair?.len() ?? 0

  let item_actions = {
    lmbAction = @(item) sendNetEvent(
    encounterWorkbenchEid.get(), RequestEncounterWorkbenchRepairItemAction(
      {
        heroEid = get_controlled_hero()
        itemEid = item?.eid ?? ecs.INVALID_ENTITY_ID
      }))
  }

  return {
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    flow = FLOW_VERTICAL
    gap = fsh(1)
    size = [pw(95), sh(20.5)]
    pos = [0, sh(1.5)]
    watch = encounterWorkbenchItemsToRepair

    children = [
      {
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        rendObj = ROBJ_TEXT
        color = Color(196,196,196,196)
        text = loc("hud/workbench_repair_menu_title")
      }.__update(h2_txt)
      {
        size = flex()
        halign = ALIGN_CENTER
        onAttach = panelsData.onAttach
        onDetach = panelsData.onDetach
        children = [
          itemsPanelList({
            outScrollHandlerInfo=panelsData.scrollHandlerData,
            
            itemsPanelData=panelsData.itemsPanelData,
            
            item_actions
            visualParams={ animations = null },
            list_type = REPAIR
            listVisualParams={ padding = [hdpx(10), hdpx(10)] },
            xSize=itemsInRow
          })
          numItems != 0 ? null : {
            size = flex()
            behavior = [Behaviors.TextArea]
            hplace = ALIGN_CENTER
            vplace = ALIGN_CENTER
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            rendObj = ROBJ_TEXTAREA
            color = Color(120,120,120,120)
            text = loc("hud/workbench_repair_menu_havent_damaged_items")
          }.__update(body_txt)
        ]
      }
    ]
  }
}

function workbenchMenu() {
  return {
    onAttach = @() addInteractiveElement(WorkBenchMenuId)
    onDetach = @() removeInteractiveElement(WorkBenchMenuId)
    rendObj = ROBJ_SOLID
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = flex()
    color = Color(0,0,0,150)
    animations = containerAnims
    behavior = Behaviors.Button
    onClick = close
    children = {
      rendObj = ROBJ_WORLD_BLUR_PANEL
      fillColor = Color(20, 20, 20, 55)
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      size = [sh(52), sh(27.5)]
      gap = fsh(1.5)
      children = [
        closebutton
        @() {
          hplace = ALIGN_LEFT
          vplace = ALIGN_TOP
          rendObj = ROBJ_TEXT
          watch = encounterWorkbenchCharges
          pos = [sh(2), sh(2)]
          size = [flex(), fsh(5)]
          text = loc("hud/workbench_charges_hint", {
            charges = encounterWorkbenchCharges.get(),
            maxCharges = encounterWorkbenchMaxCharges.get() })
          color = Color(170, 235, 255)
        }.__update(body_txt)
        encounterWorkbenchRepairMenu
      ]
    }
    hotkeys = [
      [$"^{JB.B} | Esc", {action = close, description = loc("mainmenu/btnClose")}],
    ]
  }
}


return {
  workbenchMenu
  WorkBenchMenuId
}
