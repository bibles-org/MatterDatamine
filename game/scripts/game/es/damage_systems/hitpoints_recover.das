require ecs
require app
require game.events.events_active_matter
require danetlibs.dm.dm_events


[es(tag=server, after=(simple_hitpoints_apply_damage, cellular_hitpoints_apply_damage),
  on_event=CmdApplyDamage)]
def hitpoints_recover_reset_time(evt : Event; var hitpoints__lastDamageTime : float&)
  hitpoints__lastDamageTime = get_sync_time()


[es(tag=server)]
def simple_hitpoints_recover(act : ParallelUpdateFrameDelayed;
                             hitpoints__maxHp : float;
                             hitpoints__hpPartThreshold : float;
                             hitpoints__hpRecoverySpd : float;
                             hitpoints__recoveryTimeThreshold : float;
                             hitpoints__lastDamageTime : float;
                             var hitpoints__hp : float&)
  let isCorrectHpValue = (
       hitpoints__hp > 0.f
    && hitpoints__hpPartThreshold > 0.0
    && hitpoints__hp / hitpoints__maxHp < hitpoints__hpPartThreshold
  )
  let isCanRestoreHpByTime = hitpoints__lastDamageTime + hitpoints__recoveryTimeThreshold < act.curTime
  if isCorrectHpValue && isCanRestoreHpByTime
    let newHp = hitpoints__hp + hitpoints__hpRecoverySpd * act.dt
    hitpoints__hp = min(newHp, hitpoints__maxHp * hitpoints__maxHp)


[es(tag=server)]
def cellular_hitpoints_recover(act : ParallelUpdateFrameDelayed;
                               hitpoints__hpPartThreshold : float;
                               hitpoints__hpRecoverySpd : float;
                               hitpoints__recoveryTimeThreshold : float;
                               hitpoints__lastDamageTime : float;
                               cellular_hitpoints__maxCellHp : float;
                               cellular_hitpoints__maxCells : int;
                               var cellular_hitpoints__damagedCells : int&;
                               var cellular_hitpoints__currentCellHp : float&)
  let isCorrectHpValue = (
       cellular_hitpoints__damagedCells != cellular_hitpoints__maxCells
    && hitpoints__hpPartThreshold > 0.0
    && float(cellular_hitpoints__damagedCells) / float(cellular_hitpoints__maxCells) > hitpoints__hpPartThreshold
  )
  let isCanRestoreHpByTime = hitpoints__lastDamageTime + hitpoints__recoveryTimeThreshold < act.curTime
  if isCorrectHpValue && isCanRestoreHpByTime && cellular_hitpoints__damagedCells > 0
    cellular_hitpoints__currentCellHp += hitpoints__hpRecoverySpd * act.dt
    if cellular_hitpoints__currentCellHp >= cellular_hitpoints__maxCellHp
      cellular_hitpoints__currentCellHp = 0.01
      --cellular_hitpoints__damagedCells
