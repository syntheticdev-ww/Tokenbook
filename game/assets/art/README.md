# 农场可玩版素材

## 动作与场景精修 v4（2026-09-15）

本轮只用内置 imagegen，以原 `gardener-gameplay-v2.png` 为人物参考、`farm-background-cohesive-v2.png` 为画风 / 光线参考。没有外部 CLI / API fallback；两个最终图集原始字节已复制进仓库，旧版本保留。

- `gardener-walk-v4.png`：实际 **1086 × 1448**，前斜向八帧＋后斜向八帧。来源 `exec-70f68f1e-2bea-4949-8c9c-58609afb3485.png`，初稿 `exec-f2de5ee0-1bfb-4939-a4fb-22bb809dbae6.png` 经一次交替落脚纠正。
- `gardener-work-v4.png`：实际 **971 × 1619**，八个浇水姿势、八个采集姿势、四个待机 / 侧身姿势。来源 `exec-9594a8a9-7d6f-450d-b6d5-1313adb489c9.png`。

生成结果没有严格遵循提示中的整图分辨率和均匀外边距。运行时根据实际内容标定：行走从 y=30 起按 350 高分行；劳动从 y=25 起按 310 高分行，均分四列。每张图集固定缩放，列宽映射为 28.5 世界像素；各帧只校准位置，不单独放大身体。待机 / 行走约 31–33 世界像素，弯腰自然变矮。工作中立帧复用同一待机绘图，避免边界体型改变。

行走 X 锚点以头部像素位置校准，Y 锚点对齐足底，避免换支撑脚时整个人左右跳；测量工具为 `game/tests/atlas_registration.gd`。劳动采用准备、保持、收势三段；采集起身反向复用中间姿势，避免从深弯腰跳到站直。取消整张角色纵向缩放的假呼吸。背影按路线的实际远近方向选择，左右仍为镜像，**不是完整手绘八方向或骨骼动画**。

实际提示词（行走初稿）：

```text
Use case: identity-preserve.
Asset type: production HD pixel-art game animation atlas, not a concept illustration.
Input image 1: our existing adult gardener, sole identity/outfit/proportion reference. Input image 2: our approved farm, sole palette/light/camera reference; DO NOT reproduce its environment.
Preserve the adult brown ponytail woman with small teal ribbon, sage fitted sleeveless top, tan shorts, short brown boots, tiny blue-green belt pouch. Compact approximately four-head gameplay anatomy; do not make her taller, more chibi, more heavily clothed, or redesign her face.
Finish: premium handcrafted PIXEL art, deliberate square color clusters and stepped edges, readable fine fabric/hair details. Slightly top-down isometric camera. Warm sunlight from upper left, quiet sage/brown colored outlines, soft olive reflected light at boots, subdued cool shadows. Not near-black thick sticker outlines, glossy skin, 3D, blur, smooth illustration, or extra saturation.
Critical frame registration: EXACT four columns. Every cell 384 wide by 512 high, same character scale in EVERY cell. Straight standing figure from local y=64 to y=448 in every row, fixed floor y=448. Pelvis centered local x=192. Bent poses must naturally become shorter, never rescale to fill. Preserve face size, torso length, boot size, and palette across all cells. At least 32 px empty margins. Pure flat exact #FF00FF background, no shadows or flooring, no text, no grid lines, no labels. All limbs fit their cells. Small restrained movements suitable for a calm farming game.
Canvas: 1536x2048. Exactly 4 columns by 4 rows = SIXTEEN cells.
First TWO ROWS: EIGHT chronological phases of one continuous relaxed walk facing DOWN-LEFT (toward the viewer), numbered here only for instructions, no printed numbers. 1 left leg contacts forward and right arm counter-swings; 2 weight lowers over left foot; 3 right foot passes under body; 4 right foot swings forward; 5 RIGHT leg contacts forward and LEFT arm counter-swings; 6 weight lowers on right foot; 7 left foot passes under body; 8 left foot swings forward returning into frame1. Contact frames MUST have opposite planted legs, intermediate frames feet under hips. No knee kicks, no running. Small shoulder counterrotation and ponytail follow-through; keep skull and ribcage identical. At most 6 image pixels of vertical head rise over full cycle.
Last TWO ROWS: the SAME eight walk phases with same scale and phase timing, but viewed from BACK THREE-QUARTER walking UP-LEFT (away from viewer); show the back of her head, ponytail and shirt. No front-facing eyes in back view. Do not just mirror the front poses. Ground plane, camera and light must remain identical to first two rows.
No watering can or objects in hands. Each row continues the cycle from preceding row; row3 begins the rear-facing cycle.
```

