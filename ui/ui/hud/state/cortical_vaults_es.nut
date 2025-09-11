import "%ui/hud/state/is_teams_friendly.nut" as is_teams_friendly
import "%ui/hud/state/get_player_team.nut" as get_player_team
from "%ui/helpers/ec_to_watched.nut" import mkWatchedSetAndStorage
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { localPlayerTeam, localPlayerTeamIsIncognito } = require("%ui/hud/state/local_player.nut")
let { watchedHeroPlayerEid } = require("%ui/hud/state/watched_hero.nut")
let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")

let {
  corticalVaultsSet,
  corticalVaultsGetWatched,
  corticalVaultsUpdateEid,
  corticalVaultsDestroyEid
} = mkWatchedSetAndStorage("corticalVaults")


let corticalVaultsQuery = ecs.SqQuery("cortical_vaults_status_ui_query", {
  comps_no = ["item_in_equipment"],
  comps_rq = ["cortical_vault"],
  comps_ro = [
    ["item__containerOwnerEid", ecs.TYPE_EID],
    ["playerItemOwner", ecs.TYPE_EID],
    ["item__humanOwnerEid", ecs.TYPE_EID],
    ["transform", ecs.TYPE_MATRIX, null],
    ["cortical_vault_in_inventory__trackPos", ecs.TYPE_POINT3, null],
  ]
})

function updateCorticalVaultsStatus (eid, comp) {
  let isTeammate = is_teams_friendly(get_player_team(comp.playerItemOwner), localPlayerTeam.get())
  if (!isTeammate || 
        localPlayerTeamIsIncognito.get() || 
        (!comp?.transform && !comp?.cortical_vault_in_inventory__trackPos) || 
        watchedHeroPlayerEid.get() == comp.playerItemOwner || 
        controlledHeroEid.get() == comp.item__humanOwnerEid){ 
    corticalVaultsDestroyEid(eid)
    return
  }
  let res = {
    playerItemOwner = comp.playerItemOwner
    item__containerOwnerEid = comp.item__containerOwnerEid
    pos = comp?.transform ? comp.transform.getcol(3) : comp.cortical_vault_in_inventory__trackPos
  }
  corticalVaultsUpdateEid(eid, res)
}

localPlayerTeam.subscribe_with_nasty_disregard_of_frp_update(@(_) corticalVaultsQuery.perform(updateCorticalVaultsStatus))
localPlayerTeamIsIncognito.subscribe_with_nasty_disregard_of_frp_update(@(_) corticalVaultsQuery.perform(updateCorticalVaultsStatus))
watchedHeroPlayerEid.subscribe_with_nasty_disregard_of_frp_update(@(_) corticalVaultsQuery.perform(updateCorticalVaultsStatus))

ecs.register_es("cortical_vaults_status_ui_es",
  {
    [["onInit", "onChange"]] = updateCorticalVaultsStatus
    onDestroy = @(eid, _comp) corticalVaultsDestroyEid(eid)
  },
  {
    comps_no = ["item_in_equipment"],
    comps_rq = ["cortical_vault"],
    comps_track = [
      ["item__containerOwnerEid", ecs.TYPE_EID],
      ["cortical_vault_in_inventory__trackPos", ecs.TYPE_POINT3, null]
    ],
    comps_ro = [
      ["playerItemOwner", ecs.TYPE_EID],
      ["item__humanOwnerEid", ecs.TYPE_EID],
      ["transform", ecs.TYPE_MATRIX, null],
    ]
  }
)

return {
  corticalVaultsSet,
  corticalVaultsGetWatched,
}
