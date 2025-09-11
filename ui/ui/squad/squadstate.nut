import "%dngscripts/ecs.nut" as ecs
from "%dngscripts/globalState.nut" import nestWatched

from "%ui/ui_library.nut" import *

let userInfo = require("%sqGlob/userInfo.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let selfUid = Computed(@() userInfo.get()?.userId)
let squadId = nestWatched("squadId", null)

let isInvitedToSquad = nestWatched("isInvitedToSquad", {})
let squadMembers = nestWatched("squadMembers", {})
let squadLen = Computed(@() squadMembers.get().len())
let squadSelfMember = Computed(@() squadMembers.get()?[selfUid.get()])
let allMembersState = Computed(@() squadMembers.get().map(@(s) s?.state))
let selfMemberState = Computed(@() allMembersState.get()?[selfUid.get()])
let squadLeaderState = Computed(@() allMembersState.get()?[squadId.get()])

let isInSquad = Computed(@() squadId.get() != null)
let isSquadLeader = Computed(@() squadId.get() == selfUid.get())
let isLeavingWillDisbandSquad = Computed(@() squadLen.get() == 1 || (squadLen.get() + isInvitedToSquad.get().len() <= 2))
let enabledSquad = Computed(@() !isOnboarding.get())
let canInviteToSquad = Computed(@() enabledSquad.get() && (!isInSquad.get() || isSquadLeader.get()))

let notifyMemberAdded = []
let notifyMemberRemoved = []


let squad_mannequin_placer_query = ecs.SqQuery("squad_mannequin_placer_query",
  {
    comps_ro = [["squadmate_mannequin_placer__idx", ecs.TYPE_INT]]
    comps_rw = [["squadmate_mannequin_placer__data", ecs.TYPE_OBJECT]]
  }
)

let mannequinMemberData = Computed(function() {
  let myUid = selfUid.get()
  return squadMembers
          .get()
          .values()
          .filter(@(member) member?.userId != null && myUid != member.userId)
          .sort(@(a, b) a.userId <=> b.userId)
})


let update_squad_mannequin_data = function(membersData) {
  squad_mannequin_placer_query.perform(function(_eid, comp){
    let idx = comp.squadmate_mannequin_placer__idx
    if (idx < 0 || idx >= membersData.len()) {
      comp.squadmate_mannequin_placer__data = {}
    } else {
      comp.squadmate_mannequin_placer__data = membersData[idx]?.state ?? {}
    }
  })
}


gui_scene.setInterval(2, @() update_squad_mannequin_data(mannequinMemberData.get()), "ui/squad/squadState.nut:update_squad_mannequin_data")



let autoSquad = nestWatched("autoSquad", false)

function makeSharedData(persistId) {
  let res = {}
  foreach (key in ["clusters", "squadChat"])
    res[key] <- nestWatched($"{persistId}{key}", null)
  return res
}
let squadSharedData = makeSharedData("squadSharedData")
let squadServerSharedData = makeSharedData("squadServerSharedData")

return {
  selfUid
  squadId

  isInvitedToSquad
  squadMembers
  isSquadNotEmpty = Computed(@() squadMembers.get().len()>1)
  squadLen
  squadSelfMember
  allMembersState
  selfMemberState
  squadLeaderState

  isInSquad
  isSquadLeader
  isLeavingWillDisbandSquad
  enabledSquad
  canInviteToSquad

  autoSquad

  squadSharedData
  squadServerSharedData

  
  notifyMemberAdded
  notifyMemberRemoved
  subsMemberAddedEvent = @(func) notifyMemberAdded.append(func)
  subsMemberRemovedEvent = @(func) notifyMemberRemoved.append(func)
}