实际提示词（交替落脚纠正）：

```text
Use case: precise-object-edit. Edit this exact 4-column by 4-row pixel sprite atlas. Keep same image dimensions, character identity, body scale, face, hair, outfit, palette, magenta background and cell positions.
CRITICAL WALK-CYCLE CORRECTION: currently nearly every cell has the SAME leg forward. This must be a real alternating-foot WALK.
Change ONLY limb poses in ROW TWO (cells 5,6,7,8) and ROW FOUR (cells13,14,15,16). Preserve ROW ONE and ROW THREE, and preserve every head and torso.
ROW TWO, first cell: the woman's NEAR/front-visible leg must now trail diagonally to image RIGHT, knee behind hip, ankle heel lifted; the FAR/back leg must be extended toward image LEFT, heel planted on ground. The two legs must visibly cross underneath pelvis. This is OPPOSITE the leading leg of row1cell1. Near arm swings to LEFT/front while far arm swings back.
ROW TWO second cell: put weight onto the far planted foot with near foot starting to lift from behind.
ROW TWO third cell: near leg swings underneath hip, knees passing, ankles adjacent, near knee slightly bent.
ROW TWO fourth cell: near leg swings forward to image left ready to reach the original row1cell1 contact. Arms follow naturally in opposition. Fixed pelvis; no head resizing.
ROW FOUR must likewise show the opposite planted leg to ROW THREE, from the back view: near leg trails image RIGHT while far leg reaches LEFT in first cell, then weight, passing, swing as above. Keep her facing BACK-left in row4, no face.
IMPORTANT: Do not mirror the whole character. Do not merely move her legs together while retaining the same lead. Rotate each leg from its own hip. No new hands, no extra boots, no shadows or labels. Crisp coherent pixel clusters.
```

实际提示词（劳动与待机）：

```text
Use case: identity-preserve.
Asset type: production HD pixel-art game animation atlas, not a concept illustration.
Input image 1: our existing adult gardener, sole identity/outfit/proportion reference. Input image 2: our approved farm, sole palette/light/camera reference; DO NOT reproduce its environment.
Preserve the adult brown ponytail woman with small teal ribbon, sage fitted sleeveless top, tan shorts, short brown boots, tiny blue-green belt pouch. Compact approximately four-head gameplay anatomy; do not make her taller, more chibi, more heavily clothed, or redesign her face.
Finish: premium handcrafted PIXEL art, deliberate square color clusters and stepped edges, readable fine fabric/hair details. Slightly top-down isometric camera. Warm sunlight from upper left, quiet sage/brown colored outlines, soft olive reflected light at boots, subdued cool shadows. Not near-black thick sticker outlines, glossy skin, 3D, blur, smooth illustration, or extra saturation.
Critical frame registration: EXACT four columns. Every cell 384 wide by 512 high, same character scale in EVERY cell. Straight standing figure from local y=64 to y=448 in every row, fixed floor y=448. Pelvis centered local x=192. Bent poses must naturally become shorter, never rescale to fill. Preserve face size, torso length, boot size, and palette across all cells. At least 32 px empty margins. Pure flat exact #FF00FF background, no shadows or flooring, no text, no grid lines, no labels. All limbs fit their cells. Small restrained movements suitable for a calm farming game.
Canvas: 1536x2560. Exactly 4 columns by 5 rows = TWENTY cells. All poses face DOWN-LEFT toward the crops. Feet planted at the SAME floor location throughout; no walking.
ROWS 1-2: eight consecutive stages of a single gentle watering action, progressing left-to-right then next row:
0 neutral relaxed standing, empty hands and NO can;
1 reaches down to hold small dull blue-gray watering can low at side;
2 brings can gently to waist, elbows bent;
3 gently extends spout down-left, knees soft;
4 smoothly tilts can to pour down-left;
5 almost same poured position as4 with a small natural wrist adjustment, steady body;
6 returns can upright closer to body;
7 lowers can to side, relaxed shoulders. No emitted water drops: game engine supplies those. Can has restrained detail, not huge or ornate.
ROWS 3-4: eight stages of gentle gathering with empty hands and NO can:
8 neutral relaxed standing (match frame0 exactly);
9 small anticipatory lean, hands start reaching;
10 soft knee bend, waist leaning;
11 deeper reach down-left, one hand supporting near knee;
12 lowest grounded reach;
13 gently pull hands back toward body;
14 rise halfway;
15 return to relaxed standing (match frame0). No sudden squat or exaggerated crouch.
ROW 5: four idle/turn frames with NO tools. 16 exact same front-left relaxed neutral as frame0; 17 identical pose with a brief natural blink (ONLY eyelids change); 18 relaxed side-left profile between front and back; 19 relaxed BACK-left three-quarter (face hidden), matching scale and posture. Frame17 must not smile, bob, or move hair/arms/body relative to16.
Do not add produce in hands, detached marks, decorative effects or shadows.
```

