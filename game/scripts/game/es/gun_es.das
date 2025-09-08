require ecs
require Gun
require math.base
require DagorSystem
require DagorRandom
require DaWeapons
require DagorMath
require DaWeaponProps
require DngNet
require BallisticsProps
require game.events.events_game

struct GunUpdateInput
  atTime : float
  isForReal : bool
  gunEid : EntityId
  offenderEid : EntityId
  pointVel : float3
  curGunPropsId : int
  shellIndexInSet : int
  extraDeviation : float
  zeroingAngle : float
  projectileVelocityMult : float

def private init_ammo_set(ammo_set__shellIds : IntList; gun__shell_prop_ids : GunShellPropIds; var ammo_set_indices : array<int>&)
  let shellPropsSize = length(gun__shell_prop_ids)
  for shellInd in ammo_set__shellIds
    if shellInd < shellPropsSize
      ammo_set_indices |> push(shellInd)

def private gun_launch(ld : LaunchDesc; gun_eid : EntityId;  offender_eid : EntityId)
  var ok = false
  shell_entity_get_props(int(ld.shellId.shellId)) <| $(entProps : ShellEntityTypeProps)
    let physTemplName = entProps.physTemplName
    if !empty(physTemplName)
      ok = true
      sendEventImmediate(offender_eid, CmdLaunchShell(launchDesc = ld, gunEid = gun_eid))
  if !ok
    projectile_get_props(int(ld.shellId.shellId)) <| $ [unused_argument(_)] (_ : ProjectileProps)
      ok = true
      sendEventImmediate(offender_eid, CmdLaunchProjectile(launchDesc = ld, gunEid = gun_eid))
  return ok

def private gun_launch(var gun : Gun&;
                       input : GunUpdateInput;
                       var num_shells : int&;
                       shot_time : float;
                       correction_time : float;
                       curShellId : ShellPropIds;
                       ammo_set_indices : array<int>;
                       // Can be null if length(ammo_set_indices) == 0
                       gun__shell_prop_ids : GunShellPropIds const ?;
                       rnd_seed : int)
  if int(curShellId.shellId) < 0
    return false

  if !input.isForReal // no-side effects (i.e. callbacks) on AAS apply
    return true

  if num_shells == 0
    return false

  if !has(input.offenderEid, "infiniteAmmo")
    --num_shells

  assume state = gun.curState
  assume prevState = gun.prevState
  var spreadSettings = SpreadSettings(uninitialized)
  gun_getSpreadSettings(gun, state, spreadSettings)

  var launchTm = state.shootTm
  if correction_time > 1e-6f // handle case of shooting between phys frames
    let prevQuat = DagorMath::quat(prevState.shootTm)
    let curQuat = DagorMath::quat(state.shootTm)
    assert(input.atTime > state.atTime)
    let alpha = correction_time / (input.atTime - state.atTime)
    make_tm(normalize(slerp(prevQuat, curQuat, alpha)), launchTm)
    launchTm[3] = lerp(prevState.shootTm.[3], state.shootTm[3], float3(alpha))

  var disableShellEjection = false
  if is_server()
    query(input.gunEid) <| $ [es] (gun_jamming__jamChance : float;
                                   gun__owner : EntityId;
                                   var gun_jamming__isJammed : bool&)
      var isSkipJamming = false
      query(gun__owner) <| $ [es] (possessedByPlr : EntityId const?;
                                   am_militant_bot : Tag const?)
        isSkipJamming = possessedByPlr == null || *possessedByPlr == INVALID_ENTITY_ID
        isSkipJamming ||= am_militant_bot != null
      if isSkipJamming
        return

      var seed = rnd_seed
      let rnd = _rnd_float(seed, 0.0, 1.0)
      gun_jamming__isJammed = rnd < gun_jamming__jamChance
      disableShellEjection = gun_jamming__isJammed

  let ammoSetSize = length(ammo_set_indices)
  let shellId = ammoSetSize > 0 ? (*gun__shell_prop_ids)[ammo_set_indices[input.shellIndexInSet % ammoSetSize]].shellId : curShellId.shellId
  shell_start_get_props(int(shellId)) <| $(shellStartProps : ShellStartProps)
    let dir = calc_projectile_dir(spreadSettings, gun.gunProps.spread, shellStartProps.spread, launchTm, state.randSeed,
      shellStartProps.pitch + input.zeroingAngle)
    let vel = dir * shellStartProps.speed * (1.f + _srnd(state.randSeed) * shellStartProps.speedDispersion) * input.projectileVelocityMult + input.pointVel
    var evt = EventShot()
    evt.launchDesc.shellId = ammoSetSize > 0 ? (*gun__shell_prop_ids)[ammo_set_indices[input.shellIndexInSet % ammoSetSize]] : curShellId
    evt.launchDesc.gunPropsId = int16(input.curGunPropsId)
    evt.launchDesc.atTime = shot_time
    evt.launchDesc.initialLifeTime = correction_time
    evt.launchDesc.tm = launchTm
    evt.launchDesc.vel = vel
    evt.launchDesc.firingMode = uint(state.firingMode)
    evt.launchDesc.bombBayHeight = state.bombBayHeight
    evt.launchDesc.disableShellEjection = disableShellEjection
    if gun_launch(evt.launchDesc, input.gunEid, input.offenderEid)
      sendEventImmediate(input.gunEid, evt)
  return true

