require ecs
require math.base
require DagorRandom
require DagorSystem

[es(tag=server, REQUIRE_NOT=(activeEncounterGen, finishedEncounterGen), on_appear)]
def on_encounter_gen_created(evt : Event; eid : EntityId; var encounter_gen__pos : Point3List; transform : float3x4; var encounter_gen__norm : Point3List?;
                             encounter_gen__templateToSpawn : string; var encounter_gen__numToSpawn : int&; encounter_gen__minDst : float = .0)
  var spawnedPos : array<float3>
  let minDstSq = square(encounter_gen__minDst)
  var maxAttempts = encounter_gen__numToSpawn * 4
  while length(encounter_gen__pos) > 0 && encounter_gen__numToSpawn > 0 && maxAttempts > 0
    let idx = grnd() % length(encounter_gen__pos)

    var success = true
    for p in spawnedPos
      if distance_sq(p, encounter_gen__pos[idx]) < minDstSq
        maxAttempts--
        success = false
        if maxAttempts <= 0
          logerr("Encounter gen {eid}<{getEntityTemplateName(eid)}> couldn't finish spawning entities, they are too close to each other. dst:{encounter_gen__minDst} spawns left: {encounter_gen__numToSpawn}. Probably need more spawn positions.")
          return
        break
    if !success
      continue

    createEntity(encounter_gen__templateToSpawn) <| $(var init : ComponentsInitializer)
      let tm = get_tm(idx, transform, encounter_gen__pos, encounter_gen__norm)
      erase(encounter_gen__pos, idx)
      if encounter_gen__norm != null
        erase(*encounter_gen__norm, idx)
      set(init, "transform", tm)
      if encounter_gen__minDst > .0
        spawnedPos |> push(tm[3])
      encounter_gen__numToSpawn--
  if encounter_gen__numToSpawn > 0
    logerr("Encounter gen {eid}<{getEntityTemplateName(eid)}> does not have enough spawn points. Need at least {encounter_gen__numToSpawn} more.")

def get_tm(idx : int; transform : float3x4; var encounter_gen__pos : Point3List; var encounter_gen__norm : Point3List?)
  var tm = IDENT_TM
  tm[3] = encounter_gen__pos[idx]
  if encounter_gen__norm == null
    return tm
  let n = (*encounter_gen__norm)[idx]
  tm[1] = n
  tm[2] = cross(float3(0, 1, 0), n)
  tm[0] = cross(n, tm[2])
  tm = tm * transform
  return tm