#!/bin/bash
# darkos-hw-apply -- ES 启动时应用 LED / 风扇持久化配置 (取代 systemd 服务)
# 由 EmulationStation 启动时通过 sudo 调用一次
# timeout: 任何后端异常都不允许阻塞 ES 启动 (window.init 之前同步调用)
[ -x /usr/local/bin/ledctl ] && timeout 5 /usr/local/bin/ledctl apply
[ -x /usr/local/bin/fanctl ] && timeout 5 /usr/local/bin/fanctl apply
exit 0