下面为历史版本记录，当前运行时人物使用上方 v4 图集。

## 动作连续性更新（2026-09-15）

新增两张由内置 imagegen 生成的 1536 × 1024 图集，均为 4 列 × 2 行：

- `gardener-walk-v3.png`：八帧慢步循环。原始生成文件 `exec-4039f8b2-d0d2-4873-974b-1da955fce263.png`。
- `gardener-work-v3.png`：第一行四帧取壶 / 抬壶 / 伸壶 / 倾倒，第二行四帧俯身采集。原始生成文件 `exec-6713ac2c-91e4-49b8-b797-e428f3c45556.png`。

使用既有人物 `gardener-gameplay-v2.png` 作为身份、服装、比例与画风参考；旧图集仍提供两帧待机。原始生成图已直接复制进本目录，运行时不依赖生成缓存。没有外部 API / CLI fallback。脚底锚点逐帧校准，所有人物单元均按 30 × 40 世界像素同尺度绘制；步态按真实行走距离推进，站定后再劳动。当前为左右镜像朝向，不代表完整四向 / 八向角色图集或骨骼动画已完成。

实际提示词（八帧走路）：

```text
Use case: identity-preserve. Production animation sprite sheet for our pixel farm game. Reference image is ONLY the exact character identity, compact proportions, outfit, pixel style and lighting to preserve: adult brown-ponytail woman with teal ribbon, green sleeveless top, tan shorts, short brown boots. Preserve her exact compact 4-head gameplay proportions, not a tall portrait, not a new face. Same colored outlines and warm light. Exact 4 columns x 2 rows, eight equally sized cells on pure flat #FF00FF magenta, no lines, no text, no backgrounds, no shadow, no detached particles. Target 1536x1024, cell384x512. Same body scale across all cells, feet baseline y=440 within EACH cell, standing head around y=35. Torso pivot centered x=192 in EACH cell. Leave enough padding for all limbs. Whole character visible, identical image scale, no per-cell resizing. Draw EIGHT consecutive frames of ONE smooth slow relaxed WALK cycle, facing three-quarter DOWN-LEFT in ALL frames. No tools. Read left to right, then second row. Frame1 left leg forward contact / right arm forward; frame2 weight down and knee bends; frame3 legs passing with rear foot raised; frame4 right leg coming forward / slight body rise; frame5 RIGHT leg forward contact, LEFT arm forward; frame6 weight down on right foot; frame7 opposite passing pose; frame8 left leg swinging forward ready to loop into frame1. Actual leg positions and arm swing must differ in all eight frames, not repeated poses. Subtle ponytail follow-through delayed after shoulder movement. Small natural gait, NOT running, jumping, marching or kicking. Her head stays aligned horizontally, hips move only slightly vertically. The two contact frames have opposite leading legs; intermediate frames have feet underneath hips. Genuine crisp pixel clusters, no smearing or motion blur, no ghost legs.
```

实际提示词（四帧浇水 / 四帧采集）：

