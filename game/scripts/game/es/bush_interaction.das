require ecs
require DagorMath
require Dacoll
require CollRes
require RendInst
require game.events.events
require DngHuman
require DagorMath
require PhysMat
require math.base
require net


def is_bush(collres : CollisionResource; bush_material : int)
  let nodesCount = collres |> collres_get_nodesCount()
  let desiredMatId = int16(bush_material)
  for i in range(nodesCount)
    let collNode = collres |> collres_get_node(i)
    let matId = collNode.physMatId
    if matId == desiredMatId
      return true
  return false


[es(REQUIRE_NOT=disableUpdate)]
def detect_bushes(update : CmdPostPhysUpdate;
                  human_net_phys : HumanActor;
                  bush_detraction__bushMaterial : int;
                  var bush_detraction__isInBushes : bool&)
  let matIdTorso = human_net_phys.phys.previousState.torsoContactMatId
  bush_detraction__isInBushes = matIdTorso == bush_detraction__bushMaterial


def process_bush_interaction(collres : CollisionResource;
                             bush_detraction__bushMaterial : int;
                             bush_detraction__traceMaterial : int;
                             bushBb : BBox3;
                             bushPos : float3;
                             minPower : float;
                             maxPower : float;
                             powerPower : float;
                             heroHeight : float;
                             heroCollres : CollisionResource;
                             transform : float3x4;
                             dt : float;
                             var human_net_phys : HumanActor)
  if !is_bush(collres, bush_detraction__bushMaterial)
    return

  assume state = human_net_phys.phys.currentState
  let bushBbSize = bushBb.boxMax - bushBb.boxMin
  if heroHeight < bushBbSize.y // high bush
    let heroPos = transform[3]
    let maxDistance = max(0.01, min(bushBbSize.x, bushBbSize.z))
    let directionFromBush = normalize(heroPos - bushPos)
    let up = state.vertDirection
    let upProjection = dot(up, directionFromBush) * up
    let horizontalProjection = directionFromBush - upProjection
    let distanceNorm = length(heroPos.xz - bushPos.xz) / maxDistance
    let power = minPower + (maxPower - minPower) * pow(1.0 - distanceNorm, powerPower)

    let deltaMovement = power * horizontalProjection * dt
    let distSq = length_sq(deltaMovement)
    if distSq > 1e-6
      let curPos = transform[3]
      let dist = sqrt(distSq)
      let traceDir = deltaMovement / dist
      let traceDist = dist + heroCollres.boundingSphereRad
      // trace to make sure we are not being pushed into a wall.
      // Don't trace at curPos as its generally and its ok to step a bit up the slope
      let traceOffsets = fixed_array<float3>(float3(0.0, heroHeight / 3.0, 0.0), float3(0.0, heroHeight / 3.0 * 2.0, 0.0))

      for offset in traceOffsets
        let traceStart = curPos + offset
        if rayhit_normalized(traceStart, traceDir, traceDist, ETF_DEFAULT, bush_detraction__traceMaterial)
          return
      human_net_phys.phys.currentState.location.P += DPoint3(deltaMovement)


[es(after=detect_bushes, REQUIRE_NOT=disableUpdate)]
def detract_from_bushes(update : CmdPostPhysUpdate;
                        collres : CollisionResource;
                        isAlive : bool;
                        human_net_phys__isInAir : bool;
                        bush_detraction__minMaxPower : float3;
                        bush_detraction__isInBushes : bool;
                        bush_detraction__bushMaterial : int;
                        bush_detraction__traceMaterial : int;
                        var human_net_phys : HumanActor)
  if human_net_phys__isInAir || !isAlive
    return
  if !bush_detraction__isInBushes
    return

  assume state = human_net_phys.phys.currentState
  var transform : float3x4
  location_toTM(human_net_phys.phys.previousState.location, transform)
  let bbox3 = transform * BBox3(collres.vFullBBox)
  var box : bbox3f
  box.bmin = float4(bbox3.boxMin, 1.0)
  box.bmax = float4(bbox3.boxMax, 1.0)
  let heroHeight = human_net_phys.phys.standingHeight * cvt(state.height, -1.0, 1.0, 0.0, 1.0)
  let minPower = bush_detraction__minMaxPower.x
  let maxPower = bush_detraction__minMaxPower.y
  let powerPower = bush_detraction__minMaxPower.z

  rendinst_foreachInBox(bbox3, int(GatherRiTypeFlags.RiGenAndExtra)) <| $ [unused_argument(is_tm)] (desc : RendInstDesc; tm : float3x4; is_tm : bool)
    if !desc.isValid
      return
    let bushCollres = getRiGenCollisionResource(desc)
    if bushCollres == null
      return
    let bushBbox = getRIGenBBox(desc)
    process_bush_interaction(*bushCollres,
                             bush_detraction__bushMaterial,
                             bush_detraction__traceMaterial,
                             bushBbox,
                             tm[3],
                             minPower,
                             maxPower,
                             powerPower,
                             heroHeight,
                             collres,
                             transform,
                             update.dt,
                             human_net_phys)


[es(track=bush_detraction__isInBushes, tag=server)]
def manage_bushes_effects(evt : Event; eid aka human_eid : EntityId; bush_detraction__isInBushes : bool)
  var effectEid = INVALID_ENTITY_ID
  find_query() <| $ [es(REQUIRE=human_in_bushes_effect)] (eid aka effect_eid : EntityId; game_effect__attachedTo : EntityId)
    if game_effect__attachedTo != human_eid
      return false
    effectEid = effect_eid
    return true

  if !bush_detraction__isInBushes
    destroyEntity(effectEid)
  else
    if effectEid != INVALID_ENTITY_ID
      return
    createEntity("human_in_bushes_effect") <| $(var init)
      set(init, "game_effect__attachedTo", eid)


[es(on_appear)]
def human_init_bush_material(evt : Event;
                             bush_detraction__bushMaterialName : string;
                             bush_detraction__traceMaterialName : string;
                             var bush_detraction__bushMaterial : int&;
                             var bush_detraction__traceMaterial : int&)
  bush_detraction__bushMaterial = get_material_id(bush_detraction__bushMaterialName)
  bush_detraction__traceMaterial = get_material_id(bush_detraction__traceMaterialName)