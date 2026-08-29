# Children-Concentration-Training-Game

## 实验组别

登录和创建用户时必须从四个固定组别中单选一个：

- 空白对照组（`blank_control`）
- 脑电组（`eeg`）
- 手势组（`gesture`）
- 脑电+手势组（`gesture_eeg`）

组别以单个 `experimental_group_code` 字段保存在用户存档中。已有用户再次登录时会回显原组别，也可以选择其他组别后登录以修改。

## 脑电采集器事件对齐

游戏通过 `127.0.0.1:8765` 向脑电采集器发送 JSON UDP 事件。登录成功后开始持续发送键盘按下/松开事件，登录页输入用户名和密码期间不会记录：

- `KEYBOARD_RECORDING_START`：登录成功，开始记录键盘事件
- `BLOCK_START` / `BLOCK_END`：关卡采集边界
- `PLAYER_INPUT`：键盘事件，包含 `KEY_DOWN` / `KEY_UP`、键名、逻辑键码、物理键码、Unicode 和重复按键标记
- `ENERGY_BOOST_START` / `ENERGY_BOOST_END`：跑酷充能增益边界

采集器收到 UDP 后使用与脑电流相同的本机接收时钟和首个 Cortex 样本零点写入 `events.tsv`，因此分析时应以采集器生成的 `onset`、`host_time_utc` 和 `host_monotonic` 为准。游戏自带的时间字段只用于复核。

请在 v2.1 采集器中关闭“记录全局键盘”，保留 UDP 游戏事件。该已打包版本的全局键盘选项会覆盖整段正式采集；游戏侧的 `PLAYER_INPUT` 从登录成功后开始记录。

## 分组游戏规则

- 含脑电组：跑酷充能由专注度阈值控制，允许专注度触发的黄色爱心保护；建造平台需要随专注度逐步变为实体。
- 不含脑电组：关闭专注度触发的黄色爱心保护；跑酷充能条以 `0.5x` 固定速度缓慢充能，充满后仍触发与实验组相同的限时无敌和飞行；建造平台确认后立即成为实体。
- 跑酷的每次充能增益都会写入 UDP 事件，便于实验后比较各组触发次数并继续校准 `non_eeg_charge_rate`。

