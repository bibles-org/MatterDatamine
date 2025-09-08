module app_common shared
require net
require app
require DagorSystem
require DagorDataBlock

def get_environment() : string
  return get_circuit_conf() |> datablock_getStr("environment", "")

def is_dev_circuit() : bool
  let env = get_environment()
  let isDevMode = !empty(dgs_get_argv("devMode")) || (dgs_get_settings() |> datablock_getBool("disableRemoteNetServices", false))
  let testEnv = env == "test"
  return (empty(env) && isDevMode) || (!empty(env) && testEnv)

def is_production_circuit() : bool
  return !is_dev_circuit()