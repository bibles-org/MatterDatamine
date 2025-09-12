from "dagor.math" import Point3
from "%ui/helpers/common_queries.nut" import get_pos
from "dasevents" import EventMapObjectStateChanged
from "net" import get_sync_time
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")

let visible_interactables = Watched({})
local nearby_interactables = []
local pingged_interactables = []
let secretLootables = Watched({})
let mapObjectMarkers = Watched({})
let mapObjectZones = Watched({})
let game_trigger_markers = Watched({})
let hunter_vision_targets = Watched({})
let hunter_minions = Watched({})

function deleteEid(eid, state){
  if (eid in state.get())
    state.mutate(@(v) v.$rawdelete(eid))
}

ecs.register_es("game_trigger_markers_ui",
{
  [["onInit", "onChange"]] = function(_evt, eid, comp) {
    if (!comp.game_trigger_processor_show_hint__show) {
      deleteEid(eid, game_trigger_markers)
      return
    }
    game_trigger_markers.mutate(@(v) v[eid] <- {
      pos = comp.transform[3],
      text = comp.game_trigger_processor_show_hint__text,
      inputId = comp.game_trigger_processor_show_hint__inputId,
      minDistance = comp.game_trigger_processor_show_world_hint__minDistance,
      maxDistance = comp.game_trigger_processor_show_world_hint__maxDistance,
      clampToBorder = comp.game_trigger_processor_show_world_hint__clampToBorder
    })
  },

  onDestroy = function(eid, _comp){
    deleteEid(eid, game_trigger_markers)
  }
},
{
  comps_track = [["game_trigger_processor_show_hint__show", ecs.TYPE_BOOL]],
  comps_ro = [
    ["transform", ecs.TYPE_MATRIX],
    ["game_trigger_processor_show_hint__text", ecs.TYPE_STRING],
    ["game_trigger_processor_show_hint__inputId", ecs.TYPE_STRING],
    ["game_trigger_processor_show_world_hint__minDistance", ecs.TYPE_FLOAT],
    ["game_trigger_processor_show_world_hint__maxDistance", ecs.TYPE_FLOAT],
    ["game_trigger_processor_show_world_hint__clampToBorder", ecs.TYPE_BOOL]
  ]
})

let interactableQuery = ecs.SqQuery("interactableQuery", {
  comps_ro=[
    ["interactable__name", ecs.TYPE_STRING],
    ["interactable__icon", ecs.TYPE_STRING],
    ["interactable__iconYOffset", ecs.TYPE_FLOAT, 0.4],
    ["transform", ecs.TYPE_MATRIX]
  ]
})

function extractInteractableData(eid, destination, pingged) {
  interactableQuery.perform(eid, function(_eid, comp) {
    destination[eid] <- {
      name = comp["interactable__name"],
      icon = comp["interactable__icon"],
      yOffs = comp.interactable__iconYOffset,
      pingged
    }
  })
}

ecs.register_es("on_nearby_interactables_change_ui",
  {
    [["onChange", "onInit"]] = function(_evt, _eid, comp) {
      nearby_interactables = comp["interactables__nearby"].getAll()
      visible_interactables.mutate(function(value) {
        let toDelete = []
        foreach (iter_eid, _val in value) {
          if (!nearby_interactables.contains(iter_eid) && !pingged_interactables.contains(iter_eid))
            toDelete.append(iter_eid)
        }
        foreach (i in toDelete)
          value.$rawdelete(i)

        foreach (iter_eid in nearby_interactables) {
          if (value?[iter_eid] == null) {
            extractInteractableData(iter_eid, value, false)
          }
        }
      })
    }
  },
  {
    comps_track = [["interactables__nearby", ecs.TYPE_EID_LIST]],
    comps_rq = ["watchedByPlr"]
  }
)

ecs.register_es("on_pingged_interactables_change_ui",
  {
    [["onChange", "onInit"]] = function(_evt, _eid, comp) {
      pingged_interactables = comp["interactables__pingged"].getAll().map(@(v)v.eid)
      visible_interactables.mutate(function(value) {
        let toDelete = []
        foreach(iter_eid,_val in value) {
          let isPingged = pingged_interactables.contains(iter_eid)
          if (!nearby_interactables.contains(iter_eid) && !isPingged)
            toDelete.append(iter_eid)
          else {
            value[iter_eid].pingged = isPingged
          }
        }
        foreach (i in toDelete)
          value.$rawdelete(i)

        foreach(iter_eid in pingged_interactables) {
          if (value?[iter_eid] == null) {
            extractInteractableData(iter_eid, value, true)
          }
        }
      })
    }
  },
  {
    comps_track = [["interactables__pingged", ecs.TYPE_ARRAY]],
    comps_rq = ["watchedByPlr"]
  }
)

