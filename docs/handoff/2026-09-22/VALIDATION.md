# 交接验证记录 · 2026-09-22

## 验证方式

从即将提交的 Git 暂存内容导出一个独立临时目录。该目录初始没有 `.godot` 导入缓存、Godot 应用、SQLite 插件、编译后的窗口库或私人存档。仅复制三个原始下载包/头文件缓存，随后完整执行 `npm run game:setup`，重新校验 SHA-256、解压依赖、编译 macOS 原生库和导入全部资源。

这是当前 Mac 上的干净目录验证，**不是另一台物理电脑或 Windows/Linux 的实测**。首次下载地址也分别以 HEAD 请求验证返回 HTTP 200；此次没有重复下载整份运行时。

环境：macOS / Apple M5 Pro，Node.js 24.18.0，Godot 4.7.2 stable `ed1daf0bf`，godot-sqlite 4.9，Apple Command Line Tools。采用图形桌面运行需要窗口的检查。

## 最终结果

| 命令 / 检查 | 结果与范围 |
| --- | --- |
| `npm run game:setup` | 通过；从源码重新生成窗口库、安装插件并完成资源导入，无脚本/资源加载错误 |
| `npm test` | 4 / 4 通过；用量记录规则及音乐格式/循环 |
| `npm run game:test` | 262 项，0 失败；规则、存档、布局及原有动作契约 |
| `npm run game:material-test` | 两档显示密度通过；原色/透明边缘/统一网格错误均为 0；人物之外场景像素变更为 0 |
| `npm run game:character-test` | 动作 16、素材 35、腿部时序 6、起步 33、根位移 72、真实窗口 19 项均通过 |
| `npm run game:pet-test` | 32 项，0 失败；桌宠透明轮廓、交互及窗口切换 |
| `npm run game:environment-test` | 原生画面 20、接地 9、真实窗口 11、清晰像素背景 9 项均通过 |
| `npm run game:raster-test` | 通过；普通/Retina 与镜像场景；两档密度各 60 个农场图层场景，0 不匹配 |
| `npm run game:smoke` | PASS；真实劳动计时、播种/收获、菜单、100 次展开收起、返回桌宠及截图保存 |
| 活跃 v24 素材依赖 | 57 张唯一图像全部存在且 manifest 哈希一致；跨 v17～v24 八个文件夹 |
| `git diff --cached --check` | 通过 |

## 此次发现并修复的测试问题

1. `game/tests/run.gd` 的展开位置预期仍对应旧窗口尺寸。按当前 200×210 桌宠和 1120×740 农场，同一个右下角 `(1300,810)` 对应展开位置 `(180,70)`；修正预期后 262 项全部通过。没有改窗口行为。
2. `game/tests/window_smoke.gd` 在 `frame_post_draw` 等待期间超时，诊断输出定位到截图等待点。参照已有角色烟雾测试，改为等待一次处理帧后主动绘制，再检查 PNG 保存返回值。修改后完整烟雾测试通过。没有改游戏规则或人物素材。

修订后的两个测试文件已同步到干净目录并分别重跑。其他测试在同一干净目录完成。原始失败与诊断仍留在开发机临时产物，下面保存最终可携带日志：

- [Node 测试](logs/node-tests.log)
- [规则与存档测试](logs/game-test.log)
- [静态素材测试](logs/game-material-test.log)
- [角色动作测试](logs/game-character-test.log)
- [桌宠测试](logs/game-pet-test.log)
- [环境测试](logs/game-environment-test.log)
- [像素采样测试](logs/game-raster-test.log)
- [完整玩法烟雾测试](logs/game-smoke.log)

日志中的本机绝对路径已替换为占位符。损坏存档用例故意产生 SQLite “file is not a database” 错误，其预期是拒绝打开并保留原文件；最终计数为零失败。

## 验收边界

测试通过只证明上述代码、数据与渲染约束，不代表用户已经认可走路的美感或最新人物 v57。v57 仍是静态素材候选，最新行走/劳动/桌宠动画还未接入。当前 Godot 框架已在此流程验证，未来跨平台、安装包和 Codex 接入仍需独立开发与验收。