```text
Use case: identity-preserve. Production animation sprite sheet for our pixel farm game. Reference image is ONLY the exact character identity, compact proportions, outfit, pixel style and lighting to preserve: adult brown-ponytail woman with teal ribbon, green sleeveless top, tan shorts, short brown boots. Preserve her exact compact 4-head gameplay proportions, not a tall portrait, not a new face. Same colored outlines and warm light. Exact 4 columns x 2 rows, eight equally sized cells on pure flat #FF00FF magenta, no lines, no text, no backgrounds, no shadow, no detached particles. Target 1536x1024, cell384x512. Same body scale across all cells, feet baseline y=440 within EACH cell, standing head around y=35. Torso pivot centered x=192 in EACH cell. Leave enough padding for all limbs. Whole character visible, identical image scale, no per-cell resizing. Draw a grounded slow gardening movement sequence. First row FOUR consecutive watering frames: relaxed holding can low, gently raising can, extending spout down-left, tipping can to pour. The body and legs remain grounded, arm and can gradually move across these poses, never jump drastically. No water droplets (engine supplies them). Second row FOUR consecutive gathering frames: shallow lean with hands close to waist, lean down and reach forward, deepest bend with hand reaching down-left, lift gently with elbow bent returning toward waist. Hands empty; no harvested object drawn. This is a gentle back-and-forth working loop, not combat. Keep shoes fixed on the same baseline in all work poses, torso over same x center; bent poses become shorter rather than being enlarged. Natural adult posture, no stretching, no duplicate poses, no added tools except watering can in first row.
```

## 人物与环境协调更新（2026-09-15）

当前运行时使用 `farm-background-cohesive-v2.png`（1329 × 1183，来源 `exec-e98ee025-133a-4494-afa8-c3e46ddab76c.png`）和 `gardener-gameplay-v2.png`（1536 × 1024，来源 `exec-45234ba2-6280-47f1-8454-a05d29efe070.png`）。旧素材保留。两个素材均由内置 imagegen 生成并以原始字节复制到仓库，没有 API / CLI fallback，没有提取商业游戏素材。

人物改为小尺寸游戏比例，统一 30 × 40 的图集单元绘制尺度，可见站立高度约 32 世界像素；按帧设置足底锚点，弯腰帧不单独放大。接地阴影朝向固定在世界坐标，不随左右转身翻转。猫的绘制单元降为 21 × 21。混合树林替代重复松树，保留房屋 / 河桥的位置、对角田地和全部存档语义。该轮每动作两帧；最新动作图集与边界见上方更新。

实际提示词（背景）：

```text
Use case: precise-object-edit. Asset type: original production pixel-game background, full canvas, no UI. Edit Image 1, our existing isometric farm environment.
Keep the EXACT camera, aspect ratio, composition, farmhouse size/location/architecture, farmhouse door and porch position, roof silhouette, farm tools and barrel, river, stone bridge and mountain skyline. Keep lower half a flat open buildable grassy clearing with no characters, cats, farm beds or paths added. This is a game background, not a picture with a center bulge.
Improve visual cohesion and environmental variety. Replace the repeated rows of identical triangular conifers with a naturally composed mixed woodland: rounded spreading oak crowns, slender pale-trunk birches, one soft willow near the water, scattered irregular conifers and a few small orchard trees. Vary silhouettes, age, crown size, color subtly; arrange into asymmetrical groups with calm grassy gaps. Distant forest should merge into quieter cool blue-green masses, not hundreds of individually outlined identical trees. Retain scenic village and layered mountain depth.
Make grass much calmer: broad softly shaded sage/olive meadow color clusters, only sparse intentional tufts near edges, NOT white noise, NOT evenly distributed confetti dots. Retain a few localized daisies, subtle worn earth around doorstep, tiny coherent moss and stone accents. Foreground must stay open and unobstructed. Same charming warm village-farm cottage, terracotta tiles, readable stone and timber details, but no oversharpening.
Medium: crisp intentional HD pixel art with clean square pixel clusters, finite harmonious warm sage, moss, buttercream, terracotta and slate-blue palette. Consistent soft sunshine from upper left, cool subdued shadows cast lower right. No painterly blur, no photorealistic textures, no 3D render, no overly saturated acid greens. High detail allocated to house and special environmental landmarks, restful low detail on playable ground. No labels, no borders, no watermark.
```

实际提示词（角色，先生成再局部纠正步态）：