let linkedSecretLootableQuery = ecs.SqQuery("linkedSecretLootableQuery", {comps_ro = [["transform", ecs.TYPE_MATRIX]]})

ecs.register_es("secret_lootables_when_note_spawns_second_ui_es",
  {
    [["onInit", "onChange"]] = function(eid, comp){
      linkedSecretLootableQuery.perform(comp.secret_note__linkedContainerEid, function(_stash_eid, stash_comp){
        secretLootables.mutate(@(v) v[eid] <- {
          pos = stash_comp.transform[3]
        })
      })
    },
    onDestroy = function(eid, _comp){
      deleteEid(eid, secretLootables)
    }
  },
  {
    comps_track = [["secret_note__linkedContainerEid", ecs.TYPE_EID]]
    comps_rq = [["watchedPlayerItem", ecs.TYPE_TAG]]
  }
)

let linkedSecretNoteQuery = ecs.SqQuery("linkedSecretNoteQuery", {
  comps_ro = [["secret_note__linkedContainerEid", ecs.TYPE_EID]],
  comps_rq = [["watchedPlayerItem", ecs.TYPE_TAG]]})

ecs.register_es("secret_lootables_when_ri_spawns_second_ui_es",
  {
    onInit = function(eid, comp){
      linkedSecretNoteQuery.perform(function(note_eid, note_comp){
        if (note_comp.secret_note__linkedContainerEid == eid){
          secretLootables.mutate(@(v) v[note_eid] <- {
            pos = comp.transform[3]
          })
          return true
        }
        return false
      })
    },
    onDestroy = function(eid, _comp){
      deleteEid(eid, secretLootables)
    }
  },
  {
    comps_ro = [["transform", ecs.TYPE_MATRIX]]
    comps_rq = [["secret_lootable_rendinst", ecs.TYPE_TAG]]
  }
)

secretLootables.subscribe(function(v){
  log($"Secret note: ui secretLootables changed:", v)
})

ecs.register_es("map_object_markers_ui_es",
  {
    [["onChange", "onInit", EventMapObjectStateChanged]] = function(eid, comp){
      if (!comp.map_object__show) {
        deleteEid(eid, mapObjectMarkers)
        return
      }

      local markerPos = comp.transform[3]
      if (comp.map_object__parentContainerEid != ecs.INVALID_ENTITY_ID)
        markerPos = get_pos(comp.map_object__parentContainerEid)

      mapObjectMarkers.mutate(@(v) v[eid] <- {
        pos = markerPos,
        icon = comp.map_object_marker__iconName
        text = comp.map_object_marker__tooltip
        text_complete = comp.map_object_marker__complete_tooltip
        active = comp.map_object_marker__isActive
        complete = comp.map_object_marker__isComplete
        icon_complete = comp.map_object_marker__iconCompleteName
        icon_inactive = comp.map_object_marker__iconInactiveName
        objectiveTag = comp.objective_static_target__tag ?? comp.map_object_marker__tag ?? ""
        activeColor = comp.map_object_marker__activeColor
        hoverColor = comp.map_object_marker__hoverColor
        inactiveColor = comp.map_object_marker__inactiveColor
        clampToBorder = comp.map_object_marker__clampToBorder
      })
    },
    onDestroy = function(eid, _comp){
      deleteEid(eid, mapObjectMarkers)
    }
  },
  {
    comps_ro = [
      ["map_object_marker__iconName", ecs.TYPE_STRING],
      ["map_object_marker__iconInactiveName", ecs.TYPE_STRING, ""],
      ["map_object_marker__iconCompleteName", ecs.TYPE_STRING, ""],
      ["map_object_marker__tooltip", ecs.TYPE_STRING, ""],
      ["map_object_marker__complete_tooltip", ecs.TYPE_STRING, ""],
      ["objective_static_target__tag", ecs.TYPE_STRING, null],
      ["map_object_marker__tag", ecs.TYPE_STRING, null],
      ["map_object_marker__activeColor", ecs.TYPE_POINT3, Point3(255, 255, 255)],
      ["map_object_marker__hoverColor", ecs.TYPE_POINT3, Point3(200, 255, 200)],
      ["map_object_marker__inactiveColor", ecs.TYPE_POINT3, Point3(100, 100, 100)],
      ["map_object_marker__clampToBorder", ecs.TYPE_BOOL, true],
      ["transform", ecs.TYPE_MATRIX]
    ],
    comps_track = [
      ["map_object__show", ecs.TYPE_BOOL],
      ["map_object_marker__isActive", ecs.TYPE_BOOL, true],
      ["map_object_marker__isComplete", ecs.TYPE_BOOL, false],
      ["map_object__parentContainerEid", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID]
    ]
  }
)