def private gun_schedule_next_shot(var gun : Gun&; at_time : float; var rand_seed : int&)
  assume state = gun.curState
  assume firingMode = gun_getFiringMode(gun, int(state.firingMode))
  var timeBetweenShots = gun.gunProps.timeBetweenShots * firingMode.shotFreqMultiplier
  var boltActionTime = gun.gunProps.boltActionTime

  if firingMode.modeType == EFiringModeType.EFM_MANUAL && !firingMode.autoScheduleShots
    timeBetweenShots *= gun.appliedControls.boltActionMult
    boltActionTime *= gun.appliedControls.boltActionMult

  let physStep = 1.f / 30.f
  let dispK = 1.f + _srnd(rand_seed) * (physStep / 5.f)
  state.nextShotAtTime = at_time + timeBetweenShots * dispK
  state.boltActionEndAtTime = at_time + boltActionTime * dispK
  state.lastShotAtTime = at_time
  state.timeBetweenShots = timeBetweenShots

def private is_should_be_shot_dry(var gun : Gun&; num_shells : int; gun_eid : EntityId)
  var isJammed = false
  query(gun_eid) <| $[es] (gun_jamming__isJammed : bool)
    isJammed = gun_jamming__isJammed
  if gun.appliedControls.shoot && (num_shells == 0 || isJammed)
    return true
  return false

def private gun_update_shot_dry(var gun : Gun&; num_shells : int; gun_eid : EntityId)
  assume state = gun.curState
  if is_should_be_shot_dry(gun, num_shells, gun_eid)
    if state.atTime >= state.nextShotAtTime
      if state.atTime >= state.shotDryNextTime
        sendEventImmediate(gun_eid, EventShotDry())
      state.shotDryNextTime = state.atTime + gun.appliedControls.timeStep * 2.
  else
    state.shotDryNextTime = 0.

