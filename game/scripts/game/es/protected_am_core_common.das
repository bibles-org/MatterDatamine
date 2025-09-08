module protected_am_core_common shared


enum ProtectedAmCoreState
  NONE
  SETUP_PATROL
  PATROL
  STARTING_FIGHT
  FIGHT
  ENDING_FIGHT
  DEAD


enum ProtectedAmCorePatrolPathMode
  NONE
  PING_PONG
  LOOP