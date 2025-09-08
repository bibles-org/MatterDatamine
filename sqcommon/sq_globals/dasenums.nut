

enum AbilityUseFailedReason {  
  COOLDOWN = 0
  NOT_ENOUGH_CHARGES = 1
  NOT_ENOUGH_STAMINA = 2
  TOO_FAR = 3
}
let AbilityUseFailedReason_COUNT = 4

enum MothmanDivingGrabState {  
  NONE = 0
  GRABBING = 1
  FLIGHT = 2
  HOLD = 3
}
let MothmanDivingGrabState_COUNT = 4

enum EncounterWorkbenchMenuState {  
  NONE = 0
  REPAIR = 1
}
let EncounterWorkbenchMenuState_COUNT = 2

enum BinocularsUseState {  
  NONE = 0
  IN = 1
  IN_REVERSE = 2
  WATCHING = 3
  OUT = 4
  DOWN_IDLE = 5
  FINISHED = 6
  INTERRUPTION = 7
}
let BinocularsUseState_COUNT = 8

enum BinocularsWatchingState {  
  NONE = 0
  IN_FADEIN = 1
  IN_FADE = 2
  IN_FADEOUT = 3
  IDLE = 4
  OUT_FADEIN = 5
  OUT_FADE = 6
  OUT_FADEOUT = 7
}
let BinocularsWatchingState_COUNT = 8

enum EndgameControllerState {  
  NONE = 0
  FADE_DELAY = 1
  FADEIN = 2
  DEBRIEFING = 3
  SPECTATING = 4
}
let EndgameControllerState_COUNT = 5

enum EquipmentSlotFlags {  
  NONE = 0
  REMOVED = 1
}
let EquipmentSlotFlags_COUNT = 2

enum GunSlotFlags {  
  NONE = 0
  REMOVED = 1
  LOCKED = 2
}
let GunSlotFlags_COUNT = 3

enum ExtractionStatusForHero {  
  OK = 0
  WRONG_TIME = 1
  PRIMARY_CONTRACT_NOT_COMPLETED = 2
}
let ExtractionStatusForHero_COUNT = 3

enum GameEndReasons {  
  YOU_DIED = 0
  YOU_EXTRACTED = 1
  BASE_PROTECTED = 2
  TIME_OUT = 3
  LEFT_WITH_NOTHING = 4
  LEFT_WITH_LOOT = 5
  BASE_ROBBED = 6
  NEXUS_BATTLE_WON = 7
  NEXUS_BATTLE_LOST = 8
  NEXUS_BATTLE_DIED = 9
  NEXUS_ROUND_WON = 10
  NEXUS_ROUND_LOST = 11
  ONBOARDING_FAILED_CONTRACT = 12
}
let GameEndReasons_COUNT = 13

enum HitResult {  
  HIT_RES_NONE = 0
  HIT_RES_NORMAL = 1
  HIT_RES_DOWNED = 2
  HIT_RES_KILLED = 3
}
let HitResult_COUNT = 4

enum HumanUseObjectHintType {  
  DEFAULT = 0
  WORLD_MARKER = 1
}
let HumanUseObjectHintType_COUNT = 2

enum PackFitCheckResult {  
  OK = 0
  INVENTORY_FULL = 1
  EQUIPMENT_FULL = 2
}
let PackFitCheckResult_COUNT = 3

enum NexusBeaconState {  
  INACTIVE = 0
  COOLDOWN = 1
  CHANGING = 2
  CAPTURED = 3
}
let NexusBeaconState_COUNT = 4

enum NexusTeam {  
  FIRST = 2
  SECOND = 3
}
let NexusTeam_COUNT = 2

enum NexusGameEndState {  
  None = 0
  GameEnded = 1
  Debriefing = 2
  ClientsLeave = 3
  SessionEnded = 4
}
let NexusGameEndState_COUNT = 5

enum NexusGameStartState {  
  None = 0
  Aborted = 1
  WaitingForPlayers = 2
  WarmUp = 3
  Started = 4
}
let NexusGameStartState_COUNT = 5

enum NexusRoundFinishReason {  
  ALL_DIED = 0
  TEAM_DIED = 1
  CAPTURE = 2
  CAPTURE_ADVANTAGE = 3
  POINTS = 4
  POINTS_ADVANTAGE = 5
  POINTS_DRAW = 6
  TIME_OUT = 7
}
let NexusRoundFinishReason_COUNT = 8

enum NexusRoundState {  
  None = 0
  Preparation = 1
  Started = 2
  Finished = 3
  Debriefing = 4
}
let NexusRoundState_COUNT = 5

enum NexusMvpReason {  
  MOST_KILLS = 0
  MOST_HELP = 1
  MOST_BEACON_CAPTURES = 2
}
let NexusMvpReason_COUNT = 3

enum NexusStatType {  
  KILL = 0
  ASSIST = 1
  HIT = 2
  GRENADE_KILL = 3
  MELEE_KILL = 4
  HEADSHOT_KILL = 5
  TEAM_KILL = 6
  LONGSHOT_KILL = 7
  BEACON_CAPTURE = 8
  BEACON_RESET = 9
  DEATH = 10
}
let NexusStatType_COUNT = 11

enum ContractType {  
  PRIMARY = 0
  SECONDARY = 1
  STORY = 2
  ITEM = 3
  FREE_TO_USE = 4
  FREE_TO_USE_2 = 5
  MONSTER = 6
}
let ContractType_COUNT = 7

enum ObjectivePhotographAffectState {  
  NONE = 0
  SHOOTED = 1
}
let ObjectivePhotographAffectState_COUNT = 2

enum PlayerSpawnControllerDefaultState {  
  NONE = 0
  FADE = 1
  REQUEST_REPLICATION = 2
  DELAY = 3
  DONE = 4
}
let PlayerSpawnControllerDefaultState_COUNT = 5

return {
  AbilityUseFailedReason
  AbilityUseFailedReason_COUNT
  MothmanDivingGrabState
  MothmanDivingGrabState_COUNT
  EncounterWorkbenchMenuState
  EncounterWorkbenchMenuState_COUNT
  BinocularsUseState
  BinocularsUseState_COUNT
  BinocularsWatchingState
  BinocularsWatchingState_COUNT
  EndgameControllerState
  EndgameControllerState_COUNT
  EquipmentSlotFlags
  EquipmentSlotFlags_COUNT
  GunSlotFlags
  GunSlotFlags_COUNT
  ExtractionStatusForHero
  ExtractionStatusForHero_COUNT
  GameEndReasons
  GameEndReasons_COUNT
  HitResult
  HitResult_COUNT
  HumanUseObjectHintType
  HumanUseObjectHintType_COUNT
  PackFitCheckResult
  PackFitCheckResult_COUNT
  NexusBeaconState
  NexusBeaconState_COUNT
  NexusTeam
  NexusTeam_COUNT
  NexusGameEndState
  NexusGameEndState_COUNT
  NexusGameStartState
  NexusGameStartState_COUNT
  NexusRoundFinishReason
  NexusRoundFinishReason_COUNT
  NexusRoundState
  NexusRoundState_COUNT
  NexusMvpReason
  NexusMvpReason_COUNT
  NexusStatType
  NexusStatType_COUNT
  ContractType
  ContractType_COUNT
  ObjectivePhotographAffectState
  ObjectivePhotographAffectState_COUNT
  PlayerSpawnControllerDefaultState
  PlayerSpawnControllerDefaultState_COUNT
}