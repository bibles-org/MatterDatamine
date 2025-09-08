require ecs
require app
require DagorMath


[es(tag=(server, dev), on_appear)]
def server_stats_controller_init(evt : Event;
                                 server_stats_controller__updateInterval : float;
                                 var server_stats_controller__lastUpdateAt : float&;
                                 var server_stats_controller__updateAt : float&;
                                 var server_stats_controller__framesCounter : int&;
                                 var server_stats_controller__dtMinMaxAvgCounter : float3&)
  server_stats_controller__lastUpdateAt = get_sync_time()
  server_stats_controller__updateAt = get_sync_time() + server_stats_controller__updateInterval
  server_stats_controller__framesCounter = 0
  server_stats_controller__dtMinMaxAvgCounter = float3(VERY_BIG_NUMBER, 0.0, 0.0)


[es(tag=(server, dev), no_order)]
def server_stats_controller_update(act : UpdateStageInfoAct;
                                   server_stats_controller__updateInterval : float;
                                   var server_stats_controller__lastUpdateAt : float&;
                                   var server_stats_controller__updateAt : float&;
                                   var server_stats_controller__framesCounter : int&;
                                   var server_stats_controller__fps : float&;
                                   var server_stats_controller__dtMinMaxAvgCounter : float3&;
                                   var server_stats_controller__dtMinMaxAvg : float3&)
  server_stats_controller__framesCounter++
  server_stats_controller__dtMinMaxAvgCounter.x = min(server_stats_controller__dtMinMaxAvgCounter.x, act.dt)
  server_stats_controller__dtMinMaxAvgCounter.y = max(server_stats_controller__dtMinMaxAvgCounter.y, act.dt)
  server_stats_controller__dtMinMaxAvgCounter.z += act.dt

  if act.curTime >= server_stats_controller__updateAt
    let timePassed = act.curTime - server_stats_controller__lastUpdateAt
    server_stats_controller__fps = safediv(float(server_stats_controller__framesCounter), timePassed)
    server_stats_controller__dtMinMaxAvgCounter.z = safediv(server_stats_controller__dtMinMaxAvgCounter.z, float(server_stats_controller__framesCounter))
    server_stats_controller__dtMinMaxAvg = server_stats_controller__dtMinMaxAvgCounter

    server_stats_controller__framesCounter = 0
    server_stats_controller__dtMinMaxAvgCounter = float3(VERY_BIG_NUMBER, 0.0, 0.0)
    server_stats_controller__lastUpdateAt = act.curTime
    server_stats_controller__updateAt = act.curTime + server_stats_controller__updateInterval