```text
Use case: style-transfer. Asset type: production pixel-game animation atlas, NOT concept art or a portrait. Image 1 is our existing heroine identity/outfit reference only. Image 2 is our farm palette/light/camera reference only. Create an original new gameplay sprite sheet of that same ADULT woman: brown ponytail with small teal ribbon, sage sleeveless fitted top, tan practical shorts and short brown ankle boots. Keep this identity and light outfit, no new armor or cape.
Critical: redo anatomy as a compact genuine small-world game sprite with about FOUR heads in total height, shortened legs and slightly larger readable head; clearly adult, not a toddler or oversized chibi head. Camera is slightly top-down three-quarter view matching isometric farmland. No long fashion-model legs, no realistic portrait rendering, no smooth anime illustration shrunk down.
Exactly 4 columns by 2 rows of equally sized cells, eight full-body poses. Row 1: idle eyes open, idle blink, walking left-facing step A, walking left-facing step B (opposite planted foot). Row 2: watering left with small metal can pose A, watering pose B slight tilt, gathering bent forward pose A, gathering pose B. Face mostly camera/down-left. Full feet and tools in each own cell, no overlap.
Use a fixed common scale for the body across all eight cells. Feet occupy the same baseline in every cell, centered under torso; bent frames genuinely shorter, not stretched. Leave generous clean padding around every sprite. The figure should look as if drawn on a roughly 24 by 36 pixel footprint with deliberate square pixel clusters at an integer enlargement, about 8 pixels across the head, not micro-dithered high-resolution shading. Readable expressive eyes from 1-2 pixel dots, simple stepped hair highlights, 2-3 shading values per material. Clean colored outline, not heavy black contour. Warm light upper left, muted cool shadow on lower-right body. Palette harmonizes with farm, not overly saturated skin. No cast shadow baked into sheet. Flat exact pure magenta #ff00ff background everywhere between sprites, no checkerboard, no floor, no text, no grid lines, no extra ornaments. Crisp nearest-neighbor style, not blur or anti-aliased curves.
```

```text
Use case: precise-object-edit. Edit this pixel sprite sheet with only these changes. Preserve identical 4 columns by 2 rows, same exact canvas, same character, same outfits, same pixel style, same scale and same magenta background, all cell locations unchanged.
Top row fourth cell ONLY: make this the opposite walking step to top row third cell. Swap which leg is forward: currently the near/front leg reaches left. Now near/front leg should trail backward to the right, with far leg planted forward-left, and arms swing oppositely. Must read as a distinctly opposite leg stride, not an identical duplicated pose. Keep her facing left; DO NOT mirror entire body.
Bottom row second cell ONLY: remove all detached blue water droplets outside the can; game engine supplies animated droplets. Preserve tilted watering can and pose.
Do not change remaining six frames. No text, labels, checkerboard, shadow or extra parts.
```


使用 Codex 内置图像生成工具制作，未使用 API / CLI fallback。图片原始字节复制到本目录，运行时不依赖生成缓存目录或网络。以下为素材路径、实际分辨率、来源和复现用提示词规格（生成模型不保证逐像素复现）。

| 本地文件 | 尺寸 | 用途 / 原始生成文件 |
| --- | --- | --- |
| `approved-direction.png` | 1536 × 1024 | 用户确认的像素方向，保留作为风格参考；首版还用于未开垦土地纹理。`exec-0b0565ed-46b5-4b80-b63b-743d537d445d.png` |
| `farm-background.png` | 1536 × 1024 | 首版地景（当时使用左侧 1152 × 1024）；斜侧版继续复用其中的土路纹理。`exec-60924f74-9034-4f75-b07b-d7c9b39a170c.png` |
| `gardener-atlas.png` | 1536 × 1024 | 4 列 × 2 行，依次为待机、左行、浇水、采集，每种两帧。`exec-08f1852b-b3b1-40be-8fe9-d9be4afe7beb.png` |
| `farm-atlas.png` | 1254 × 1254 | 4 列 × 4 行，作物和小猫。`exec-c69161db-488e-451f-9eb8-fe21bcb70a56.png` |

原始生成文件来自当前任务的 `$CODEX_HOME/generated_images/`，仅用于追溯；上述文件已经独立保存在仓库中。

## 提示词规格

