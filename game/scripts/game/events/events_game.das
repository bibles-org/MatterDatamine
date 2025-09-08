module events_game shared
require ecs
require Gun
require RendInst
require DagorMath
require rapidjson
require DaWeapons
require danetlibs.route_prober.main.net_events public
require danetlibs.native_dasevents.main.native_events public
require danetlibs.package_soldier.soldier_inventory_events public

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventEntityDied
  victim : EntityId
  offender : EntityId
  damageType : int
  gunPropsId : int
  shellId : int
  collNodeId : int
  victimTeam : int
  offenderTeam : int

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventAnyEntityDied
  victim : EntityId
  offender : EntityId
  offenderPlayer : EntityId
  victimPlayer : EntityId
  damageType : int
  gunPropsId : int
  shellId : int
  collNodeId : int
  victimTeam : int
  offenderTeam : int

[cpp_event(broadcast)]
struct EventEntityManagerBeforeClear {}

[event(broadcast)]
struct CmdClearAllAttachedUserPoint
  target : EntityId
  team : int

[event(unicast)]
struct CmdCollisionDamage
  damage : float
  pos : float3
  offender : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventEntityResurrected {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventEntityRevived
  reviveByTimer : bool

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct EventSpectateTarget
  target_eid : EntityId

[cpp_event(unicast)]
struct EventAnimIrq
  irqType : int

[cpp_event(unicast)]
struct EventAction
  actionIdx : int
  propsId : int

[event(unicast)]
struct GameEffectStateChanged // note: can be resended on recreate
  attachedTo : EntityId
  activated : bool

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EnableSpectatorForTarget
  player : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EnableSpectatorForPlayer
  target : EntityId// if invalid, the target will be decided on the client side

[cpp_event(unicast)]
struct CmdRendinstDamage
  handle : riex_handle_t
  damage : float
  pos : float3
  impulse : float3
  time : float

[event(unicast)]
struct EventRendinstOnProjectileHit
  projectile_eid : EntityId
  pos : float3
  impulse : float3
  time : float

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestRendinstDamage
  handle : riex_handle_t
  damage : float
  pos : float3
  impulse : float3
  time : float

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestRendinstEntityDamage
  eid : EntityId
  damage : float
  pos : float3
  impulse : float3
  time : float

[cpp_event(broadcast)]
struct EventRendinstDestroyed // server
  riexHandle : riex_handle_t
  riTm : float3x4
  riBBox : BBox3

[event(unicast)]
struct EventRendinstRotationFinished {}

[event(unicast)]
struct CmdSwitchCamera {}

[event(unicast)]
struct CmdSwitchCameraByEntity
  index : int
  camNamesEid : EntityId

[event(unicast)]
struct CmdSwitchCameraByIndex
  index : int

[event(broadcast)]
struct EventTeamMemberJoined
  eid : EntityId
  team : int

[event(unicast)]
struct CmdWeapSwitchSight
  toNext : bool

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct PossessHero // Possess/unposses entity
  possess : bool

[cpp_event(unicast)]
struct CmdSetSimplifiedPhys
  is_simplified : bool

[event(unicast)]
struct CmdPushPhys
  vel : float3
  push_immunity : float

[event(unicast)]
struct EventPlayerPossessedEntityDied
  victimEid : EntityId
  killerEid : EntityId
  deathDesc_damageTypeId : uint16
  victimPlayerEid : EntityId
  killerPlayerEid : EntityId

[event(unicast)]
struct FindNextReplayTarget
  direction : int

[event(unicast)]
struct SetNextReplayTarget
  newTarget : EntityId

[event(unicast)]
struct ChangeReplayCamera
  newCameraEid : EntityId

[event(unicast)]
struct CmdSpawnEntity
  tm : float3x4

[cpp_event(unicast)]
struct CmdApplyRagdollParameters
  cur_time : float

[event(unicast)]
struct EventOnItemGenerated {}

[cpp_event(broadcast)]
struct EventGameObjectsCreated
  game_objects : EntityId

[cpp_event(broadcast)]
struct EventGameObjectsEntitiesScheduled
  count : int

[event(unicast)]
struct EventEntityActivate
  activate : bool

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestSuicide {}

[cpp_event(broadcast)]
struct EventOnWriteReplayMetaInfo
  replayMeta : JsonDocument

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct RunActionCmd
  id : int
  overridePropsId : int
  overrideTime : float
  overrideAt : float
  actionPeriod : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct InterruptActionsCmd {}

[event(unicast)]
struct CmdSetCameraTarget
  target : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestCamSwitch
  isTpsView : bool

[cpp_event(unicast)]
struct CmdResetRotAnim
  firstKey : float4
  firstKeyTime : float
  animType : int

[cpp_event(unicast)]
struct CmdAddRotAnim
  firstKey : float4
  firstKeyTime : float
  useAdditionalTime : bool

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdDeleteMapUserPoint {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdCreateMapUserPoint
  pos : float3
  norm : float3
  item_name : string

[event(unicast)]
struct CmdCreateMapPoint
  x : float
  z : float

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdUseFlashlight {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdUseNightVisionDevice {}

[event(unicast)]
struct EventOnDamaged
  offender : EntityId
  damageType : int
  deltaHp : float
  hitPos : float3
  hitDir : float3

[cpp_event(broadcast, with_scheme, cpp_gen=false)]
struct EventOnEntityHit
  victim : EntityId
  offender : EntityId
  hitResult : int
  damageType : int
  shellId : int
  gunPropsId : int
  actionPropsId : int
  collNodeId : int
  deltaHp : float
  blockingDeltaHp : float
  stoppingPower : float
  hitPos : float3
  hitDir : float3
  hitNorm : float3
  dmgMult : float
  armorMult : float
  armorPenetration : float
  shatterCount : int
  causedBleeding : float

[cpp_event(unicast)]
struct CmdOnHeroHit
  damageType : int
  hitDir : float3
  collNodeId : int

[cpp_event(broadcast)]
struct HitBloodOnScreenRender
  direction : float3
  duration : float
  intensity : float
  hold : bool

[cpp_event(unicast)]
struct EventProjectileHitScene
  pos : float3
  shouldStop : bool
  ricochetAngle : float
  smokeTracerStop : bool
  rendinstCellIdx : int
  rendinstIdx : int
  rendinstPool : int
  rendinstOffs : uint
  rendinstLayer : int
  matId : int
  norm : float3
  allowDetonation : bool
  sceneIntersectionsExceeded : bool
  collType : int
  vel : float3
  riexHandle : riex_handle_t

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventEntityDowned
  offender : EntityId

[event(unicast)]
struct EventPlayerKilledEntity
  victimEid : EntityId
  killerEid : EntityId
  deathDesc_gunPropsId : int16
  deathDesc_collNodeId : int16
  deathDesc_damageTypeId : uint16
  victimPlayerEid : EntityId
  killerPlayerEid : EntityId

[event(unicast)]
struct EventZoneEnter
  visitorEid : EntityId

[event(unicast)]
struct EventZoneLeave
  visitorEid : EntityId

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdPutOutFireStart {}

[cpp_event(unicast)]
struct CmdWeapAttach
  toEid : EntityId
  isAttached : bool
  slotId : int

[event(unicast)]
struct CmdWeapDetach {}

[event(unicast)]
struct CmdDetachAttachedGun {}

[event(unicast)]
struct CmdSlotDetach {}

[cpp_event(unicast)]
struct CmdWeapPhysUpdate
  owner : EntityId
  atTime : float
  dt : float
  isForReal : bool
  slotId : int
  gctrl : GunControls
  gloc : GunLocation

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct HumanWeapThrowBackAbort {}

[cpp_event(unicast)]
struct HumanWeapSetCurrentGun
  slot : uint8

[event(broadcast)]
struct EventOnGunBlocksShoot
  reason : string

[cpp_event(unicast)]
struct EventOnShellExploded
  explPos : float3
  shellId : int16
  damageId : int16
  ballisticsId : int16
  gunPropsId : int
  owner : EntityId

[cpp_event(unicast)]
struct EventShellExplodedServer
  pos : float3

[cpp_event(unicast)]
struct CmdShellExplode
  position : float3
  prevPos : float3
  vel : float3

[cpp_event(unicast)]
struct CmdShellExplosionFx {}

[event(unicast)]
struct EventWeapOnReload {}

[event(unicast)]
struct CmdUnloadAmmo
  unloadAmmoCount : int

[event(unicast)]
struct CmdRequestReload
  atTime : float
  gunEid : EntityId
  minReloadAmmoCount : int

[event(unicast)]
struct CmdRequestFixJamming
  gunEid : EntityId

[event(unicast)]
struct CmdInterruptReloadImmediately {}

[cpp_event(unicast)]
struct CmdSetWishAmmoItemType
  slot_id : int
  item_id : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestQuickThrowGrenade
  grenade_ammo_id : int
  grenade_ammo_eid : EntityId

[event(unicast)]
struct CmdSetWishGrenadeType
  slot_id : int
  item_id : int
  try_take : bool
  wish_item : EntityId // only if try_take is true

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestSetWishGrenadeType
  slot_id : int
  item_id : int
  is_grenade_slot_current : bool
  try_take : bool
  wish_item : EntityId // only if try_take is true

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanRequestTakeGrenade {}

[cpp_event(unicast)]
struct EventShot
  launchDesc : LaunchDesc

[cpp_event(unicast)]
struct CmdNetShot
  shellId : int16
  damageId : int16
  ballisticsId : int16
  gunPropsId : int16
  atTime : float
  initialLifeTime : float
  tm : float3x4
  vel : float3
  firingMode : uint
  bombBayHeight : float

[cpp_event(unicast)]
struct CmdLaunchShell
  launchDesc : LaunchDesc
  gunEid : EntityId

[cpp_event(unicast)]
struct CmdLaunchProjectile
  launchDesc : LaunchDesc
  gunEid : EntityId

[cpp_event(broadcast)]
struct EventProjectileFlight
  prevPos : float3
  normalizedDir : float3
  dist : float
  isLocalOwner : bool

[cpp_event(unicast)]
struct CmdGunUpdate
  atTime : float
  isForReal : bool
  seed : int
  gctrl : GunControls
  gloc : GunLocation

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanWeapRequestSwitchFiringMode
  slotId : uint8
  modeId : uint8

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanAttachToGunRequest {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct HumanAttachToGunResponse
  gun_eid : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanDetachFromGunRequest {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct HumanDetachFromGunResponse {}

[event(unicast)]
struct HumanSwitchWeaponStarted {}

[event(unicast)]
struct HumanEquipStateWeaponEquipped
  slot : int

[event(unicast)]
struct HumanAttachToGunComplete
  gun_eid : EntityId

[event(unicast)]
struct HumanDetachFromGunComplete {}

[event(unicast)]
struct CmdHumanEndFreefall {}

[event(unicast)]
struct CmdTrackHeroWeapons {}

[event(unicast)]
struct CmdAddDefaultEntitiesInNetScopeForPlayer {}

[event(broadcast)]
struct EventSessionFinished {}

[cpp_event(unicast)]
struct CmdShellBeforeMove {}

[cpp_event(unicast)]
struct EventShotDry {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestStartThrowStone
  atTime : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventStartThrowStone
  atTime : float

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestScheduleStoneThrown
  transform : float3x4
  humanVelocity : float3
  humanPos : float3
  humanLookDir : float3
  atTick : int

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventScheduleStoneThrown
  transform : float3x4
  humanVelocity : float3
  humanPos : float3
  humanLookDir : float3
  atTick : int

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT, reliability=UNRELIABLE)]
struct EventSyncHeartRate
  value : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT, reliability=UNRELIABLE)]
struct EventSyncHandStamina
  value : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventHeartRateHpChange
  tick : int
  hp : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdHeartRateHpReset {}


[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdUpdateTransform
  tm : float3x4

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventRewardDailyContract
  statName : string
  reward : int