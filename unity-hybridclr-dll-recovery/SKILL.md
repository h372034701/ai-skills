---
name: unity-hybridclr-dll-recovery
description: Recover real managed DLLs and readable C# method bodies from Unity HybridCLR hot-update bundles or YooAsset caches, including binary TextAsset extraction and loader-derived decryption. Use when IL2CPP tools yield only metadata, DummyDlls, or invalid registration candidates but hot-update assemblies may still contain original IL. Not for Spine asset extraction or native-only IL2CPP reconstruction.
---

# Unity HybridCLR DLL Recovery

把“恢复 IL”先分成两条路径：HybridCLR 热更程序集可能仍保存真实 IL，可以提取、按加载器逻辑解密、直接反编译；原生 IL2CPP 方法则需要从机器码近似重建。不要在发现热更缓存后仍只重复扫描原生注册表。

使用 PowerShell 7 (`pwsh`)。保留 APK、运行时缓存、原生库及 metadata 原件；中间产物写到独立目录。分析程序集时使用静态读取和反编译，不加载执行游戏程序集。

## 1. 确认输入与恢复路线

- 同时检查安装包和运行时数据目录；后者可能含比 APK 更新的程序集。寻找 `HybridCLR`、`HotUpdate`、`yoo`、`CacheFiles`、`ManifestFiles`、`__data`、`.dll.bytes` 和启动程序集。
- 用 manifest、缓存标识、程序集版本或哈希区分版本。不要把不同版本或 CPU 架构的缓存混成一套依赖。
- AssetRipper 导出的 prefab 和 Dummy C# 不等于原生库或真实 DLL。需要原生分析时另找 `libil2cpp.so` / `GameAssembly.dll` 与匹配的 `global-metadata.dat`。
- 先分类：可静态解析的 managed PE、Unity bundle/SerializedFile、待识别的受保护载荷。文件名 `.dll` 和头部 `MZ` 都不能单独证明其含真实方法体。

确认只有 native IL2CPP 输入时，改走 Cpp2IL / 原生分析路线；本 skill 不承诺恢复不存在于缓存中的原始 IL。不要为了验证本 skill 去另行提取 Spine 资源。

## 2. 无损提取 TextAsset

原项目成功链路及注册表误报见 [references/recovery-case.md](references/recovery-case.md)。需要理解二进制布局、处理非标准序列化时再读该参考。

依赖是 Python 3 和 UnityPy；先检查已有环境，缺失时可在任务虚拟环境中安装 `UnityPy`。记录实际使用的版本；原案例使用了 `1.25.4`，无需把它当成所有项目的固定版本。

```powershell
python '<skill-dir>/scripts/extract_hybridclr_textassets.py' `
  --source '<runtime-cache-or-bundle>' --output '<new-raw-directory>'
```

该工具支持单文件、目录内的 YooAsset `__data`、`.bundle`、`.unity3d`、`.ab` 文件，保留提取清单和错误。其他命名形式可先定位容器，再按单文件传入。检查 `index.json`，解释所有错误后再声称提取完整。

**必须从 TextAsset 的序列化原始字节中取 script bytes。** 不要把 `m_Script` 解码为字符串再以 UTF-8 编码写回 DLL；这会破坏非文本字节。工具适用的布局是小端 name 长度、name、4 字节对齐、script 长度、script。布局不同应调整读取器，不能截断后继续当作成功。

## 3. 从真实加载器恢复保护逻辑

先反编译已经可读的启动 DLL（例如 `Launch.dll`），沿程序集加载调用回溯 payload 变换。寻找 `Assembly.Load`、HybridCLR 加载调用、`CreateDecryptor`、`TransformFinalBlock` 及其参数来源。

- 只根据该项目可见的方法体确定算法、key、IV、padding、解压顺序及 header 偏移。失败时回查原始字节和加载链，不进行无依据的算法轮试。
- 原案例 `Launch.HCC` 使用 AES-CBC / PKCS7，key 由常量逐项减 7 得到，IV 是 key 的逆序。这是该案例的结论，不能当作 HybridCLR 通用加密协议。
- `.mv` 等旁路文件不自动视为 DLL；保留它们并检查加载器用途。

若证据确认整段载荷是 AES-CBC / PKCS7，可创建任务本地 JSON 参数文件（`key_hex` 为 16/24/32 字节的十六进制，`iv_hex` 为 16 字节），运行：

```powershell
pwsh -NoProfile -File '<skill-dir>/scripts/Restore-HybridClrDlls.ps1' `
  -InputDirectory '<raw-directory>' -OutputDirectory '<new-managed-directory>' `
  -ParametersPath '<local-aes-parameters.json>'
```

该工具接受 `.dll` / `.dll.bytes`，将已是 managed PE 的文件直接复制，其他候选按上述算法解密；静态验证 PE/CLR metadata 和方法体后才写出 DLL。输出按程序集内部身份命名为 `<AssemblyName>.dll`，便于 ILSpy 查找依赖；同名身份会报错，先按 manifest 选好一套缓存版本再恢复。每个文件单独建立解密器，保留原字节与 SHA-256。`recovery-index.json` 含失败信息，任何候选失败时进程报错。其他保护方式应根据加载器另行实现，不强行套此工具。

## 4. 反编译并验证真实方法体

用现有 ILSpy / `ilspycmd`，按本机 `--help` 确认选项。先反编译启动器定位解密逻辑，再反编译业务程序集；在目标程序集旁提供同版本依赖，或通过 `-r` 指向依赖目录：

```powershell
ilspycmd -p -r '<matching-managed-directory>' `
  -o '<new-csharp-directory>' '<managed-directory>/Assembly-CSharp.dll'
if ($LASTEXITCODE -ne 0) { throw 'ILSpy decompilation failed; inspect diagnostics.' }
```

分层检查，不把“工具成功退出”写成“完整源码恢复”：

1. 提取前后记录 source/cache、对象标识、长度、SHA-256；解密时另记输入与输出哈希。
2. 检查 PE signature、CLR metadata、程序集身份和方法体 RVA / IL。脚本中的 `NoBody` 可包括合法抽象和外部方法；`LdnullThrow` 是可疑占位统计，必须结合来源判断，既不能忽略也不能要求所有真实程序集绝对为零。
3. 查看用户关心的代表性方法及其调用方、分支和异步状态机 `MoveNext`。批量 `ldnull; throw`、`NotImplementedException` 或仅有签名需要核实，不能直接当作原始业务逻辑。
4. ILSpy 的 `Unknown result type` 可能来自缺失依赖；补齐引用后重试，并确认是否仍有反编译失败。单有这些注释不能证明方法体不存在，也不能证明控制流完整。

原生注册表定位失败时，先校验候选 VA 所在 ELF section / segment、VA 到文件偏移映射、重定位、计数和指针表。落在 `.hash` 的候选或明显不可能的指针不能作为成功映射。metadata 中的类名和方法签名依然可以单独使用。

## 交付与边界

报告输入版本、工具版本、提取/复制/解密/失败数量、产物位置、哈希清单、关键方法证据和未解决限制。明确方法体来自真实热更 IL、metadata 签名还是原生重建。区分“可阅读的反编译 C#”与“已在匹配 Unity 工程中编译通过”。

保留原始、解密、反编译三层目录；更新旧文档中的过时判断，尤其是“完全无法恢复方法体”和无效 native 地址。发布 skill 时只纳入通用工具与流程，不将游戏 DLL、缓存、整份反编译源码或本地参数文件夹带进仓库。