共用方向：高清精细像素艺术，2.5D 俯视田园游戏，清楚的像素轮廓与分组阴影，不使用平滑 3D 渲染、景深模糊或写实皮肤。暖阳、绿色草地、平静治愈的感觉；保持已确认的比例与整齐布局，不增加遮挡前景，不复制商业游戏素材。

1. **场景编辑**：以上一版确认图为编辑目标，只删除游戏场景中的人物、小猫及八块田内部的作物、杂草和石头，八块田内部恢复干净裸土。保留房屋大小和宽度、村庄农场小楼细节、木栅栏、田埂、田间道路、工具、远处河流石桥、山峦与村庄，以及右侧设定栏的位置和比例。不要移动地块、房屋或镜头；人物和作物将在引擎中独立绘制。
2. **人物图集**：以已确认的成年女性园丁为角色参考，棕色头发、绿色无袖上衣、浅棕短裤、棕色靴子，保留原角色的成熟与轻盈，不增加盔甲或夸张比例。4 列 × 2 行等大单元，依次两帧放松待机、两帧向左走、两帧站在田外用水壶浇水、两帧俯身采集。严格统一人物尺度、足底基线、镜头和光照，完整保留头脚与工具，不切边、不写文字。后续精准编辑仅将背景换成纯洋红色，保留人物轮廓和所有八个姿势。
3. **农场图集**：以已确认场景的像素画风为风格参考，4 列 × 4 行等大单元、统一镜头和暖阳照明。前四列依次为萝卜、小麦、土豆和红莓；前三行依次为幼苗、生长、成熟。最后一行依次为坐着睁眼的橘猫、相同位置闭眼的橘猫、小石头、野草。每个元素单独居中、完整留边，纯洋红色背景，无标题、网格线或文字。红莓和石草单体暂作为后续资源，本版可种植作物仅前三种。

## 引擎使用约定

- PNG 图集背景并非真正 alpha；`chroma_key.gdshader` 在绘制时剔除洋红色。没有把伪棋盘格当透明，也没有修改原图字节。背景和图集色彩不能二次乘算，否则整体会变暗。
- 全部使用最近邻过滤；逻辑世界保持 384 × 342。首版地景用设定板左侧，斜侧版改用新地景的完整画幅。原生 Retina 窗口独立按系统比例显示 UI，画面不以模糊滤镜冒充高清。
- `farm-atlas.png` 的实际边长不是 4 的整数倍，源矩形使用纹理实际大小 / 网格数的浮点边界，不能假设图集是 1024 或把单元取整后累积错位。
- 人物与猫为独立绘制对象；田块各自根据存档显示幼苗、生长或成熟阶段；背景不烘焙产出，不出现静态假作物。
- 人物目前是每动作两帧的首版图集；左右行走以翻转处理，完整方向和更自然的帧间运动仍需后续精修。此文件不表示已经完成正式美术交付。

## 斜侧布局更新

参考用户新图时只提取了斜侧布局要求，**没有把该截图传入图像生成工具**。两个新图都只以本项目 `approved-direction.png` 为风格与建筑参考；现有角色、猫、作物、音乐和游戏 UI 继续复用。

## 连续步态分层素材（2026-09-15，已否决并停用）

用户实看后认为固定身体、独立拉腿和动作切换破坏了老版连贯感。该图集及 `farm_gait.gd` / `gardener_rig.gd` 只保留作实验历史，当前运行时不引用。正式绘制已恢复 `gardener-walk-v4.png` 完整帧；固定图集比例为行走 1.0、劳动 0.95，用于匹配人物实际高度，不是逐帧缩放。活动时最高 60 FPS。

以下为当时生成记录，不是当前方案说明：

`gardener-rig-v1.png` 是本轮通过内置 imagegen 生成并复制到项目的 2 行 × 5 列分层图集，仅以本项目 `gardener-walk-v4.png` 为角色参考。每行依次为身体、远侧手臂、近侧手臂、远侧腿、近侧腿；上行为前视、下行为后视。背景仍使用既有非破坏性色键，不修改原图字节。`gardener_rig.gd` 明确登记裁切矩形、髋/膝/踝和鞋底中心，避免把自动生成的边距当成真实关节。旧素材保留。新的图层只用于行走，待机和劳动仍使用原工作图集。

实际生成提示词（内置工具，不是 CLI/API）：

