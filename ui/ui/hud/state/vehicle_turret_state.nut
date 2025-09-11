import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let {watchedHeroEid} = require("%ui/hud/state/watched_hero.nut")
let {inTank, isPassenger} = require("%ui/hud/state/vehicle_state.nut")
let {get_gun_template_by_props_id} = require("dm")
let {EventOnSeatOwnersChanged} = require("dasevents")

let vehicleTurrets = Watched({turrets = []})
let turretsReload = Watched({})
let turretsAmmo = Watched({})
let turretsReplenishment = Watched({})

let function resetState() {
  vehicleTurrets.set({turrets = []})
}

let turretQuery = ecs.SqQuery("turretQuery", {
  comps_ro=[
    ["gun__propsId", ecs.TYPE_INT, -1],
    ["gun__reloadable", ecs.TYPE_BOOL, false],
    ["turret__groupName", ecs.TYPE_STRING, ""],
    ["turretInput", ecs.TYPE_TAG, null],
    ["currentBulletId", ecs.TYPE_INT, 0],
    ["nextBulletId", ecs.TYPE_INT, -1],
    ["turret__triggerGroup", ecs.TYPE_INT, -1],
    ["gun__ammoSetsInfo", ecs.TYPE_SHARED_ARRAY, null],
    ["gun__shellsAmmo", ecs.TYPE_ARRAY, []],
    ["turret_input__isLocalControlLocked", ecs.TYPE_BOOL, false],
    ["turret__disableAim", ecs.TYPE_TAG, null],
    ["turret__hideCrosshair", ecs.TYPE_BOOL, false]
  ]
})

let function get_trigger_mappings(hotkeys) {
  let mappings = {}
  foreach(mapping in hotkeys) {
    let name = mapping?.name
    let hotkey = mapping?.hotkey
    if (name != null && hotkey != null)
      mappings[name] <- hotkey
  }
  return mappings
}

let getAmmoSets = @(_, comp)
  (comp["gun__ammoSetsInfo"]?.getAll() ?? []).map(@(set, setInd) { name=set?[0]?.name ?? "", type=set?[0]?.type ?? "", maxAmmo = comp["gun__shellsAmmo"]?[setInd] ?? 0 })

let function initTurretsState(eid, comp) {
  let hero = watchedHeroEid.get()
  if (eid != ecs.obsolete_dbg_get_comp_val(hero, "human_anim__vehicleSelected")) {
    resetState()
    return
  }

  let turretsByGroup = {}

  let triggerMappingComp = comp["turret_control__triggerMapping"]?.getAll() ?? []
  let triggerMappings = get_trigger_mappings(triggerMappingComp)
  let turretInfo = comp["turret_control__turretInfo"]

  foreach (gIndex, gEid in comp["turret_control__gunEids"]) {
    let gunIndex = gIndex
    let gunEid = gEid
    turretQuery.perform(gunEid, function(_,gunComp) {
      let gunPropsId = gunComp["gun__propsId"]
      let gunTplName = get_gun_template_by_props_id(gunPropsId)
      let gunTpl = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(gunTplName ?? "")
      let trigger = turretInfo?[gunIndex]?.trigger

      let turret = {
        isMain = false
        gunEid = gunEid
        gunPropsId = gunPropsId
        name = gunTpl?.getCompValNullable("item__name")
        currentAmmoSetId = gunComp["currentBulletId"]
        nextAmmoSetId = gunComp["nextBulletId"]
        isReloadable = gunComp["gun__reloadable"]
        icon = gunTpl?.getCompValNullable("gun__icon")
        isControlled = gunComp["turretInput"] != null
        isBomb = trigger == "bombs"
        isRocket = trigger == "rockets"
        hotkey = triggerMappings?[trigger]
        triggerGroup = gunComp["turret__triggerGroup"]
        groupName = gunComp["turret__groupName"]
        isWithSeveralShells = gunComp["nextBulletId"] != -1
        ammoSet = getAmmoSets(gunEid, gunComp)
        showCrosshair = gunComp.turret__disableAim == null && !gunComp["turret__hideCrosshair"]
        isLocalControlLocked = gunComp["turret_input__isLocalControlLocked"]
      }
      let groupName = turret.groupName
      if (turretsByGroup?[groupName] == null)
        turretsByGroup[groupName] <- []
      turretsByGroup[groupName].append(turret)
    })

    if (turretsByGroup?[""][0].isMain != null)
      turretsByGroup[""][0].isMain = true

    let turrets = []
    foreach (group, turretsInGroup in turretsByGroup)
      if (group != "") {
        let mainTurretInGroup = turretsInGroup[0]
        if (mainTurretInGroup.isBomb || mainTurretInGroup.isRocket)
          mainTurretInGroup.namesInGroup <-
            turretsInGroup.reduce(function(res, turret) { res[turret.gunEid] <- turret.name; return res }, {})
        turrets.append(mainTurretInGroup)
      } else
        turrets.extend(turretsInGroup)

    vehicleTurrets.set({
      turrets = turrets
    })
    let ammoState = comp["ui_turrets_state__ammo"]
    let turretEids = turrets.reduce(function(res, turret) { res[turret.gunEid] <- null; return res }, {})
    let turretGroups = turretsByGroup.map(@(_) null).filter(@(_, group) group != "")
    let ammoKeys = turretEids.__merge(turretGroups)
    turretsAmmo.set(ammoKeys.map(@(_, key) ammoState?[key.tostring()].getAll() ?? {}))
  }
}

