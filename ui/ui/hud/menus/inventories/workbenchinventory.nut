from "%ui/ui_library.nut" import *

let { isShiftPressed } = require("%ui/hud/state/inventory_state.nut")
let { get_item_info } = require("%ui/hud/state/item_info.nut")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")

let workbenchItemContainer = Watched([])
let workbenchRepairInProgress = Watched(false)

function removeFromWorkbench(item) {
  if (workbenchRepairInProgress.get())
    return
  let indexToProceed = isShiftPressed.get() ? item.uniqueIds.len() : 1
  workbenchItemContainer.mutate(function(cont) {
    for(local i=0; i < indexToProceed; i++){
      cont.remove(cont.findindex(@(v) v.uniqueId == item.uniqueIds[i]))
    }
  })
}


function dropToWorkbench(item, fromListName) {
  if (workbenchRepairInProgress.get())
    return
  let indexToProceed = isShiftPressed.get() ? item.uniqueIds.len() : 1
  workbenchItemContainer.mutate(function(v) {
    for(local i=0; i < indexToProceed; i++){
      let additionalFields = {
        uniqueId = item.uniqueIds[i]
        uniqueIds = [ item.uniqueIds[i] ]
        eid = item.eids[i]
        eids = [ item.eids[i] ]
        count = 1
        refiner__fromList = fromListName
      }
      v.append( item?.itemOverridedWithProto ?
        get_item_info(item.eids[i]).__update(additionalFields) :
        item.__merge(additionalFields)
      )
    }
  })
}

function itemCanBeRepaired(item) {
  return !isOnboarding.get()
    && isOnPlayerBase.get()
    && (item?.itemCanBeRepaired ?? false)
    && item?.hp != null
    && item.hp < (item?.maxHp ?? 0)
}

return {
  workbenchItemContainer
  removeFromWorkbench
  dropToWorkbench
  workbenchRepairInProgress
  itemCanBeRepaired
}