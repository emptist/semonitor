say = require 'say'
util = require 'util'
{ticks} = require 'sedata'

monitor = ->
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

      # 僅跟蹤可售,新買入則從自選品種中選擇
      組合管家.持倉品種(券商接口.賬戶.可售)

    sss = 組合管家.symbols
    unless sss.length > 1
      #throw 'observer.coffee>> 出錯: 沒有跟蹤代碼組' #為何沒法 catch到?
      組合管家.結束跟蹤()
    else
      symbols = sss.join(',')
      #util.log('observer: ', symbols)
      ticks symbols, (組合行情)->
        if 組合行情

          ###
            組合管家只是轉手交給證券品種去應對,如果原先沒有某個代碼,此時組合管家會加入該代
            碼,並出生一個相應證券

            證券品種的應對在 strategies.coffee中定義
            在策略中,指令回執必須是個性指令或null,
            組合管家和證券的代碼無關此事,僅僅轉述

            event 和 callback 其實是等價的. 因此也可以由 組合管家調動所有品種各自藉助策略
            監控行情發出信號,然後各相關賬戶各自接受信號,定制實施.

            我目前只需要自己賬戶操作,不必支持多賬戶,但已經設置好多賬戶機制,後人可隨意發揮.
            重點就是 賬戶和組合各有自己線程,兩個互相交換信息即可.即,交易接口在組合管家這裡掛
            號登記,登錄時把自己持倉報送組合管家,補充品種,一併觀察,組合管家則隨時通報交易指令.

            如果我有時間,會盡量實現兩個process分開然後採用 websocket之類的雙向溝通方式連接.
            如果我沒時間,那後人如果需要,可以採用當時最有效的技術,分開這兩個體系,並互相通訊.
          ###

          組合管家.應對組合即時行情 組合行情, (指令)->
            # 組合管家不管具體賬戶情況,根據組合行情發出指令,
            unless 指令? then return null
            報告 = "#{指令.指令名},#{指令.操作},#{指令.證券代碼},#{指令.比重},#{指令.委託價位}"
            util.log 報告
            if 指令.操作 is 'buyIt' then say.speak "#{指令.操作},#{指令.證券代碼}"

            for 券商接口 in 組合管家.各券商接口
              券商接口.賬戶.操作指令 指令, (個性指令)->
                if 個性指令?
                  # 經過個別定制,指令跟原來不一樣,需要這樣寫
                  命令行 = "#{個性指令.操作},#{個性指令.證券代碼},#{個性指令.比重},#{個性指令.委託價位}"
                  # 由券商接口來管理開市期間或稱為交易時段,比較合理.
                  # 非交易時段,則命令加test,交易接口須直接忽略這類命令
                  unless 券商接口.交易時間() then 命令行 = "test:#{命令行}"
                  券商接口.發出指令(命令行, ->)

module.exports = monitor
