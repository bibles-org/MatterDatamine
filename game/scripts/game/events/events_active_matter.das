module events_active_matter shared
require ecs
require game.events.events_game
require DngWeapon
require DaWeapons
require CollisionTraces
require DngDm
require BitStream
require danetlibs.renderer.includes.pufd_events public


[event(broadcast)]
struct CmdEnableUi {}

[event(broadcast)]
struct CmdDisableUi {}

[event(broadcast)]
struct CmdNexusAddBots
  number : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct EventNexusPlayerLoaded {}

[event(unicast)]
struct EventEntityDamagedByFireZone
  zone : EntityId

[event(unicast)]
struct EventHealItemUsed {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdPlayMothmanIdleSound {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdMothmanAttack
  direction : float3
  position : float3
  shotAt : float
  objectEid : EntityId
  charged : bool

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdMothmanChannelAttack
  chargeAt : float
  objectEid : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdMothmanCancelAttack {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventUpdateMothmanAttackState
  isChanneling : bool
  chargedAt : float
  chosenObject : EntityId

[event(unicast)]
struct EventCorpseEaten {}

[event(unicast)]
struct EventCorpseSwarmRepelled
  repelPos : float3
  repelDuration : float

[event(unicast)]
struct EventDesiredHeroIrqHappened {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventUnlockAppear
  unlockName : string

[event(unicast)]
struct CmdStartMenuExtractionSequence {}

[event(unicast)]
struct CmdGenerateAnomalyZone {}

[event(unicast)]
struct ParachuteDeployStateChanged {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdNexusBattleSelectLoadout
  loadoutIndex : int
  selectAnyIfUnavailable : bool

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestNexusSpawnPlayer

[event(broadcast)]
struct EventNexusWholeTeamDied
  team : int

[event(unicast)]
struct CmdNexusSpawnPlayer
  playerEid : EntityId
  atTime : float
  replaceForced : bool
  destroyPreviousPossessed : bool

[event(unicast)]
struct CmdNexusSpawnAllPlayers
  atTime : float
  replaceForced : bool
  ignoreAlreadySpawned : bool
  destroyPreviousPossessed : bool

[event(unicast)]
struct CmdNexusDespawnAllPlayers {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdNexusStartSpawnSequence
  endAt : float

[event(unicast)]
struct CmdNexusLockShootingForPlayer {}

[event(unicast)]
struct CmdNexusUnlockShootingForPlayer {}

[event(unicast)]
struct CmdNexusLockInputForPlayer {}

[event(unicast)]
struct CmdNexusUnlockInputForPlayer {}

[event(unicast)]
struct CmdNexusLockMovementForPlayer {}

[event(unicast)]
struct CmdNexusUnlockMovementForPlayer {}

[event(unicast)]
struct EventNexusRequestReturnToSpawnQueue {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct RequestNexusStopCapturingBeacon
  beaconEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventNexusStopCapturingBeacon

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct RequestEndInteraction
  currentInteractable : EntityId

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdKillLianaTentacle
  pos : float3
  tentacleEid : EntityId

[event(unicast)]
struct CmdExecInteractionAction {}

[event(unicast)]
struct CmdConnectToHost {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdExtractFromBattlefield {}

[event(unicast)]
struct CmdExtractFromBattlefieldServer
  isDebug : bool

[event(unicast)]
struct CmdTriggerSafepackDrop {}

[event(unicast)]
struct EventTeammateFinishedRaid {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventPlayerFinishedRaid {}

[event(broadcast)]
struct EventPlayerFinishedOfflineRaid
  data : string

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventEndgamePlayerResult
  reason : int
  team : int
  allowSpectate : bool
  autoExit : bool

[event(unicast)]
struct EventResurrectionDeviceExpired {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdSendPlayerProfile
  signedToken : string
  unsignedToken : string

[event(broadcast)]
struct EventNavmeshIslandsMarked {}

[event(unicast)]
struct ApplyGameAffect
  targetEid : EntityId

[event(unicast, with_scheme, routing=ROUTING_SERVER_TO_CLIENT)]
struct DroneForceLeaveEvent {}

[event(unicast, with_scheme, routing=ROUTING_CLIENT_TO_SERVER)]
struct DroneLeaveEvent {}

[event(unicast, with_scheme, routing=ROUTING_CLIENT_TO_SERVER)]
struct DroneDropGrenade {}

[event(unicast, with_scheme, routing=ROUTING_SERVER_TO_CLIENT)]
struct DroneEnterEvent {}

[event(unicast)]
struct DroneDestroyEvent {}

[event(unicast)]
struct DroneMarkedCreate {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdDroneDeploy
  pos : float3

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdStartDroneDeploying {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdCancelDroneDeploying {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdRequestUseEmote
  emoteId : int

[event(unicast)]
struct CmdUseEmote
  emoteId : int

[event(unicast)]
struct EventGenJobComplete
  workerEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventAnimcharShowGeomtreeNode
  nodeName : string

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventAnimcharHideGeomtreeNode
  nodeName : string

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct NotifyFailReloadGun
  gunEid : EntityId
  statusTip : string

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct ShowStatusTip
  statusTip : string

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdAddSplineGeomPoint
  point : float3
  timeStamp : float

[event(unicast)]
struct CmdCryForHelp
  enemy : EntityId
  enemyPos : float3

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventTransPortalTeleport
  from : float3
  to : float3
  entry : EntityId
  exit : EntityId

[event(broadcast)]
struct EventMovingZoneCreated
  eid : EntityId

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnMovingZoneStarted
  zoneEid : EntityId

[event(broadcast)]
struct EventOnMovingZoneStopped
  zoneEid : EntityId

[event(unicast)]
struct CmdSetAbilityCooldown
  idx : int
  cooldown : float // < 0 resets cooldown to initial value

[event(unicast)]
struct PreRqUseAbility // To setup ability extra info BEFORE using (like target)
  idx : int
  isDryRun : bool
  physTick : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RqUseAbility
  idx : int
  isDryRun : bool
  physTick : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RqCancelAbility
  idx : int

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct AbilityUseFailed
  ability_name : string
  reason : int

[event(unicast)]
struct AbilityUseFailedClient
  ability_name : string
  reason : int

[event(unicast)]
struct CmdSkipActiveAbility
  ability_name : string

[event(unicast)]
struct CmdUseAbilityIdx
  idx : int
  physTick : int

[event(unicast)]
struct CmdSetAbilityParam
  name : string
  physTick : int

[event(unicast)]
struct EventOnPlayerDash
  from : float3
  to : float3

[event(unicast)]
struct DisableActiveAbilities {}


[event(unicast)]
struct ValidateAbilityPrereqs
  abilityIdx : int
  canUseAbility : bool

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RqDiyCreate
  previewTransform : float3x4

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct DiyAbilityAppearEffect
  pos : float3

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RqCheckAmmo
  value : bool

[event(unicast)]
struct EventCheckAmmoInMark {}

[event(unicast)]
struct EventCheckAmmoRemovedAmmoMarker {}

[event(unicast)]
struct CmdAddUserstats
  name : string
  change : float

[event(unicast)]
struct CmdSetStartTimestampUserstats
  name : string
  timestamp : float

[event(unicast)]
struct CmdSetEndTimestampUserstats
  name : string
  timestamp : float

[event(unicast)]
struct CmdSendAndFlushStats {}

[event(unicast)]
struct CmdChangeActiveMatterBalance
  change : int
  reason : string

[event(unicast)]
struct CmdUpdateActiveMatterBalance {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT, net_liable=logerr)]
struct EventChangeActiveMatterBalanceHint
  change : int
  hint : string

[event(broadcast)]
struct EventInventoryClosed {}

[event(broadcast)]
struct EventLocalPlayerRibbonsChanged {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdUseExtractionItemsTerminalRequest
  active : bool
  terminalEid : EntityId

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdExtractionItemsRequest
  heroEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdExtractionItemsPortalUse {}

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventFinalExtractionAppear
  extractionPointEid : EntityId

[event(broadcast)]
struct EventHeroExtracted
  heroEid : EntityId
  portalEid : EntityId

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdUseExternalInventoryAccesspointRequest
  heroEid : EntityId

[event(unicast)]
struct CmdUseExternalInventoryAccesspoint
  heroEid : EntityId

[event(unicast)]
struct CmdValidateActorUseExternalInventoryAccesspoint
  actorEid : EntityId
  inventoryEid : EntityId
  accesspointEid : EntityId

[event(unicast)]
struct EventExternalInventoryAccesspointAccessed
  heroEid : EntityId

[event(unicast)]
struct EventExternalInventoryContainerAccessedByHero
  heroEid : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdCloseExternalInventoryRequest
  inventoryEid : EntityId

[event(unicast)]
struct EventNexusBeaconCaptured
  team : int

[event(unicast)]
struct EventNexusBeaconReseted
  team : int

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventNexusRoundModeRoundStarted {}

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventNexusRoundModeRoundFinished
  winnerTeam : int
  reason : int
  time : float

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventNexusRoundModeRoundChange {}

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventNexusRoundModeRoundDebriefing {}

[event(broadcast)]
struct EventNexusCancelScheduledSpawnAllPlayers {}

[event(broadcast)]
struct EventNexusWaitingForEnoughPlayers {}

[event(broadcast)]
struct EventNexusWarmUp {}

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventNexusGameStart {}

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventNexusGameEnd
  winner : int
  time : float

[event(broadcast)]
struct EventNexusGameWaitForDebriefing

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventNexusGameDebriefing

[event(broadcast)]
struct EventNexusWarmUpStarted {}

[event(broadcast)]
struct EventNexusWarmUpFinished {}

[event(broadcast)]
struct EventNexusEnableProtectSpheres {}

[event(broadcast)]
struct EventNexusDisableProtectSpheres {}

[event(broadcast)]
struct EventNexusBattleDraw {}

[event(broadcast)]
struct EventNexusKillStatIncrease
  playerEid : EntityId;
  stats : IntList const?

[event(broadcast)]
struct EventNexusAssistStatIncrease
  playerEid : EntityId;

[event(broadcast)]
struct EventNexusHitStatIncrease
  playerEid : EntityId;

[event(broadcast)]
struct EventNexusBeaconCaptureStatIncrease
  playerEid : EntityId;

[event(broadcast)]
struct EventNexusBeaconResetStatIncrease
  playerEid : EntityId;

[event(broadcast)]
struct EventNexusDeathStatIncrease
  playerEid : EntityId;

[event(broadcast)]
struct EventNexusKillGroupStatChange
  playerEid : EntityId;
  count : int
  prevCount : int

[event(unicast)]
struct EventNexusSimpleStatChanged
  stat : int
  count : int
  score : int
  credits : int

[event(unicast)]
struct EventNexusKillStatChanged
  victimEid : EntityId
  stats : IntList const?
  score : int
  credits : int

[event(unicast)]
struct EventNexusAssistStatChanged
  victimEid : EntityId
  score : int
  credits : int

[event(unicast)]
struct EventNexusKillGroupStatChanged
  count : int
  score : int
  credits : int

[event(unicast)]
struct PlayerRequestCustomRespawnInWorld {}

[event(unicast)]
struct EventPlayerFirstSpawn {}

[event(broadcast)]
struct CmdRecreatePossessedRequest
  playerEid : EntityId

[cpp_event(broadcast, with_scheme, cpp_gen=false)]
struct OnShellHitEntityFx
  shellId : int
  pos : float3
  dir : float3
  pmid : int
  norm : float3
  bloodSplash : HitBloodType
  nodeCollId : int
  victimEid : EntityId
  directHit : bool
  stopped : bool
  projectileEid : EntityId

[cpp_event(broadcast)]
struct ProjectileOnHitEntityWithHp
  result : ProjectileHitResult
  projectile_eid : EntityId
  victim : EntityId
  isect : IntersectedEntityData
  launch_desc : LaunchDesc
  vel : float3
  dir : float3
  waterLen : float
  curTime : float
  offender : EntityId
  prev_projectile_dist : float
  piercing_shift : float
  allow_detonation : bool
  gun_eid : EntityId
  sceneHitRicochetStability : float
  trace_ray_mat_id : int
  check_if_should_apply_damage : bool

[event(unicast)]
struct EventProjectileIntersectEntityWithHp
  victim : EntityId
  offender : EntityId
  pos : float3
  collNodeId : int

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdPlayerSpawnRequestReplication {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdPlayerSpawnRequestReplicationResponse {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdGameModePlayerInit
  metaItemsJson : string

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdGameModePlayerSpawnRequest {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventGameModePlayerSpawnRejected
  reason : int

[event(unicast)]
struct EventGameModeResurrectRequest {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventTeamItemHint {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdHeroLogExEvent
  event : string
  key : string
  data : Object const?

[event(unicast)]
struct CmdHeroLogExEventLocal
  event : string
  key : string
  data : Object const?

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventGameTrigger
  source : EntityId
  target : EntityId = INVALID_ENTITY_ID
  triggerHash : int

[event(unicast)]
struct RequestItemPickup
  itemEid : EntityId

[event(unicast)]
struct TryUseItem
  userEid : EntityId
  targetEid : EntityId

[event(unicast)]
struct EventUpdateMonstrifyPosition {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestUseItem
  itemEid : EntityId
  targetEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct ResponseFailureUseItem
  itemEid : EntityId
  reason : int

[event(unicast)]
struct EventOnItemStartUse
  userEid : EntityId
  targetEid : EntityId

[event(unicast)]
struct EventInterruptItemUse
  forced : bool

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestInterruptItemUse{}

[event(unicast)]
struct EventItemUseInterrupted
  userEid : EntityId
  startTime : float

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestUseCorticalVault
  itemEid : EntityId
  targetEid : EntityId
  atTime : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct ResponseFailureUseCorticalVault
  itemEid : EntityId
  reason : int

[event(unicast)]
struct RequestUseTeammateRaiser
  targetEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct ResponseFailureUseTeammateRaiser
  reason : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestUseBinoculars
  itemEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct ResponseFailureUseBinoculars
  itemEid : EntityId
  reason : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestUseHeal
  partIndex : int
  itemEid : EntityId
  atTime : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct ResponseFailureUseHeal
  itemEid : EntityId
  reason : int

[event(unicast)]
struct CmdShowHealingDoll {}

[event(broadcast)]
struct CmdShowUiMenu
  menuName : string

[event(broadcast)]
struct CmdToggleUiMenu
  menuName : string

[event(broadcast)]
struct CmdHideUiMenu
  menuName : string

[event(broadcast)]
struct CmdHideAllUiMenus {}

[event(unicast)]
struct CmdPrepareInteractionMenu
  interactorEid : EntityId

[event(unicast)]
struct EventActionMarkerStateChanged {}

[event(unicast)]
struct EventStartPlacingFromStash
  blueprintName : string
  stashIdx : int

[event(unicast)]
struct EventBuildPlaced
  blueprintName : string
  movedBuildingEid : EntityId
  stashIdx : int

enum DestroyBuildingReason
  UNKNOWN
  MOVE
  STASH

[event(unicast)]
struct CmdDestroyBuilding
  reason : DestroyBuildingReason

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdGathererToggle
  isOn : bool

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct ReqAttachToLadder
  wishPos : float3
  wishLookOrient : float4
  wishGunOrient : float4
  ladderUp : float3

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct ReqDetachFromLadder {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct ReqJumpFromLadder {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdDetachLadder {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdShowPoisonEffect
  begin : float
  end : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdShowHealOverTimeEffect
  begin : float
  end : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdJumpQuestNodeSyncTransform
  transform : float3x4

[event(broadcast)]
struct EventAmCoreExhausted
  eid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdSetCoreWarriorTravelPath
  path : Point3List const?

[event(unicast)]
struct EventAmCoreAgroed {}

[event(unicast)]
struct EventConstructionControllerPartCreated
  partEid : EntityId

[event(unicast)]
struct EventConstructionControllerAllPartsCreated{}

[event(broadcast)]
struct EventBaseBuildingsLoaded {}

[event(unicast)]
struct EventUseObjectBlocked {}

[event(unicast)]
struct CmdBuildModeSaveChanges {}

[event(unicast)]
struct CmdMoveCameraToSelection {}

[event(unicast)]
struct CmdChangeActiveBuildGrid
  gridEid : EntityId

[event(broadcast)]
struct CmdInputEnterBuildMode {}

[event(broadcast)]
struct CmdInputExitBuildMode {}

[event(unicast)]
struct CmdExitBuildMode
  saveChanges : bool

[event(unicast)]
struct CmdMoveBuildCamera
  to : EntityId

[event(unicast)]
struct EventJumpNodeTreeGenerated {}

[event(unicast)]
struct CmdLaunchBigheadProjectile {}

[event(unicast)]
struct EventBuildCameraArrived {}

[event(broadcast)]
struct EventUIMouseMoved
  screenX : float
  screenY : float

[event(broadcast)]
struct EventUIMouseWheelUsed
  value : float

[event(unicast)]
struct CmdDeployBuildingPreviewFromStash
  uniqueId : string
  position : int2
  rotation : int
  gridId : int
  blueprintName : string
  recordChange : bool

[event(unicast)]
struct CmdDeployBuildingPreviewBeforeCamera
  uniqueId : string

[event(unicast)]
struct CmdStashCurrentBuilding {}

[event(unicast)]
struct EventBuildModeGizmoStartDrag {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventWorkbenchItemsCreated
  heroEid : EntityId
  data : Object const?

[event(unicast)]
struct CmdWorkbenchResultEvent
  name : string
  heroEid : EntityId
  data : Object const?

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventWorkbenchResultEvent
  name : string
  heroEid : EntityId
  data : Object const?

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventWorkbenchCorruptionBlockRemoved
  pos : float3

[event(unicast)]
struct EventCorruptedWorkbenchCleaned {}

[event(broadcast)]
struct CmdEncounterWorkbenchMenuRequest
  state : int

[event(unicast)]
struct EventEncounterWorkbenchItemsToRepairChanged {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct RequestEncounterWorkbenchRepairItemAction
  heroEid : EntityId
  itemEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventWorkbenchItemRepaired
  heroEid : EntityId
  itemEid : EntityId

[event(unicast)]
struct EventSwitchRagdollPhysobj
  templateName : string

[event(broadcast)]
struct CmdUpdateActiveBuildings {}

[event(broadcast)]
struct CmdUpdateBasePower {}

[event(unicast)]
struct CmdRecreateBuildingParts {}

[event(unicast)]
struct CmdRequestMoveBuilding
  id : int64
  move : int2
  rotate : int
  grid : int

[event(unicast)]
struct CmdRequestUnstashBuilding
  uniqueId : int64
  move : int2
  rotate : int
  grid : int

[event(unicast)]
struct CmdRequestStashBuilding
  id : int64

[event(unicast)]
struct CmdBuildModeCameraZoom
  zoomIn : bool

[event(unicast)]
struct CmdRequestChangeBasePower
  basePower : Object const?

[event(unicast)]
struct CmdMovePreviewToStash
  uniqueId : string

[event(unicast)]
struct CmdShowBuildModeBriefing {}

[event(unicast)]
struct CmdBuildModeUndo {}

[event(unicast)]
struct CmdDebriefingSpectateRequest {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdDebriefingUseRespawnDeviceRequest {}

[event(unicast)]
struct CmdOpenDebriefingRequest {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdOpenSwarmNote {}

[event(broadcast)]
struct CmdRegenMonsterGen {}

[event(broadcast)]
struct EventTilecacheSyncWillBeStarted {}

[event(broadcast)]
struct EventTilecacheSyncFinished {}

[event(unicast)]
struct CmdAwakeSleepingMonster
  propadateCount : int
  disturber : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdReplaceRiExtraRes
  riExtra : string
  destroyPrevRi : bool
  addPrevRiToRestorables : bool
  createPrevRiDestr : bool

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdPreloadRiRes
  riExtra : string

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventHumanFall
  duration : float

[event(unicast)]
struct EventHumanFallClientPrediction
  duration : float

[cpp_event(broadcast)]
struct TransformSnapshots
  data : BitStream

[cpp_event(broadcast)]
struct TransformSnapshotsReliable
  data : BitStream

[event(unicast, version=1, routing=ROUTING_SERVER_TO_CLIENT, reliability=UNRELIABLE)]
struct TransformSnapshotsTargeted
  data : BitStream const?

[cpp_event(unicast)]
struct EventSnapshotBlink
  from : float3x4
  to : float3x4
  dt : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdCauseTrauma
  addTrauma : float
  maxTrauma : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventBeesLeftStain
  value : float

[event(broadcast)]
struct EventBeehiveDestruction
  beehiveEid : EntityId

[event(unicast)]
struct EventTrapTrigger
  activatorEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventTrapTriggerNotify
  trapEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventLightningCreated
  startPos : float3
  direction : float3
  speed : float
  lifetime : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventWanderingCoreHit
  agro : float

[event(unicast)]
struct EventMonsterAuraDirty {}

[event(unicast)]
struct EventAmDrainedFromCorpse {}

[event(unicast)]
struct EventAmAttachedToCorpse {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventEnterGravityHookZone
  effectEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventLeaveGravityHookZone {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdValidateRIExtraIndex
  id : int
  name : string

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct ResponseFailureUseItemHolder
  itemEid : EntityId
  reason : int

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct ResponseFailureDropAllContent
  inventoryEid : EntityId
  reason : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestInterruptUseItemHolder

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestLoadItemHolder
  targetItemEid : EntityId
  containerEid : EntityId
  searchOtherContainers : bool

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestUnloadItemHolder
  targetItemEid : EntityId
  containerEid : EntityId

[event(unicast)]
struct RqCheckAmmoItemHolder
  targetItemEid : EntityId
  containerEid : EntityId

[event(unicast)]
struct RqStopCheckAmmoItemHolder {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventCapacityExceeded
  containerEid : EntityId

[event(broadcast)]
struct CmdSetCameraDofEnabled
  enabled : bool

[event(broadcast)]
struct CmdSetDofIsFilmic
  isFilmic : bool

[event(broadcast)]
struct CmdSetDofFocusDistance
  focusDistance : float

[event(broadcast)]
struct CmdSetDofFocalLength
  focalLength : float

[event(broadcast)]
struct CmdSetDofFStop
  fStop : float

[event(broadcast)]
struct CmdSetDofBokehCorners
  bokehCorners : float

[event(broadcast)]
struct CmdSetDofBokehSize
  bokehSize : float

[event(broadcast)]
struct CmdSetCinematicModeEnabled
  enabled : bool

[event(broadcast)]
struct CmdSetMotionBlurScale
  scale : float

[event(broadcast)]
struct CmdSetFilmGrain
  strength : float

[event(broadcast)]
struct CmdSetVignetteStrength
  strength : float

[event(broadcast)]
struct CmdSetChromaticAberrationOffset
  offset : float

[event(broadcast)]
struct CmdChangeTimeOfDay
  timeOfDay : float

[event(broadcast)]
struct CmdWeather
  preset : string

[event(broadcast)]
struct CmdSetRain
  enabled : bool

[event(broadcast)]
struct CmdSetSnow
  enabled : bool

[event(broadcast)]
struct CmdSetLightning
  enabled : bool

[event(broadcast)]
struct CmdSetCinematicPostFxBloom
  enabled : bool

[event(broadcast)]
struct CmdSetCinematicSetSuperPixels
  super_pixels : int

[event(broadcast)]
struct CmdSetCinematicCustomSettings
  enabled : bool

[event(broadcast)]
struct CmdSetLenseFlareIntensity
  intensity : float

[event(broadcast)]
struct CmdSetBloomThreshold
  threshold : float

[event(broadcast)]
struct CmdSetCameraLerpFactor
  lerpFactor : float

[event(broadcast)]
struct CmdSetCameraStopLerpFactor
  stopLerpFactor : float

[event(broadcast)]
struct CmdReplayRewind
  time : int

[event(unicast)]
struct NextReplayTarget
  delta : int

[event(unicast)]
struct ReplayTrackPlayAll {}

[event(unicast)]
struct ReplayTrackClearAllKeyFrames {}

[event(unicast)]
struct ReplayTrackSerialize {}

[event(unicast)]
struct ReplayTrackDeserialize
  switchCamera : bool

[event(broadcast)]
struct ReplayToggleFreeCamera {}

[event(broadcast)]
struct ReplaySetFpsCamera {}

[event(broadcast)]
struct ReplaySetFreeTpsCamera {}

[event(broadcast)]
struct ReplaySetTpsCamera {}

[event(broadcast)]
struct ReplaySetOperatorCamera {}

[event(broadcast)]
struct ReplaySetTrackCamera {}

[event(unicast)]
struct ReplayTrackSaveKeyFrame {}

[event(unicast)]
struct ReplayTrackDeleteKeyFrame
  index : int

[event(unicast)]
struct ReplayTrackTogglePlayRotation {}

[event(unicast)]
struct ReplayTrackTogglePlayPosition {}

[event(unicast)]
struct ReplayTrackAttachToWeapon {}

[event(unicast)]
struct ReplayTrackDetachFromWeapon {}

[event(unicast)]
struct ReplayTrackTogglePlayRoll {}

[event(unicast)]
struct ReplayTrackTogglePlayFov {}

[event(unicast)]
struct ReplayTrackToggleInterp {}

[event(unicast)]
struct ReplayPostProdSaveFile {}

[event(unicast)]
struct ReplayPostProdLoadFile {}

[event(unicast)]
struct ReplayPossessEntity
  prevEid : EntityId

[event(unicast)]
struct SetReplayTarget {}

[event(broadcast)]            // require only for use parallel for in different attaches queue's
struct SlotAttachUpdateEvent  // May be removed when "parallel for" will implemented in das ecs query
  dt : float

[event(broadcast)]
struct CmdSetCameraFov
  fov : float

[event(broadcast)]
struct CmdSetFreeTpsCameraSpeed
  speed : float

[event(broadcast)]
struct CmdSetCinemaRecording
  enabled : bool

[event(unicast)]
struct CmdUpdateCameraByVehicleType {}

[event(unicast)]
struct ReplaySetCamera {}

[event(broadcast)]
struct CmdReplayRewindSaveState
  state : Object const?

[event(broadcast)]
struct CmdReplayRewindLoadState
  state : Object const?

[event(unicast)]
struct EventQuickUseItemUsed
  userEid : EntityId

[event(broadcast)]
struct SaveQuickUseSlot
  itemTemplate : string
  slotIdx : int

[event(broadcast)]
struct EventProfileLoaded {}

[event(unicast)]
struct EventAmLooted
  amount : int

[event(unicast)]
struct CmdDestroyMe {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct EventSpawnSequenceHeroInited {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventSpawnSequenceEnd {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventDamageModelApplyDamage
  totalDamage : float
  notBlockedDamage : float

[event(unicast)]
struct EventDamageModelPartDamageBlocked
  partName : string
  damageType : int
  fullDamage : float
  blockedDamage : float

[event(unicast)]
struct CmdDamageItem
  damageType : int
  damage : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdItemDestroyed
  damageType : int

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct RequestInteractionMenuAction
  heroEid : EntityId
  action : string
  actionParam : Object const?

[event(unicast)]
struct EventWentToNetStash {}

[event(unicast)]
struct EventNoLongerInNetStash {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdRequestSnakeSegmentPositionSync
  hero : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventSnakeSegmentPositionSync
  position : float3

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdToggleSnapshotDebug {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventSnapshotsDebugInfo
  eidsCounts : IntList const?
  snapsCounts : IntList const?

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdMarkItemRecognized
  itemEid : EntityId

[event(unicast)]
struct NotifyItemRecognitionStarted {}

[event(unicast)]
struct CmdEnableRagdoll {}

[event(unicast)]
struct CmdDisableRagdoll {}

[event(unicast)]
struct EventDoorControllerInited {}

[event(unicast)]
struct EventDoorChangeStateRequest
  target_door_state : int

[event(broadcast)]
struct CmdStartOnboardingMemory {}

[event(broadcast)]
struct CmdInterruptOnboardingMemory {}

[event(broadcast)]
struct CmdRequestOnboardingRaid {}

[event(broadcast)]
struct EventOnboardingRaidExit
  success : bool

[event(broadcast)]
struct CmdRequestOnboardingReportContract {}

[event(broadcast)]
struct CmdRequestOnboardingBuyMonolithAccess {}

[event(unicast)]
struct CmdClearStateMachineEffectImmediately {}

[event(unicast)]
struct EventStateMachineTransition {}

[event(unicast)]
struct EventOnboardingPhaseResult
  amCount : int
  data : Object const?

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdTeaserGoToEpisodeRequest {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdTeaserEpisodeTriggerRequest
  triggerIndex : int

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdTeaserResetEpisodeRequest {}

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdChangeSkiesTime
  time : float

[event(unicast)]
struct EventStateMachineStateChanged
  stateEid : EntityId

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdSendUserDedicatedPermissions
  jwt : string

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdSendChatMessage//mode="team",text="",qmsg=null
  data : Object const?

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventChatMessage
  data : Object const?

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventCorticalVaultSyncPos
  pos : float3


[event(unicast)]
struct EventHumanDefaultStubItemCreated
  itemEid : EntityId

[event(unicast)]
struct EventEquipAlter
  chronogenesList : Object const?

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventAddNoiseSubtemplate {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventRemoveNoiseSubtemplate {}

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventServerTrackedLoudNoise
  pos : float3
  radius : float
  amount : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventObjectivePhotographShot {}

[event(unicast)]
struct CmdStartAssistantSpeak
  scriptName : string
  skipBeepSound : bool

[event(unicast)]
struct CmdStopAssistantSpeak {}

[event(unicast)]
struct EventRiRotationPrematureStop {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventHumanInventoryPostponedUsageOnUnarmedSet {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EntityWillBeTeleported
  fromTm : float3x4
  toTm : float3x4

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventPreparingToSleep
  value : bool

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventFlowerFall
  slotId : int
  direction : float3

[event(broadcast)]
struct EventGravityZonesLoaded {}

[event(broadcast)]
struct EventSuitChanged
  oldSuitEid : EntityId
  newSuitEid : EntityId

[event(unicast)]
struct EventReattachWeapons {}

[event(unicast)]
struct EventReattachWeapon
  slot : int

[event(unicast)]
struct EventItemHolderLoadingFinished
  holderEid : EntityId
  loadedItemCount : int

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct EventItemHolderInspectionFinished
  holderEid : EntityId

[event(unicast)]
struct EventCheckWeaponMarker {}

[event(unicast)]
struct EventRiExtraLoaded {}

[event(unicast)]
struct RotatingRendinstSimplePhysFixedUpdate
  dt : float

[event(unicast)]
struct RotatingRendinstSimplePhysUpdateFinished
  accRatio : float

[event(unicast)]
struct RotatingRendinstSimplePhysClampAngleReached
  angle : float

[event(unicast)]
struct EventDelayedFrameAction {}

[event(broadcast)]
struct EventShowItemInShowroom
  showroomKey : string
  data : Object const?

[event(broadcast)]
struct EventActivateShowroom
  showroomKey : string
  placeScreenPosition : float2
  placeScreenSize : float2

[event(broadcast)]
struct EventAlterHighlight
  alterTubeKey : string
  highlightIntence : float

[event(broadcast)]
struct EventCloseShowroom {}

[event(unicast)]
struct EventRetriggerEntity {}
// formatter hack

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventProcessDash
  atTime : float
  wishPos : float3

[event(unicast)]
struct CmdStartItemInWorldPhys {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdStopItemInWorldPhys {}

[event(broadcast)]
struct EventSetReplicatorData
  replicatorIdx : int
  replicatorDoneAt : float
  replicatorTime : float
  replicatorIsEmpty : bool

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct ShowActivityHelperPoint
  position : float3

[event(unicast)]
struct EventMapObjectStateChanged {}

[event(unicast)]
struct RequestFillAllItems {}

[event(broadcast)]
struct EventNesingSnakeCollided
  holeIn : bool
  pos : float3
  dir : float3
  norm : float3
  templ : string

[event(unicast)]
struct EventLockEquipmentHeartbeat {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventPortalTeleportEntity
  newTm, oldTm : float3x4

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct EventClientTeleportedEntity
  newTm, oldTm : float3x4
  entryPortal : EntityId
  atTick : int

[event(unicast)]
struct CmdTraceAgentDangers
  forceRetrace : bool

[event(unicast)]
struct EventFlankingTargetAcquired
  targetEid : EntityId
  distance : float
  priority : int


[event(unicast)]
struct CmdForceLoadProfile {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdZoneWeatherStartStorm
  riseTime : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdZoneWeatherStopStorm
  recoveryTime : float

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdHumanStopHackingCorticalVaultRequest {}

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventAmStorageHacked
  hackerActorEid : EntityId
  ragdollPhysObjEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventActiveMatterPileProviderExhausted {}

[event(unicast)]
struct EventStoneHit {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventStatueAttacked {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventStatueAttackImminent {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventStatueMove
  pos : float3
  look : float2
  duration : float

[event(broadcast)]
struct EventTrapIsTriggered
  trapEid : EntityId

[event(unicast)]
struct CmdAssignContainerForPlanting {} //offline hack

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdExplodeCore
  exploadAt : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdDynamicExtractionChangeState
  enabled : bool
  timestamp : float

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct MothmanGrabAbilityPrepare
  targetEid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventNPhysTeleported
  from : float3x4
  to : float3x4

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdSetBoidsStamina {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventMimicAttack
  pos : float3
  success : bool

[event(unicast)]
struct EventMimicAttackPrepare {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT, net_liable=ignore)]
struct EventMimicDamaged {}

[event(unicast)]
struct EventamMimicStep
  pos : float3