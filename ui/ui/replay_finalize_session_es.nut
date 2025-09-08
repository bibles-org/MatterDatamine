import "%dngscripts/ecs.nut" as ecs

let {CmdReplayRewindSaveState, CmdReplayRewindLoadState} = require("dasevents")
let {nestWatched} = require("%dngscripts/globalState.nut")

let replaySavedState = nestWatched("replaySavedState", {})

ecs.register_es("replay_rewind_state_save_es", {
  [[CmdReplayRewindSaveState]] = @(evt, _eid, _comp) replaySavedState(evt.state.getAll())
}, {}, {tags="playingReplay"})

ecs.register_es("replay_rewind_state_load_es", {
  [["onInit"]] = function(...) {
    if (replaySavedState.value.len() == 0)
      return
    let state = ecs.CompObject()
    foreach (key, val in replaySavedState.value)
      state[key] <- val
    ecs.g_entity_mgr.broadcastEvent(CmdReplayRewindLoadState({ state }))
    replaySavedState({})
  }
}, { comps_rq=["replay__startAt"] }, { tags="playingReplay" })