def private gun_update(var gun : Gun&;
                       var input : GunUpdateInput&;
                       var num_shells : int&;
                       rnd_seed : int;
                       gun__curShellId : ShellPropIds;
                       ammo_set_indices : array<int>;
                       gun__shell_prop_ids : GunShellPropIds const?)
  assume state = gun.curState
  state.randSeed = rnd_seed
  if input.isForReal
    gun_update_shot_dry(gun, num_shells, input.gunEid)
    let isShotDry = is_should_be_shot_dry(gun, num_shells, input.gunEid)
    if isShotDry
      state.isPrevAppliedControlShoot = gun.appliedControls.shoot
      state.atTime = input.atTime
      return

  assume firingMode = gun_getFiringMode(gun, int(state.firingMode))
  let shootOnRelease = firingMode.modeType == EFiringModeType.EFM_ONRELEASE
  let shootNextBurst = (firingMode.modeType == EFiringModeType.EFM_BURST &&
                        int(state.burstCounter) > 0 &&
                        int(state.burstCounter) < firingMode.burstSize &&
                        num_shells > 0)
  if shootNextBurst || (shootOnRelease ? state.isPrevAppliedControlShoot && !gun.appliedControls.shoot : gun.appliedControls.shoot)
    var fixedDt = gun.appliedControls.timeStep
    if fixedDt <= 0.f
      logerr("GunControls::syncTime <= 0 ({fixedDt}) in gun_update")
      fixedDt = 1.f / 30.f

    // if the gun was asleep for a while, it's possible that state.atTime <<< in.atTime
    // in this situation without the next line the gun will start shooting in a distant past
    state.atTime = max(state.atTime, input.atTime - fixedDt)

    while input.atTime >= state.nextShotAtTime && state.loaded
      var launchCorrectionTime = 0.f
      var shotTime = 0.f
      if state.atTime < state.nextShotAtTime
        launchCorrectionTime = state.nextShotAtTime - state.atTime
        if launchCorrectionTime > gun.gunProps.timeBetweenShots * firingMode.shotFreqMultiplier || launchCorrectionTime < 0.0
          launchCorrectionTime = 0.f
        shotTime = state.nextShotAtTime
      else
        shotTime = input.atTime
      if !gun_launch(gun, input, num_shells, shotTime, launchCorrectionTime, gun__curShellId, ammo_set_indices, gun__shell_prop_ids, rnd_seed)
        state.loaded = false
        break

      state.lastShotAtTime = shotTime
      input.shellIndexInSet++
      state.burstCounter = uint16(int(state.burstCounter) + 1)
      if firingMode.autoScheduleShots
        var atTime = state.lastShotAtTime
        if firingMode.modeType == EFiringModeType.EFM_AUTOMATIC && !state.isPrevAppliedControlShoot && gun.appliedControls.shoot // catch 1st
                                                                                                                                // shoot
          // Fix for gun updates launched between phys updates
          // align shooting interval start to phys tick end, but launch first shot immediately at this update
          // serverside updates already aligned to ticks, so we add 1e-3 tolerancy to don't change already aligned value
          atTime = ceil(atTime / fixedDt - 1e-3) * fixedDt // gamephys::ceilPhysicsTickNumber gives tick+1 for rounded number
        var seed = num_shells
        gun_schedule_next_shot(gun, atTime, seed)
      if !firingMode.autoScheduleShots || (firingMode.modeType == EFiringModeType.EFM_BURST && int(state.burstCounter) >= firingMode.burstSize)
        state.loaded = false
        break
  elif !firingMode.autoScheduleShots
    let haveShellInChamber = num_shells > 0 || (state.lastShotAtTime > state.boltActionEndAtTime)
    if state.nextShotAtTime < input.atTime && !state.loaded && haveShellInChamber
      var seed = num_shells
      gun_schedule_next_shot(gun, input.atTime, seed)
      state.loaded = true
  elif ((firingMode.modeType == EFiringModeType.EFM_BURST &&
        (int(state.burstCounter) == 0 || int(state.burstCounter) >= firingMode.burstSize || num_shells == 0)) ||
        firingMode.modeType == EFiringModeType.EFM_AUTOMATIC)
    state.burstCounter = uint16(0)
    state.loaded = true

  state.isPrevAppliedControlShoot = gun.appliedControls.shoot
  state.atTime = input.atTime


