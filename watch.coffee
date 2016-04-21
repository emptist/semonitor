say = require 'say'
util = require 'util'
monitor = require './monitor.coffee'

###
  db: 數據庫連接
  可採用多線程寫法,券商接口各自在自己線程中運行
###
observe = (組合管家,多券商接口, n, db)->
  券商接口啟動登記 = (多券商接口)->
    for 接口 in 多券商接口
      接口.連接成功 (err,data)->
        if err?
          throw(err)
        else
          util.log('已接通券商..', data)
          接口.提取資料 '查詢資產,getCapital'
          組合管家.各券商接口.push 接口

  券商接口啟動登記(多券商接口) if 多券商接口?

  秒 = 1000
  分 = 60*秒
  小時 = 60*分
  間隔 = 3*秒
  開市時間 = n*小時

  組合管家.清潔 = true
  # 將其this 設定為組合管家
  組合管家.跟蹤行情 = monitor.call(組合管家)

  interval = setInterval 組合管家.跟蹤行情, 間隔

  ###
    1. 此處,到設定時間,或
    2. monitor中,不再有品種需要跟蹤時,使用本法停止跟蹤
  ###
  組合管家.結束跟蹤 = ->
    say.speak "Well, done! See you later!"
    util.log '收盤了'
    組合管家.clearIntervals()
    clearInterval interval
    for 接口 in 組合管家.各券商接口
      接口.destroy()
    # 亦可在此斷開數據庫連接
    db?.close()

  timeout = setTimeout 組合管家.結束跟蹤, 開市時間


module.exports = observe