ecs.register_es("vehicle_turret_input_state_es",
  {
    onInit = @(eid, _comp) vehicleTurrets.mutate(function(v) {
      let turretIdx = v.turrets.findindex(@(t) t.gunEid == eid)
      if (turretIdx != null) {
        v.turrets[turretIdx].isControlled = true
      }
      return v
    })
    onDestroy = @(eid, _comp) vehicleTurrets.mutate(function(v) {
      let turretIdx = v.turrets.findindex(@(t) t.gunEid == eid)
      if (turretIdx != null) {
        v.turrets[turretIdx].isControlled = false
      }
      return v
    })
  }
  {
    comps_rq = ["turretInput"]
  }
)

ecs.register_es("vehicle_turret_state_ui_es",
  {
    [["onInit", "onChange"]] = initTurretsState,
    [EventOnSeatOwnersChanged] = initTurretsState,
    onDestroy = @(...) resetState(),
  },
  {
    comps_ro = [
      ["ui_turrets_state__ammo", ecs.TYPE_OBJECT, null],
      ["turret_control__triggerMapping", ecs.TYPE_SHARED_ARRAY, null],
      ["turret_control__turretInfo", ecs.TYPE_SHARED_ARRAY],
    ]
    comps_track = [
      ["turret_control__gunEids", ecs.TYPE_EID_LIST],
      ["vehicle_seats__seatEids", ecs.TYPE_EID_LIST],
    ]
    comps_rq = ["vehicleWithWatched"]
  }
)

ecs.register_es("turret_ammo_ui_es",
  { [["onInit", "onChange"]] = function(_, comp) {
      let res = turretsAmmo.get().map(@(_, key)
        comp["ui_turrets_state__ammo"]?[key.tostring()].getAll())
      turretsAmmo.set(res)
    }
  },
  {
    comps_track = [["ui_turrets_state__ammo", ecs.TYPE_OBJECT]]
    comps_rq = ["vehicleWithWatched"]
  })

let turretsVehicleQuery = ecs.SqQuery("turretsVehicleQuery", {
  comps_ro = [
    ["ui_turrets_state__ammo", ecs.TYPE_OBJECT, null],
    ["turret_control__triggerMapping", ecs.TYPE_SHARED_ARRAY, null],
    ["turret_control__turretInfo", ecs.TYPE_SHARED_ARRAY],
    ["turret_control__gunEids", ecs.TYPE_EID_LIST],
    ["vehicle_seats__seatEids", ecs.TYPE_EID_LIST],
  ],
  comps_rq = ["vehicleWithWatched"]
})

ecs.register_es("track_controlled_turret_ui_es",
  { [["onInit", "onChange", "onDestroy"]] = function(_eid, comp) {
      turretsVehicleQuery(comp["turret__owner"], @(vehicleEid, vehicleComp) initTurretsState(vehicleEid, vehicleComp))
    }
  },
  {
    comps_track = [
      ["currentBulletId", ecs.TYPE_INT, 0],
      ["nextBulletId", ecs.TYPE_INT, 0],
    ]
    comps_ro = [["turret__owner", ecs.TYPE_EID]]
    comps_rq = ["turretInput"]
  }
)

ecs.register_es("turret_state_reload_progress_ui",
  { onChange = function(eid, comp) {
      turretsReload.mutate(@(t) t[eid] <- {
        progressStopped = comp["ui_turret_reload_progress__progressStopped"]
        endTime = comp["ui_turret_reload_progress__finishTime"]
        totalTime = comp["ui_turret_reload_progress__finishTime"] - comp["ui_turret_reload_progress__startTime"]
      })
    },
  },
  { comps_track = [
    ["ui_turret_reload_progress__startTime", ecs.TYPE_FLOAT],
    ["ui_turret_reload_progress__finishTime", ecs.TYPE_FLOAT],
    ["ui_turret_reload_progress__progressStopped", ecs.TYPE_FLOAT, -1],
  ],
    comps_rq = ["isTurret", "turretInput"]
  },
  {tags="ui"}
)

let showVehicleWeapons = Computed(@() inTank.get() ? (vehicleTurrets.get()?.turrets?.len() ?? 0) > 0 && !isPassenger.get() : (vehicleTurrets.get()?.turrets?.len() ?? 0) > 0)

let turrets       = Computed(@() vehicleTurrets.get()?.turrets ?? [])
let mainTurret    = Computed(@() turrets.get().findvalue(@(v) v?.isMain ?? false) ?? turrets.get()?[0])
let mainTurretEid = Computed(@() mainTurret.get()?.gunEid ?? ecs.INVALID_ENTITY_ID)

let turretAmmoSetsQuery = ecs.SqQuery("turretAmmoSetsQuery", { comps_ro=[["gun__ammoSetsInfo", ecs.TYPE_SHARED_ARRAY, null], ["gun__shellsAmmo", ecs.TYPE_ARRAY]] })

let mainTurretAmmoSets = Computed(@() turretAmmoSetsQuery.perform(mainTurretEid.get(), getAmmoSets) ?? [])
let mainTurretAmmo = Computed(@() turretsAmmo.get()?[mainTurretEid.get()])

return {
  vehicleTurrets
  turretsReplenishment
  showVehicleWeapons
  mainTurretEid
  mainTurretAmmoSets
  turretsReload
  turretsAmmo
  mainTurretAmmo
}
