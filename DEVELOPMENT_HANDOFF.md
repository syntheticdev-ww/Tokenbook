# Tokenbook 开发交接 · 2026-09-22

这份文件用于**没有聊天上下文、换电脑后的继续开发**。先读本文件，再看 README 的命令说明；不要把历史素材版本号、测试通过或设计文档当成用户已经验收。

## 1. 仓库与当前目标

- 仓库：<https://github.com/syntheticdev-ww/Tokenbook>
- 开发分支：`codex/playable-farm`。当前工作都在这个分支，不要默认切换到 `main`。
- 产品：词元之书，一款精细像素风田园休闲挂机小游戏，作为 Codex 桌面端的独立伴随应用。
- 近期工作重心：先定好女主角的静态素材，再单独解决动作。**最新 v57 只有静态素材和独立实景预览，尚未变成新版动画。**
- 当前仍使用 Godot 4.7.2、GDScript、SQLite 和 macOS 原生窗口扩展；没有迁移到别的框架。当前问题集中在素材、动作制作与像素渲染，继续沿用现有工程即可推进；这不是对未来所有平台需求的保证。

## 2. 在新 Mac 上恢复

当前完整开发启动脚本只支持 **macOS 13+**。需要 Git、Node.js 22+、Apple Command Line Tools（`clang`、`xcrun`）；本次验证机器使用 Node.js 24.18.0。Windows/Linux 的桌宠窗口扩展和安装流程尚未实现。

```sh
git clone --branch codex/playable-farm --single-branch https://github.com/syntheticdev-ww/Tokenbook.git
cd Tokenbook

# 仅在当前仓库设置个人提交身份，避免继承公司邮箱。
git config --local user.name lcoria
git config --local user.email 299729413+syntheticdev-ww@users.noreply.github.com

# 若尚未安装 Apple Command Line Tools，先执行 xcode-select --install 并完成安装。
npm run game:setup
npm run game:material-preview
```

仓库当前没有 npm 第三方依赖，无须先执行 `npm install`。`game:setup` 下载并校验 Godot、godot-sqlite 和扩展头文件，编译原生库，再导入项目。首次准备需要联网；后续正常游戏运行不依赖网络。运行时均安装在项目目录下。

使用 GitHub SSH 推送时，需要在新电脑配置该个人账号自己的 SSH 密钥；不要从旧电脑复制密钥、Codex 登录凭据或全局 Git 配置。HTTPS 克隆不等于已经配置写入认证。

## 3. 四个入口的区别

| 命令 | 实际内容 | 素材与存档 |
| --- | --- | --- |
| `npm run game:material-preview` | 最新女主角在真实农场里的**冻结静态预览**，关闭按钮退出 | `gardener-v57/idle.png`，与 v56 对照；每次使用临时存档 |
| `npm run game:character-preview` | 桌宠点开农场，测试“小屋 → 第一块田”的正向起走、行走、停止 | 行走 `gardener-v24/character.json`，桌宠 `desktop-pet-v1`；临时存档 |
| `npm run game` | 原有完整农场玩法、持久存档与桌宠窗口 | 正式试玩仍用旧玩法动作路径 `farm_motion.gd` / `walk_art.gd`；数据在 `.runtime/m0/` |
| `npm run game:motion-preview` | 较早的动作实验夹具 | 研究入口，不是最新版人物验收入口 |

**在正常游戏或桌宠看到旧人物，并不代表 v57 没有保存。** 不要简单替换动画中的一张静止图，那会造成脸型、比例与帧间形变不一致。

## 4. 目前已实现与尚未完成

已实现：无系统边框的透明桌宠、休闲与徒手挖土切换、点击进入 1120×740 横屏农场、画面内按钮与覆盖菜单、回到桌宠、拖动与菜单栏隐藏；八块田（初始四块）、播种与收获、种子购买与作物出售、主书开垦、离线成长、音乐、SQLite 存档及旧档升级保护。

背景使用 `farm-background-landscape-v3.png`，减少河景占比并向小屋取景；草地已降低刺眼亮黄和饱和度，保留自然草叶细节。场景和点击坐标使用同一投影，像素采样避免背景被过滤模糊。

