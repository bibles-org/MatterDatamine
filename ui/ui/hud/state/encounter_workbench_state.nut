from "%sqGlob/dasenums.nut" import EncounterWorkbenchMenuState
from "dasevents" import CmdShowUiMenu, CmdHideUiMenu, EventEncounterWorkbenchItemsToRepairChanged
from "%ui/hud/state/inventory_items_es.nut" import updateEidInventoryContainer
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


let encounterWorkbenchCharges = Watched(0)
let encounterWorkbenchMaxCharges = Watched(0)
let encounterWorkbenchEid = Watched(ecs.INVALID_ENTITY_ID)
let encounterWorkbenchItemsToRepair = mkWatched(persist, "encounterWorkbenchItemsToRepair", [])

const WorkBenchMenuId = "WorkbenchMenu"

let openEncounterWorkbenchMenu  = @() ecs.g_entity_mgr.broadcastEvent(CmdShowUiMenu({menuName = WorkBenchMenuId}))
let closeEncounterWorkbenchMenu  = @() ecs.g_entity_mgr.broadcastEvent(CmdHideUiMenu({menuName = WorkBenchMenuId}))

ecs.register_es("encounter_workbench_menu_controller_ui",
  {
    [["onInit", "onChange", EventEncounterWorkbenchItemsToRepairChanged]] = function(_evt, _eid, comp) {
      let needOpenWbMenu = comp["encounter_workbench_menu_controller__state"] != EncounterWorkbenchMenuState.NONE
      if (needOpenWbMenu)
        openEncounterWorkbenchMenu()
      else
        closeEncounterWorkbenchMenu()
      encounterWorkbenchEid.set(comp.encounter_workbench_menu_controller__workbenchEid)

      let items = comp.encounter_workbench_menu_controller__itemsToRepair.getAll()
      updateEidInventoryContainer(encounterWorkbenchItemsToRepair, items)
    }
    onDestroy = function(_eid, _comp) {
      closeEncounterWorkbenchMenu()
      encounterWorkbenchEid.set(ecs.INVALID_ENTITY_ID)
      encounterWorkbenchItemsToRepair.set([])
    }
  },
  {
    comps_track=[
      ["encounter_workbench_menu_controller__state", ecs.TYPE_INT],
      ["encounter_workbench_menu_controller__workbenchEid", ecs.TYPE_EID],
    ]
    comps_ro=[
      ["encounter_workbench_menu_controller__itemsToRepair", ecs.TYPE_EID_LIST]
    ]
  }
)


let getEncounterWorkbenchStateQuery = ecs.SqQuery(
  "getEncounterWorkbenchStateQuery",
   {
    comps_ro=[
      ["encounter_workbench__charges", ecs.TYPE_INT],
      ["encounter_workbench__maxCharges", ecs.TYPE_INT]
    ]
  })


function updateEncounterWorkbenchState(comp) {
  if (comp == null)
    return
  encounterWorkbenchCharges.set(comp.encounter_workbench__charges)
  encounterWorkbenchMaxCharges.set(comp.encounter_workbench__maxCharges)
}


encounterWorkbenchEid.subscribe_with_nasty_disregard_of_frp_update(function(val){
  if (val == ecs.INVALID_ENTITY_ID)
    return

  updateEncounterWorkbenchState(getEncounterWorkbenchStateQuery.perform(val, @(_eid, comp) comp))
})


ecs.register_es("encounter_workbench_state_ui",
  {
    onChange = function(eid, comp) {
      if (eid != encounterWorkbenchEid.get())
        return
      updateEncounterWorkbenchState(comp)
    },
    onDestroy = function(eid, _comp) {
      if (eid != encounterWorkbenchEid.get())
        return
      encounterWorkbenchCharges.set(0)
      encounterWorkbenchMaxCharges.set(0)
    }
  },
  {
    comps_track=[
      ["encounter_workbench__charges", ecs.TYPE_INT],
      ["encounter_workbench__maxCharges", ecs.TYPE_INT]
    ]
  }
)


return {
  WorkBenchMenuId
  encounterWorkbenchCharges
  encounterWorkbenchMaxCharges
  encounterWorkbenchEid
  encounterWorkbenchItemsToRepair
  openEncounterWorkbenchMenu
  closeEncounterWorkbenchMenu
}
