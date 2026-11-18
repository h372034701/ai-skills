# 已验证的 HybridCLR 恢复案例

来源：Codex 聊天“梳理 Spine 换装实现 (4)”（`01a1e425-c2e0-71a3-81b4-9a6d5b20dcab`）中“继续恢复完整 c# 方法体 然后更新文档”这一轮的最终结果，以及该轮落地的 `HybridCLR DLL恢复记录.md`、提取/解密脚本和反编译出的 `Launch.HCC`。以下记录案例事实，不要求其他项目具有相同版本、名字、密钥或数量。

## 为什么从原生扫描转到热更缓存

输入是 Android ARM64 `libil2cpp.so`，Unity `2022.3.57f1`，metadata 解析器报告 `31.1`（metadata 头部版本与解析器的细分版本不要混用）。metadata 可解析出 51,316 types、307,502 methods、144 images，但 Cpp2IL 无法定位 code registration。

disunity 曾报告候选 CodeRegistration VA `0x1C821B00` 及 1,466 个方法映射。继续核查后发现该 VA 落在 ELF `.hash`，所谓计数 `1471` 与 `0xD0` 是哈希表数据。异常 `codeGenModules = 0x68f00000687` 和类型计数 `1194000908288` 也是无效候选的表现，不能仅据此断定“特殊相对指针加密”或整个游戏没有可恢复方法体。

metadata 的类型/字段/方法名仍可作为独立证据；无效 native 映射不能用来证明调用关系或完整方法体。需要原生恢复时继续校验 ELF 映射与真正的初始化/注册调用，而不是给 `.hash` 误报补一套指针解码规则。

## 真实字节的提取

运行时目录存在 `files/yoo/HybridCLR/CacheFiles/.../__data` 和版本 manifest。载荷是 Unity SerializedFile / bundle 中的 TextAsset，不能因缺乏 `.dll` 扩展名而漏掉。

UnityPy `1.25.4` 下的正确路径是 `ObjectReader.get_raw_data()`：

```text
uint32 little-endian nameLength
nameLength bytes of name
padding to 4-byte boundary
uint32 little-endian scriptLength
scriptLength raw bytes
```

`m_Script` 是文本表示，转成 UTF-8 写回会改变 DLL 字节。先前损坏的提取需要从原始缓存重做，不能把解密失败直接归因于密钥。对 name、对齐位置、script 范围都做边界检查，记录每个对象的 SHA-256；不同 bundle 中的重名对象必须分别保留。

## 从启动器取得解密依据

`Launch.dll`（386,560 bytes）和 `Framework.FirstPass.Runtime.dll`（408,576 bytes）本身是 managed PE，可先直接反编译。其余八个 DLL 的原始前 16 字节相同：

```text
21 D8 87 B0 BD 21 D0 02 BA AF 3F 41 AA 49 3D 68
```

这只是该版本载荷的特征，不是通用魔数。真实 `Launch.HCC` 的逻辑为：

1. 16 个常量分别减 `7` 得到 AES key；按 byte 语义计算。
2. 将 key 按字节逆序得到 IV。
3. `Aes.Create()` 后调用 `CreateDecryptor(key, iv)`，再对整段输入执行 `TransformFinalBlock`；该实现使用 CBC 和 PKCS7。

复现本案例时，在检查到**同一份加载器逻辑**后可这样生成工具参数。其他项目必须自己恢复参数；不要使用猜测的常量：

```powershell
[byte[]]$keyBytes = 40,49,83,108,112,123,112,117,110,44,84,63,63,42,133,40
for ($i = 0; $i -lt $keyBytes.Length; $i++) {
    $keyBytes[$i] = [byte](($keyBytes[$i] - 7) -band 0xff)
}
[byte[]]$ivBytes = $keyBytes[($keyBytes.Length - 1)..0]
@{
    key_hex = [Convert]::ToHexString($keyBytes)
    iv_hex = [Convert]::ToHexString($ivBytes)
} | ConvertTo-Json | Set-Content -LiteralPath '<task-local>/aes-parameters.json' -Encoding utf8
```

## 最终验证到的输出

| 程序集 | 原始 script bytes | 解密 PE bytes |
| --- | ---: | ---: |
| Assembly-CSharp.dll | 16,787,984 | 16,787,968 |
| Console.dll | 16,738,832 | 16,738,816 |
| Framework.dll | 97,808 | 97,792 |
| GameFramework.Runtime.dll | 80,400 | 80,384 |
| CustomWater.dll | 23,056 | 23,040 |
| GFrameCore.Extensions.Cloneable.dll | 38,928 | 38,912 |
| LoopScrollRect.Runtime.dll | 50,704 | 50,688 |
| Luban.dll | 21,520 | 21,504 |

该样本八个输出长度均减少 16 字节，是本次 PKCS7 padding 的结果；其他输入可能减少 1–16 字节，不能把固定差值当作通用校验。

ILSpy 11.1 从真实热更程序集生成了可读方法体，代表性检查包括 `ChatPanel.OnSendBtnClickImpl`、`ChatOperUtils.SendChatMsg` / `TranslateInputStr`、`ChatPrivateChannelPanel.TrySyncPrivateMsg`。异步逻辑可能位于生成的状态机 `MoveNext`，不能只看入口 wrapper 就判为空。

该轮整理了八个聊天核心类，确认其包含真实方法体。部分 `Unknown result type` 来自尚未齐全的 Unity/项目引用；当时并未在匹配 Unity 项目中验证整套源码编译。不要将这些案例结果升级为“所有类都完整反编译”或“可以直接脱离 Unity 编译”。

## 排查次序

| 症状 | 下一项证据 |
| --- | --- |
| 原始 DLL 开头不是 MZ | 先确认是不是容器，再验证 TextAsset 提取长度与字节保真，最后追加载器保护逻辑 |
| AES padding 错误 | 核对缓存版本、key/IV 来源、变换顺序、header 偏移与是否截断；不自动换模式或暴力枚举 |
| 解密后仅有 MZ | 静态解析 PE、CLR metadata、方法体，不能以两个字节作完整验证 |
| 只有类型和签名 | 检查 DummyDll/补充 AOT metadata 程序集，并找真正由加载器加载的热更 DLL |
| ILSpy 方法入口很短 | 追状态机 MoveNext、调用方及引用依赖，区分合法 wrapper 和占位 |
| 工具返回了大量 native 地址 | 检查 section、计数、指针映射与代表性指令后才使用 |