尚未完成：最新女主角动画、转身与背向、新人物完整劳动衔接、用户对步态丝滑程度的最终验收、正式安装包、Windows/Linux 支持、远征/训练等完整 v0.4 玩法。**游戏尚未接入 Codex 的实际使用事件与 Token 收益**；仓库内探针和设计文档不能视作接入已完成，也不能保证能被动读取官方桌面端所有任务。

## 5. 人物当前状态与不能丢失的设计决定

最新文件：`game/assets/art/gardener-v57/idle.png`。来源、哈希、注册点在同目录 `provenance.json`。

- v54：用户认可的整体基础，肤色稍白、脖子稍短、脸型和背心细节微调。
- v55 / v56：领口内阴影的局部迭代；用户认为 v56 的变化不够明显。
- v57：当前最新候选，把领口内的阴影加强为暖色阶梯像素块，表现短 Y 形和轻微饱满感。**已展示与验证渲染，用户尚未明确最终认可 v57；最新请求是保存推送并交接。**
- 继续保留：棕色单马尾、莓红发圈、奶油色背心、靛蓝短裤、完整腰带、绿色小包、棕靴；简洁前额侧发、闭嘴微笑、柔和小鼻子、不带直角折钩的鼻部、适中的头身比和较短脖子。
- 像素风必须靠清楚的色块与阶梯轮廓体现，不靠模糊、降饱和或乱加颗粒。脸、身体、背景的像素语言需要统一。
- 用户多次反对：脸变丑/头身比漂移、头发凌乱凸起、嘴消失/露齿笑、腰过细/腰带缺口、发光般的艳绿草地，以及走路闪烁/卡顿。
- 身材与领口细节只做克制微调，不夸张。后续局部调整不要顺带重画已认可的脸、发型、服装或动作。
- v25、v39 等实验曾被撤回；版本号较高不等于获准启用。历史文件保留，勿按文件夹名称批量清理。

### 渲染参数

源 PNG 为 1154×1363，逻辑画布 **80×94**，原生采样网格 **160×188**，全身统一采样位置 `(0.25, 0.25)`，面部局部采样覆盖关闭。Retina 与普通屏使用一致的原生像素集合，人物轮廓约 90.5 逻辑像素高。不要误用旧版 112×104 / 224×208 的横向画布，否则会改变比例。

脚底注册点由 `provenance.json` 提供；换素材后检查脚底、人物高度和位置，而不是只看原图。背景与角色之外像素不应随静态素材替换而变化。生成式编辑可能带来目标区域以外的微小差异；像素检查通过并不等于整张人物逐像素保持不变。

## 6. 关键代码与素材关系

| 文件 | 职责 |
| --- | --- |
| `scripts/game.mjs` | 本地依赖准备、各运行入口、临时存档、测试与截图输出 |
| `game/main.gd`、`game/game_overlay.gd` | 游戏状态、桌宠/农场切换、画面内 UI |
| `game/desktop_pet.gd` | 读取 `desktop-pet-v1/animation.json`，休闲/徒手挖土；不发放游戏收益 |
| `native/macos/window_bridge.m` | AppKit 窗口行为，只操作当前应用窗口 |
| `game/farm_rules.gd`、`game/farm_store.gd` | 游戏规则、劳动队列、事务、命令去重、存档升级 |
| `game/farm_view.gd`、`game/farm_environment.gd` / `.gdshader` | 场景、图层、阴影与环境动画 |
| `game/farm_motion.gd`、`game/walk_art.gd` | 原有完整玩法动作路径 |
| `game/farm_character.gd` | 新人物正向测试路线的起停和步态，当前周期 1.05 秒 |
| `game/farm_character_art.gd` | 读取 `gardener-v24/character.json`，选取整帧和注册点 |
| `game/tests/character_material_preview.gd` | 当前 v57 / 上版 v56 在真实场景中的独立静态预览 |
| `game/character_material.gdshader` | 静态预览均匀像素采样；预览脚本显式覆盖网格参数 |
| `game/tests/character_material_tests.gd` | 两档密度、透明边缘、五官色块和原色验证 |

