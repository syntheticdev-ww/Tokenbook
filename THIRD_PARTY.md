# 第三方依赖与素材

本清单针对当前农场可玩版开发环境；公开分发前仍需完成应用签名、公证、完整依赖许可证装配与目标系统验收。

| 依赖 | 当前锁定 | 来源与许可 | 仓库处理 |
| --- | --- | --- | --- |
| Godot | 4.7.2 stable / ed1daf0bf | [官方发布](https://godotengine.org/download/archive/4.7.2-stable/)，[MIT 及第三方声明](https://godotengine.org/license/) | 下载至忽略的 `.tools/`；保留官方应用包 |
| godot-sqlite | v4.9，SQLite 3.51.0 | [维护者发布](https://github.com/2shady4u/godot-sqlite/releases/tag/v4.9)，MIT；SQLite 公共领域 | macOS 框架及其 LICENSE.md 解压至忽略的 `game/addons/` |
| GDExtension C 接口头文件 | godot-cpp 的 godot-4.5-stable，SHA-256 锁定 | [上游头文件](https://github.com/godotengine/godot-cpp/blob/godot-4.5-stable/gdextension/gdextension_interface.h)，MIT，文件自带声明 | `.tools/gdextension_interface.h`；使用可在 4.7.2 验证的 ABI 接口 |
| Noto Sans SC 可变字体 | 2026-09-14 下载快照，SHA-256 见下 | [Google Fonts 源文件](https://github.com/google/fonts/tree/main/ofl/notosanssc)，SIL Open Font License 1.1 | 字体原始字节及 OFL.txt 位于 `game/assets/fonts/`；未修改字体 |

下载校验（SHA-256）：

```text
Godot macOS zip: c58a24e31d720be9d62f60cb5627c4e695fb72f21b0cfe1bc9ccaa9a3b3ba63e
godot-sqlite addons.zip: 95e91b72fe32984a84edaf6357a78753661f37a170cb362f5b948e0ede7c2cb0
GDExtension header: a40ac4fca0f526910bd0e6afc6da6c169f50801c84d4e29c4ce2891cadc7b550
NotoSansSC.ttf: a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da
```

农场、房屋、角色、作物与小猫为本项目通过内置图像生成工具制作的 AI 辅助像素素材，沿用用户确认的构图与角色方向，未提取参考游戏的角色、贴图或音频。素材来源、实际分辨率和复现用提示词规格见 `game/assets/art/README.md`。图集目前为可玩版资源，不代表完整多方向动画与最终美术验收已经完成。

`game/assets/audio/morning.wav` 由本项目 `scripts/ambient-music.mjs` 的音符、包络和波形合成生成，无第三方音频采样。叶子菜单栏图标与窗口代码为项目自有实现。公开分发前仍需对完整素材清单及相应平台条款做发布审查。
