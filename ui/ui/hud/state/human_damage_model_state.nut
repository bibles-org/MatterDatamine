from "math" import floor
from "dm" import DM_MELEE, DM_BACKSTAB, DM_PROJECTILE, DM_EXPLOSION, DM_ZONE, DM_COLLISION, DM_HOLD_BREATH, DM_FIRE, DM_BARBWIRE, DM_GAS
from "dasevents" import CmdMusicPlayerStop

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let bodyParts = mkWatched(persist, "bodyParts", {})
let bodyPartsIsDamaged = mkWatched(persist, "bodyPartsIsDamaged", false)
let curHp = mkWatched(persist, "curHp")
let fullHp = mkWatched(persist, "fullHp")

let getPossessedPartsQuery = ecs.SqQuery("getPossessedPartsQuery", {
  comps_rq = [["watchedByPlr"]],
  comps_track = [
    ["human_damage_model__partName", ecs.TYPE_STRING_LIST],
    ["human_damage_model__partHp", ecs.TYPE_FLOAT_LIST],
    ["human_damage_model__partInjured", ecs.TYPE_BOOL_LIST],
  ],
  comps_ro = [
    ["human_damage_model__parts", ecs.TYPE_OBJECT],
    ["human_damage_model__partName", ecs.TYPE_STRING_LIST],
    ["human_damage_model__partHp", ecs.TYPE_FLOAT_LIST],
    ["human_damage_model__partInjured", ecs.TYPE_BOOL_LIST],
  ]
})

let currentPosName = Watched(null)
local posSavedForEid = ecs.INVALID_ENTITY_ID
let POSE_STAND = "pose_stand"
let POSE_CROUCH = "pose_crouch"
let POSE_CRAWL = "pose_crawl"
let POSE_DOWNED = "pose_crouch"
let poseNames = [POSE_STAND, POSE_CROUCH, POSE_CRAWL, POSE_DOWNED]


let damageTypeToLang = {
  [DM_MELEE] = "melee",
  [DM_BACKSTAB] = "melee",
  [DM_PROJECTILE] = "projectile",
  [DM_EXPLOSION] = "explosion",
  [DM_ZONE] = "zone",
  [DM_COLLISION] = "collision",
  [DM_HOLD_BREATH] = "suffocation",
  [DM_FIRE] = "fire",
  [DM_BARBWIRE] = "barbwire",
  [DM_GAS] = "bees"
}

function getMostDamagedPart(){
  return bodyParts.get().values().sort(@(a, b) ((a?.hp ?? 0) / max(1, a?.maxHp ?? 1)) <=> ((b?.hp ?? 0) / max(1, b?.maxHp ?? 1)))[0]
}

function calculateHp(hp){
  if (hp <= 0.0)
    return 0.0
  if (hp <= 1.0)
    return 1.0
  return floor(hp)
}

function update_body_parts_state(parts, parts_state = null){

  let obj = bodyParts.get()
  local sumMaxHp = 0.0
  local sumHp = 0.0

  foreach (name, newPartInfo in parts.getAll()){
    let newMaxHp = newPartInfo?.maxHp ?? 0.0
    let newHp = calculateHp(parts_state?[name]?.hp ?? 0.0)
    let oldHp = calculateHp(obj?[name]?.hp ?? 0.0)
    let partName = newPartInfo?.name ?? "unknown"
    let isInjured = parts_state?[name]?.injured ?? false

    sumMaxHp += newMaxHp
    sumHp += newHp

    if (newHp < oldHp) {
      anim_start($"{partName}_dmg_anim")
      ecs.g_entity_mgr.broadcastEvent(CmdMusicPlayerStop())
    }
    else if (newHp > oldHp)
      anim_start($"{partName}_heal_anim")

    obj[name] <- {
      hp = newHp
      maxHp = newMaxHp
      name = partName
      protection = newPartInfo?.protection
      isInjured
    }
  }

  bodyParts.set(obj)
  bodyParts.trigger()

  bodyPartsIsDamaged.set(sumHp < sumMaxHp)
  curHp.set(sumHp)
  fullHp.set(sumMaxHp)
}

let updateBodypartsState = function(_eid, comp) {
  let partNames = comp.human_damage_model__partName.getAll()
  let partHps = comp.human_damage_model__partHp.getAll()
  let partInjures = comp.human_damage_model__partInjured.getAll()
  if ((partNames.len() != partHps.len() || partHps.len() != partInjures.len()))
    return
  let partsState = partNames.map(@(v, i) [v, {
    hp = partHps[i],
    injured = partInjures[i]
  }]).totable()

  update_body_parts_state(comp.human_damage_model__parts, partsState)
}

let getPossessedParts = @(target) getPossessedPartsQuery.perform(target, updateBodypartsState)

function human_damage_model_state_track_possessed(_eid, comp){
  if (comp.is_local && comp.possessed != ecs.INVALID_ENTITY_ID)
    getPossessedParts(comp.possessed)
}


function human_damage_model_state_track_spec_hero(_eid, comp){
  if (comp.is_local && comp.specTarget != ecs.INVALID_ENTITY_ID)
    getPossessedParts(comp.specTarget)
}

ecs.register_es("human_damage_model_state_track_parts",
  {
    [["onInit", "onChange"]] = updateBodypartsState
  },
  {
    comps_rq = [["watchedByPlr"]]
    comps_ro = [["human_damage_model__parts", ecs.TYPE_OBJECT]]
    comps_track = [
      ["human_damage_model__partName", ecs.TYPE_STRING_LIST],
      ["human_damage_model__partHp", ecs.TYPE_FLOAT_LIST],
      ["human_damage_model__partInjured", ecs.TYPE_BOOL_LIST],
    ]
  }
)

ecs.register_es("human_damage_model_state_track_possessed",
  {
    [["onInit", "onChange"]] = human_damage_model_state_track_possessed
  },
  {
    comps_rq = [["player"]],
    comps_ro = [["is_local", ecs.TYPE_BOOL]],
    comps_track = [["possessed", ecs.TYPE_EID]]
  }
)

ecs.register_es("human_damage_model_state_track_spec_hero",
  {
    [["onInit", "onChange"]] = human_damage_model_state_track_spec_hero
  },
  {
    comps_ro = [["is_local", ecs.TYPE_BOOL]],
    comps_track = [["specTarget", ecs.TYPE_EID]]
  }
)

ecs.register_es("human_track_stand_pose",
  {
    [["onInit", "onChange"]] = function(eid, comps){
      if (comps.human_net_phys__standState >= 0 && comps.human_net_phys__standState < poseNames.len())
        currentPosName.set(poseNames[comps.human_net_phys__standState])
      else
        currentPosName.set(POSE_STAND)
      posSavedForEid = eid
    },
    [["onDestroy"]] = function(eid, _comps) {
      if (posSavedForEid == eid) {
        currentPosName.set(null)
        posSavedForEid = ecs.INVALID_ENTITY_ID
      }
    }
  },
  {
    comps_rq = ["watchedByPlr"],
    comps_track = [["human_net_phys__standState", ecs.TYPE_INT]]
  }
)

function getDamageTypeStr(damage_type){
  return damageTypeToLang?[damage_type] ?? "unknown"
}

return {
  bodyParts
  bodyPartsIsDamaged
  currentPosName
  getDamageTypeStr
  POSE_STAND,
  POSE_CROUCH,
  POSE_CRAWL,
  getMostDamagedPart,
  update_body_parts_state,
  fullHp,
  curHp,
}