> Use case: precise-object-edit. Production game asset, NOT a walk-cycle sheet. Derive a CUTOUT ANIMATION PARTS ATLAS from the attached original adult female gardener character. Keep her exact identity, original proportions, brown ponytail with sage bow, sage sleeveless top, tan shorts and belt, small green hip pouch, short cream socks and brown ankle boots. Preserve the warm HD pixel-art clusters, dark brown contour and soft warm light. This is for a tiny isometric cozy farm game; no realistic painting or vector style.
>
> Layout: exactly TWO ROWS, FIVE COLUMNS, ten equal rectangular cells, wide canvas, generous clear margins. Each cell contains ONE isolated cutout part. Row 1 uses the existing front three-quarter facing LEFT view. Row 2 uses the existing rear three-quarter facing LEFT view.
>
> In EACH ROW, columns LEFT to RIGHT: (1) head, hair, neck, sleeveless torso AND shorts with pouch together as one connected BODY cutout, NO arms and NO legs, but complete shoulders and shorts hems; (2) FAR ARM complete from rounded shoulder to relaxed hand, straight and hanging down, no torso; (3) NEAR ARM complete from rounded shoulder to relaxed hand, straight and hanging down, no torso; (4) FAR LEG complete from rounded upper thigh under shorts to brown boot, straight knee, flat sole, toes facing left, NO shorts or torso; (5) NEAR LEG complete from rounded upper thigh under shorts to brown boot, straight knee, flat sole, toes facing left, NO shorts or torso. Each part appears only once per cell. Legs have bare thigh, bare knee and shin, cream sock, brown boot. Both near and far legs MUST be separate unclipped cutouts with complete thighs, knees, socks and feet. Arms likewise have complete shoulder and elbow areas for articulated rendering.
>
> All parts use exactly the SAME pixel density and physical scale; do not enlarge small parts to fill cells. Body roughly twice the height of a leg. Limbs must be straight neutral rest-pose, not crossed walking poses. Maintain the original broad head / small body farm-character proportion. Same anatomy and clothes in both views. Solid pure magenta #ff00ff background for the game's existing color-key pipeline. NO ground, NO cast shadows, NO labels, NO lines, NO numbers, NO layout borders, NO duplicates, NO assembled full characters, NO other art.

实际输出并未完全遵守各部位相对大小，因此每类部位使用固定的项目标定比例（身体、手臂、腿分别固定），不是每帧重新缩放。腿部通过关节控制投影形变；鞋子在支撑阶段保持固定形状和世界位置。此方案不等于逐帧手绘 120 张完整人物，也不是全 3D 游戏。

| 新文件 | 实际尺寸 | 来源 |
| --- | --- | --- |
| `farm-background-isometric.png` | 1329 × 1183 | `exec-d1bbb3f3-10c7-495f-990b-bd4391800c3e.png` |
| `terrain-isometric-atlas.png` | 1774 × 887 | `exec-43328b33-85b3-4b92-8fcd-0d2a61684245.png` |

使用内置图像生成工具，未调用 fallback CLI。新地景使用完整画幅，不再截取旧设定板的左侧。旧图保留，便于对照。新的 2 列 × 1 行地形图集是空田 / 待开垦田；仍用运行时洋红透明键。地块编号、开垦状态、作物和存档内容不因画面旋转重新排列。

田埂与门廊连接的小路复用首版 `farm-background.png` 中间通道的土路像素（源 x=572..602、y=548..626），分成短段映射到斜向路线，保持原场景的泥土、碎石色彩和纹理，不使用大块纯色 UI 线条替代。

统一投影为 `world = (132,186) + u*(48,24) + v*(-48,24)`。8 块田按 `id = row*4+column` 排列，点击多边形、作物根部、田埂路线均复用同一投影。人物、猫和作物按脚底 Y 排序，避免正面版逐田绘制导致的前后错层。地形图片的实际平面中心按 `(53,50)` 注册到 106 × 106 的绘制矩形；选择框用可种植区域，不包含外侧立柱。

### 实际使用的提示词：斜侧地景