[es(before=gun_update_deviation)]
def gun_update_states(evt : CmdGunUpdate; var gun : Gun&)
  if !evt.isForReal
    return

  gun.prevState = gun.curState

  var shootTm : float3x4
  var gunTm : float3x4
  if evt.gloc.gunPos != null
    gun |> gun_calculate_shoot_tm(evt.gloc.gunShootDir, evt.gloc.gunPos, null, null, shootTm)
    gun |> gun_calculate_shoot_tm(evt.gloc.gunDir, evt.gloc.gunPos, null, null, gunTm)
  else
    let visTm : float3x4 const? = evt.gloc.visTm
    let physTm : float3x4 const? = evt.gloc.physTm
    gun |> gun_calculate_shoot_tm(evt.gloc.gunShootDir, null, visTm, physTm, shootTm)
    gun |> gun_calculate_shoot_tm(evt.gloc.gunDir, null, visTm, physTm, gunTm)

  gun.curState.gunTm = gunTm
  gun.curState.shootTm = shootTm


[es(before=gun_update_es)]
def gun_update_deviation(evt : CmdGunUpdate;
                         gun__owner : EntityId;
                         gun_deviation__shotTau : float;
                         gun_deviation__bufferThreshold : float;
                         gun_deviation__omegaRange : float2;
                         gun_deviation__omegaDevInc : float2;
                         gun_deviation__movementRange : float2;
                         gun_deviation__movementDevInc : float2;
                         gun_deviation__extraDeviationTau : float;
                         gun_deviation__maxDeviation : float;
                         gun_deviation__minDeviation : float;
                         gun_deviation_ct__movement : float2;
                         gun_deviation_ct__tauMult : float;
                         gun_deviation_ct__rotationShotSpreadDecrMult : float;
                         gun_deviation_ct__aimingAfterFireMult : float;
                         gun_deviation_ct__minExtraDev : float;
                         var gun_deviation_ct__gunDir : float3&;
                         var gun_deviation_ct__isShot : bool&;
                         var gun_deviation_state__atTime : float&;
                         var gun_deviation_state__unspentDeviation : float&;
                         var gun_deviation_state__extraDeviation : float&;
                         var gun_deviation_state__gunDir : float3&;
                         var gun_deviation_state__bufferDeviation : float&;
                         var gun : Gun&)
  if !evt.isForReal
    return

  var movementDeviationMult = 1.0
  query(gun__owner) <| $ [es] (entity_mods__movementShotSpreadDecrMult : float)
    movementDeviationMult = entity_mods__movementShotSpreadDecrMult

  gun_deviation_ct__gunDir = gun.curState.gunTm[0]
  gun_deviation_ct__isShot = evt.gctrl.shoot

  var dt = evt.atTime - gun_deviation_state__atTime
  if dt < 0.0
    logwarn("gun_update_deviation: prevTime {gun_deviation_state__atTime} is > curTime {evt.atTime}")
    dt = 0.0
  gun_deviation_state__atTime = evt.atTime

  assume unspentDeviation = gun_deviation_state__unspentDeviation
  let prevUnspent = unspentDeviation
  assume extraDeviation = gun_deviation_state__extraDeviation
  unspentDeviation = approach(prevUnspent, 0.0, dt, gun_deviation__shotTau)
  extraDeviation += prevUnspent - unspentDeviation

  let dirDot = dot(gun_deviation_ct__gunDir, gun_deviation_state__gunDir)
  assume bufferDeviation = gun_deviation_state__bufferDeviation
  bufferDeviation += is_equal_float(dirDot, 1.0) ? 0.0 : rad_to_deg(safe_acos(dirDot))
  let dAngle = max(bufferDeviation - gun_deviation__bufferThreshold, 0.0)

  assume omegaRange = gun_deviation__omegaRange
  assume omegaDevInc = gun_deviation__omegaDevInc
  assume movementRange = gun_deviation__movementRange
  assume movementDevInc = gun_deviation__movementDevInc
  extraDeviation += dAngle * cvt(dAngle, omegaRange.x * dt, omegaRange.y * dt, omegaDevInc.x, omegaDevInc.y)
  let moveSpd = min(length(gun_deviation_ct__movement), gun_deviation__movementRange.y)
  let moveSpdCvt = cvt(moveSpd, movementRange.x, movementRange.y, movementDevInc.x, movementDevInc.y)
  extraDeviation += moveSpd * moveSpdCvt * dt * movementDeviationMult

  gun_deviation_state__gunDir = gun_deviation_ct__gunDir

  var devVisc = gun_deviation__extraDeviationTau
  devVisc *= gun_deviation_ct__tauMult * gun_deviation_ct__rotationShotSpreadDecrMult
  if gun_deviation_ct__isShot
    devVisc *= gun_deviation_ct__aimingAfterFireMult

  bufferDeviation = approach(min(bufferDeviation, gun_deviation__bufferThreshold), 0.0, dt, devVisc)
  extraDeviation = max(
    gun_deviation_ct__minExtraDev,
    approach(min(extraDeviation, gun_deviation__maxDeviation), gun_deviation__minDeviation, dt, devVisc)
  )
  gun.curState.extraDeviation = float2(extraDeviation)


