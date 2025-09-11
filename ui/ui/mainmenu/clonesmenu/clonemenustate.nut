from "eventbus" import eventbus_send, eventbus_subscribe

from "%ui/ui_library.nut" import *

let { currentAlter, alterContainers } = require("%ui/profile/profileState.nut")
let { equipment } = require("%ui/hud/state/equipment.nut")

let alterRewardWindowOpened = Watched(false)

let currentChronogenes = Computed(function() {
  return alterContainers.get().findvalue(@(v) v.containerId == currentAlter.get()) ?? {}
})

let isWaitingForChronogenesResponse = Watched(false)
eventbus_subscribe("profile_server.make_alter_from_chronogenes.result", @(...) isWaitingForChronogenesResponse.set(false))

function sendRawChronogenes(container) {
  let mainGenes = container.primaryChronogenes
  let secondaryGenes = container.secondaryChronogenes
  let alter_name = container.alterName
  isWaitingForChronogenesResponse.set(true)
  let curMelee = equipment.get()?.chronogene_melee_1.uniqueId
  let meleeChronogenes = curMelee ? [ curMelee ] : []

  let curDogtag = equipment.get()?.chronogene_dogtag_1.uniqueId
  let dogtagChronogenes = curDogtag ? [ curDogtag ] : []

  eventbus_send("profile_server.make_alter_from_chronogenes",
    {container_id_int64=container.containerId, mainGenes=mainGenes, secondaryGenes=secondaryGenes, alterName=alter_name, stub_melee_chronogenes=meleeChronogenes, dogtag_chronogenes=dogtagChronogenes})
}

function equipMeleeChoronogeneItem(meleeChronogeneItem) {
  let curChronogenes = currentChronogenes.get()

  let mainGenes = curChronogenes.primaryChronogenes
  let secondaryGenes = curChronogenes.secondaryChronogenes
  let alter_name = curChronogenes.alterName
  let containerId = curChronogenes.containerId
  let meleeChronogeneId = meleeChronogeneItem?.uniqueId ? [ meleeChronogeneItem?.uniqueId ] : []

  let curDogtag = equipment.get()?.chronogene_dogtag_1.uniqueId
  let dogtagChronogenes = curDogtag ? [ curDogtag ] : []

  eventbus_send("profile_server.make_alter_from_chronogenes",
    {container_id_int64=containerId, mainGenes=mainGenes, secondaryGenes=secondaryGenes, alterName=alter_name, stub_melee_chronogenes=meleeChronogeneId, dogtag_chronogenes=dogtagChronogenes})
}

function equipTagChoronogeneItem(tagChronogeneItem) {
  let curChronogenes = currentChronogenes.get()

  let mainGenes = curChronogenes.primaryChronogenes
  let secondaryGenes = curChronogenes.secondaryChronogenes
  let alter_name = curChronogenes.alterName
  let containerId = curChronogenes.containerId
  let curMelee = equipment.get()?.chronogene_melee_1.uniqueId
  let meleeChronogenes = curMelee ? [ curMelee ] : []
  let tagChronogeneId = tagChronogeneItem?.uniqueId ? [ tagChronogeneItem?.uniqueId ] : []

  eventbus_send("profile_server.make_alter_from_chronogenes",
    {container_id_int64=containerId, mainGenes=mainGenes, secondaryGenes=secondaryGenes, alterName=alter_name, stub_melee_chronogenes=meleeChronogenes, dogtag_chronogenes=tagChronogeneId})
}

return {
  isWaitingForChronogenesResponse
  sendRawChronogenes
  currentChronogenes
  equipMeleeChoronogeneItem
  equipTagChoronogeneItem
  alterRewardWindowOpened
}