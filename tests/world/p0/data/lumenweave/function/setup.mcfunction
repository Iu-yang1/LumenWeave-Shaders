gamerule doDaylightCycle false
gamerule doWeatherCycle false
gamerule doMobSpawning false
gamerule randomTickSpeed 0
gamerule doImmediateRespawn true
fill -8 119 -8 8 119 16 minecraft:stone
fill -7 120 10 7 124 10 minecraft:white_concrete
fill -7 120 10 -3 124 10 minecraft:black_concrete
fill 3 120 10 7 124 10 minecraft:red_concrete
fill -5 120 3 -5 122 7 minecraft:glass
fill 3 120 3 5 120 5 minecraft:water
setblock -3 120 8 minecraft:torch
setblock 3 120 8 minecraft:soul_torch
setblock 5 120 8 minecraft:sea_lantern
execute if block 0 119 0 minecraft:stone run function lumenweave:day