ecs.register_es("map_object_zones_ui_es",
  {
    [["onChange", "onInit"]] = function(eid, comp){
      if (!comp.map_object__show) {
        deleteEid(eid, mapObjectZones)
        return
      }
      mapObjectZones.mutate(@(v) v[eid] <- {
        pos = comp.transform[3],
        objectiveTag = comp.objective_static_target__tag
        radius = comp.map_object_zone__radius,
        enabled = comp.map_object__show
      })
    },
    onDestroy = function(eid, _comp){
      deleteEid(eid, mapObjectZones)
    }
  },
  {
    comps_ro = [
      ["transform", ecs.TYPE_MATRIX],
      ["objective_static_target__tag", ecs.TYPE_STRING],
      ["map_object_zone__radius", ecs.TYPE_FLOAT]
    ],
    comps_track = [
      ["map_object__show", ecs.TYPE_BOOL]
    ]
  }
)

ecs.register_es("map_object_zones_with_override_ui_es",
  {
    [["onChange", "onInit"]] = function(eid, comp){
      if (!comp.map_object__show) {
        deleteEid(eid, mapObjectZones)
        return
      }
      mapObjectZones.mutate(@(v) v[eid] <- {
        pos = comp.map_object_zone__overridePos,
        objectiveTag = comp.objective_dynamic_target__tag
        radius = comp.map_object_zone__radius,
        enabled = comp.map_object__show
      })
    },
    onDestroy = function(eid, _comp){
      deleteEid(eid, mapObjectZones)
    }
  },
  {
    comps_ro = [
      ["objective_dynamic_target__tag", ecs.TYPE_STRING],
      ["map_object_zone__radius", ecs.TYPE_FLOAT]
    ],
    comps_track = [
      ["map_object__show", ecs.TYPE_BOOL],
      ["map_object_zone__overridePos", ecs.TYPE_POINT3]
    ]
  }
)


ecs.register_es("hunter_vision_targets_ui_es",
  {
    [["onChange", "onInit"]] = function(eid, comp){
      let hero = $"{watchedHeroEid.get()}"
      let curTime = get_sync_time()
      if ((comp.hunter_vision_target__keepFxUntil?[hero] ?? 0.0) > curTime)
        hunter_vision_targets.mutate(@(v) v[eid] <- true)
    },
    onDestroy = function(eid, _comp){
      deleteEid(eid, hunter_vision_targets)
    }
  },
  {
    comps_track = [["hunter_vision_target__keepFxUntil", ecs.TYPE_OBJECT]]
  }
)

ecs.register_es("hunter_vision_targets_update_ui_es",
  {
    onUpdate = function(eid, comp){
      let hero = $"{watchedHeroEid.get()}"
      let curTime = get_sync_time()
      if ((comp.hunter_vision_target__keepFxUntil?[hero] ?? 0.0) > curTime){
        if (!(eid in hunter_vision_targets.get()))
          hunter_vision_targets.mutate(@(v) v[eid] <- true)
      }
      else{
        if (eid in hunter_vision_targets.get())
          deleteEid(eid, hunter_vision_targets)
      }
    }
  },
  {
    comps_ro = [["hunter_vision_target__keepFxUntil", ecs.TYPE_OBJECT]]
  },
  { updateInterval = 1, after="*", before="*" }
)

ecs.register_es("hunter_minion_marker_es",
  {
    ["onInit"] = function(eid, comp) {
      if (comp.minion_creature__masterEid != ecs.INVALID_ENTITY_ID && comp.minion_creature__masterEid == watchedHeroEid.get())
        hunter_minions.mutate(@(v) v[eid] <- true)
    }
    onDestroy = function(eid, _comp) {
      hunter_minions.mutate(@(v) v.rawdelete(eid))
    }
  },
  {
    comps_ro = [["minion_creature__masterEid", ecs.TYPE_EID]]
    comps_no = ["deadEntity"]
  },
  { updateInterval = 1, after="*", before="*" }
)


return{
  visible_interactables
  secretLootables
  mapObjectMarkers
  mapObjectZones
  game_trigger_markers
  hunter_vision_targets
  hunter_minions
}
