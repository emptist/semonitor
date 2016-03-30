say = require 'say'
util = require 'util'
{ticks} = require 'sedata'

monitor = ()->
  ###*
    不知為何,此法若直接定義, 再用
      組合管家.跟蹤行情 = 跟蹤行情
    則 此地的this並不是組合管家

    故此通過在使用處call
      組合管家.跟蹤行情 = monitor.call(組合管家)
    設定 this 為 組合管家
    然後用:
      return =>
        組合管家 = this
    或:
      組合管家 = this
      return ->

    以下用了雙保險
  *###

  組合管家 = this
  return =>

    ###*
      盡量簡化,將來不用Python接口時,這些代碼也不用改,只需取前半部分
      系統內部用的是前半部分,英文部分是針對Python接口的
      更新券商賬戶數據部分,也可以用單獨循環,設置稍微長一點的間隔,但為求簡便,就一起循環了
    *###
    for 券商接口 in 組合管家.各券商接口
      券商接口.提取資料 '查詢資產,getCapital'
      券商接口.提取資料 '查詢持倉,getPosition'
      #券商接口.提取資料 '查可撤單,getWOrders'
      ###
        注意 不要直接修改
         組合管家.symbols,

        該代碼集在constructor中生成證券objects
        用 .持倉品種(代碼組) 來更新
      ###
      #組合管家.持倉品種(券商接口.賬戶.現有) #僅跟蹤可售,新買入則從自選品種中選擇
      組合管家.持倉品種(券商接口.賬戶.可售)

    sss = 組合管家.symbols
    unless sss.length > 1
      console.error 'observer.coffee>> 出錯: 沒有跟蹤代碼組'
    else
      symbols = sss.join(',')
      #util.log('observer: ', symbols)
      ticks symbols, (組合行情)->
        if 組合行情

          ###
            組合管家只是轉手交給證券品種去應對,如果原先沒有某個代碼,此時組合管家會加入該代
            碼,並出生一個相應證券

            證券品種的應對在 strategies.coffee中定義
            在策略中,指令回執必須是指令個性指令或null,組合管家和證券的代碼無關此事,僅僅轉述

          ###

          組合管家.應對組合即時行情 組合行情, (指令)->
            # 組合管家不管具體賬戶情況,根據組合行情發出指令,
            unless 指令? then return this
            for 券商接口 in @各券商接口
              券商接口.賬戶.操作指令 指令, (個性指令)->
                if 個性指令?
                  # 經過過濾的指令可能跟原來不一樣,所以需要這樣寫
                  命令行 = "#{個性指令.操作},#{個性指令.代碼},#{個性指令.比重},#{個性指令.價位}"
                  unless 券商接口.交易時間() then 命令行 = "test#{命令行}"
                  券商接口.發出指令(命令行, ->)
                  報告 = "#{個性指令.策略},#{命令行},次數:#{個性指令.次數}"
                  console.log 報告
                  if 個性指令.操作 is 'buyIt' then say.speak "#{個性指令.操作},#{個性指令.代碼}"

module.exports = monitor