v24 的 manifest 跨文件夹引用 v17～v24 八个目录中的 57 张图像，不能只拷贝 v24 一个目录。此次仓库保留全部项目美术版本及源码，以便完整恢复。`tools/animation_lab`、`tools/pixel_cleanup` 和若干旧测试属于历史研究工具；有些依赖已忽略的历史实验输出，不是新电脑启动的必要步骤。

## 7. 验证与可携带证据

交接验证的实际结果见 [验证记录](docs/handoff/2026-09-22/VALIDATION.md)。静态预览的场景图、局部对照与 JSON 已复制到版本控制内，不依赖旧电脑的 `artifacts/`：

- [最新人物全景](docs/handoff/2026-09-22/evidence/after-scene.png)
- [人物场景局部](docs/handoff/2026-09-22/evidence/after-context.png)
- [v56 → v57 局部对照](docs/handoff/2026-09-22/evidence/neckline-comparison.png)
- [生成提示与源素材映射](docs/handoff/2026-09-22/generation.json)

常用验证命令：

```sh
npm test
npm run game:test
npm run game:material-test
npm run game:character-test
npm run game:pet-test
npm run game:environment-test
npm run game:raster-test
npm run game:smoke
```

带窗口的测试需要已登录的 macOS 图形桌面。测试会创建隔离临时存档，`material-test` 写入 `artifacts/character-reference-v57/pixel-grid/`。若要重建此次局部对照，在 `material-test` 后于仓库根目录运行：

```sh
TOKENBOOK_CAPTURE_DIR="$PWD/artifacts/character-reference-v57/pixel-grid" \
  .tools/godot-4.7.2/Godot.app/Contents/MacOS/Godot --path game \
  --script ../docs/handoff/2026-09-22/detail_preview.gd
```

开发工具缓存、`.runtime/` 私人存档、系统临时数据、全部历史截图/录屏没有提交；16 GB 的本机 `artifacts/` 不作为项目依赖。旧 provenance 内 `/Users/...` 或生成图片路径只是来源记录，不是运行依赖；当前 PNG 已在仓库，v57 提示词另有上面的可携带记录。如果要迁移个人试玩进度，先退出游戏，再单独拷贝整个 `.runtime/m0/`，不要把数据库或登录资料提交 Git。新电脑没有该目录时会建立新档。

## 8. 下一位开发者从哪里继续

1. 先运行 `game:material-preview`，确认看到的是 v57 与自然草地 v3，而不是旧动作角色。先理解最新素材的验收状态。
2. 用户继续提人物局部意见时，只做对应素材调整；保留上版、更新 provenance/预览/相关验证，展示游戏网格下的效果，不把原图放大效果当成实景。
3. 用户确认静态人物并要求动画后，再做统一比例与统一像素网格的整帧动作。重点检查左右腿交叉收腿、脚底着地、头脸/躯干稳定、帧间轮廓闪烁。用户特别指出过“持续走路时，收腿经过另一条腿的位置”卡顿；不能只靠补帧数量或 60 FPS 判定顺滑。
4. 在隔离路线验证“起走 → 持续走 → 停下”，随后补转向/背向/劳动衔接，再接入完整玩法与新版桌宠。不要把一张最新静态图直接混进旧动画。
5. 之后再推进 Codex 接入和更多玩法。保留游戏本体与 Codex 适配器分离的边界，不凭未确认的数据源发奖励。

可直接给新电脑上的助手这段话：

> 在 Tokenbook 的 codex/playable-farm 分支继续开发。先读 DEVELOPMENT_HANDOFF.md、README.md 和 docs/handoff/2026-09-22/VALIDATION.md，检查当前代码再行动。最新女主角为 gardener-v57，只有静态预览，尚未获最终视觉验收；行走测试仍是 v24、桌宠仍是 desktop-pet-v1。保持已确认的精细像素风、人物与场景比例，局部调整不要擅自重做脸、衣服或动作。不要恢复已撤回的动画实验。根据我接下来具体提出的要求继续。