```text
Use case: precise-object-edit.
Asset type: production pixel-art farm game environment background, without actors or farm plots, for separate interactive tile layers.
Input image 1 is the sole ART STYLE and architectural identity reference: our already-approved Tokenbook pixel farm design. Ignore the right-hand character study panel as a composition. Render ONE full-bleed single scene, no panel, no text, no UI.
Primary request: change the farm's spatial layout and camera to a clearly oblique 3/4 isometric 2.5D view, with the ground axes running diagonally down-right and down-left at about 26.6 degrees. Keep precisely the established refined high-definition pixel-art material language, warm sunshine, tiny pixel clusters, green meadow colors, terracotta roof village farmhouse, cream plaster and timber, detailed windows with flowers, chimney, small farm tools, barrels and wheelbarrow. Not full 3D, not smooth casual mobile-game rendering, not a new art style.
Canvas composition: nearly square landscape 1536 by 1368 pixels, filling the entire canvas. Upper 30% is our same atmospheric layered blue mountains, evergreen woodland, tiny distant village and lovely river with old stone arch bridge to the LEFT. A modest broad farmhouse in the UPPER RIGHT quadrant (roughly x 62%-95%, y 17%-49%), recognizable as the same comfortable terracotta-roof farm village small house, now seen from its corner so both walls and roof agree with the diagonal ground axes. Keep its compact proportional footprint, not a tower or narrow hut, no thatched roof. A short doorway apron and tools are confined near the house, not scattered over gameplay space.
The lower 52% and central-left area is a CALM FLAT, UNBROKEN WALKABLE GRASS CLEARING, with no crops, no garden beds, no dirt patches, no rocks or shrubs occupying that clearing, because eight diagonal garden tiles will be placed there in the game engine. This is essential for a usable game background. Keep clearing grass finely pixel-textured but quiet and low-contrast with open breathing space, subtle little daisies at OUTER margins only. No convex mound or bulging foreground, no fisheye, no vignette, no foreground fence, tree canopy or leaves covering the bottom or any central gameplay space. The meadow plane recedes consistently toward the far river; do not create a floating island or cutaway diorama.
No people, no cat, no animals, no pre-rendered crops; these remain separate sprites in the game. Preserve warm healing atmosphere and the approved pixel clarity/detail.
```

### 实际使用的提示词：斜侧田块

```text
Use case: stylized-concept.
Asset type: game terrain sprite atlas, exactly TWO terrain sprites in a 2-column x 1-row grid. Each cell is square and the two cells have identical dimensions, scale, camera, registration and ground-level baseline. Output 1536 by 768 pixels.
Input image is only our approved Tokenbook refined pixel-art style and farm material reference. Use no other game's visual language.
LEFT cell: an empty, neatly tilled diamond-shaped raised farm bed with rich granular dark brown pixel soil, a very low thin wooden board rim and four tiny corner pegs, unobstructed interior, NO crops.
RIGHT cell: the EXACT SAME diamond bed, same camera, size, rim, peg locations and perspective, but containing fine meadow grass, a few small wild sprouts and two little stones waiting to be reclaimed. These details must be wholly inside its rim. No trees, no giant weeds, no foreground obstruction.
Camera: oblique 3/4 isometric view. Both ground axes slope 1 pixel down for every 2 pixels horizontally. The plane is a clean symmetric diamond with a 2:1 width-to-height ratio, NOT a front-facing trapezoid. The terrain surfaces of BOTH cells must have their diamond corners at these normalized cell coordinates: TOP (50%,27%), RIGHT (93%,48.5%), BOTTOM (50%,70%), LEFT (7%,48.5%). Pegs and board thickness should extend only a few percent outside the surface. Do not draw a deep floating block, dirt slab, pedestal, cliff, floating island or large shadow. The rim height is low, just like a garden bed on flat ground.
Style: premium crisp detailed pixel art, clearly grouped pixels, warm light from upper left, soft natural woodland soil and honey-brown aged wood. Match the supplied scene's existing wood and grass tones precisely, not smooth 3D and not cartoon casual-game art.
Every pixel outside the two separate sprites MUST be perfectly uniform pure magenta #FF00FF. No gradient, no checkerboard, no white, no backdrop, no scenery, no labels, no grid lines, no UI. Keep generous magenta padding around each sprite. The left cell center is x=384 and right cell center is x=1152 on the 1536-wide canvas. Do not overlap or crop either sprite.
```