[es]
def gun_update_es(evt : CmdGunUpdate;
                  eid : EntityId;
                  gun__owner : EntityId;
                  gun__maxAmmo : int;
                  gun__salt : int;
                  gun__propsId : int;
                  gun__curShellId : ShellPropIds;
                  var gun__ammo : int&;
                  var gun : Gun&;
                  gun__offender : EntityId const?;
                  gun__shell_prop_ids : GunShellPropIds const?;
                  ammo_set__shellIds : IntList const?;
                  gun__zeroingAngle : float = 0.;
                  gun__projectileVelocityMult : float = 1.;
                  gun__ignoreWeaponVelocity : bool = false;
                  gun_deviation_state__extraDeviation = 0.0)
  // do not update gun shoot in replay, otherwise two shots will be visible
  let isReplay = find_query() <| $ [es(REQUIRE=replayIsPlaying)] => true
  if isReplay
    return

  let gloc = evt.gloc
  gun.appliedControls = evt.gctrl

  var gunIn = GunUpdateInput()
  gunIn.atTime = evt.atTime
  gunIn.isForReal = evt.isForReal
  gunIn.gunEid = eid
  gunIn.offenderEid = !!gun__owner ? gun__owner : (gun__offender != null ? *gun__offender : eid)
  gunIn.pointVel = !gun__ignoreWeaponVelocity ? (gloc.gunVel ?? float3()) : float3()
  gunIn.curGunPropsId = gun__propsId
  gunIn.extraDeviation = gun_deviation_state__extraDeviation
  gunIn.zeroingAngle = gun__zeroingAngle
  gunIn.projectileVelocityMult = gun__projectileVelocityMult

  var curShellId = -1
  var ammo_set_indices : array<int>
  if ammo_set__shellIds != null && gun__shell_prop_ids != null
    if length(*ammo_set__shellIds) == 1
      let shellId = (*ammo_set__shellIds)[0]
      if shellId < length(*gun__shell_prop_ids)
        curShellId = shellId
    else
      init_ammo_set(*ammo_set__shellIds, *gun__shell_prop_ids, ammo_set_indices)
      let shellNumber = max(0, gun__maxAmmo - gun__ammo)
      gunIn.shellIndexInSet = shellNumber % max(1, length(ammo_set_indices))

  let rndSeed = evt.seed ^ gun__salt // For perfecting sync
  gun_update(gun, gunIn, gun__ammo,
             rndSeed, curShellId < 0 ? gun__curShellId : (*gun__shell_prop_ids)[curShellId],
             ammo_set_indices, gun__shell_prop_ids)


[es(on_event=EventShot)]
def gun_update_deviation_on_shot(evt : Event;
                                 gun_deviation__onShotDeviationChange : float;
                                 var gun_deviation_state__unspentDeviation : float&)
  gun_deviation_state__unspentDeviation += gun_deviation__onShotDeviationChange
