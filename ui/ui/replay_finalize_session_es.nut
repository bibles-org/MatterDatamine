from "%dngscripts/globalState.nut" import nestWatched

from "dasevents" import CmdReplayRewindSaveState, CmdReplayRewindLoadState

import "%dngscripts/ecs.nut" as ecs


let replaySavedState = nestWatched("replaySavedState", {})

ecs.register_es("replay_rewind_state_save_es", {
  [[CmdReplayRewindSaveState]] = @(evt, _eid, _comp) replaySavedState.set(evt.state.getAll())
}, {}, {tags="playingReplay"})

ecs.register_es("replay_rewind_state_load_es", {
  [["onInit"]] = function(...) {
    if (replaySavedState.get().len() == 0)
      return
    let state = ecs.CompObject()
    foreach (key, val in replaySavedState.get())
      state[key] <- val
    ecs.g_entity_mgr.broadcastEvent(CmdReplayRewindLoadState({ state }))
    replaySavedState.set({})
  }
}, { comps_rq=["replay__startAt"] }, { tags="playingReplay" })
