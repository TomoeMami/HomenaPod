# 签名与发布指南（T5.5）

## 1. 开发真机调试

DevEco Studio 菜单：`File > Project Structure > Signing Configs`，勾选 `Automatically generate signature`，填入华为账号后 IDE 会自动生成 debug 签名并在 `build-profile.json5` 写入 `signingConfigs`。

## 2. Release 签名

在 `build-profile.json5` 的 `app.signingConfigs` 中配置 release 证书与 Profile：

```json5
{
  "app": {
    "signingConfigs": [
      {
        "name": "release",
        "type": "HarmonyOS",
        "material": {
          "certpath": "./sign/homenapod-release.cer",
          "storePassword": "****",
          "keyAlias": "homenapod",
          "keyPassword": "****",
          "profile": "./sign/homenapod-release.p7b",
          "signAlg": "SHA256withECDSA",
          "storeFile": "./sign/homenapod-release.p12"
        }
      }
    ],
    "products": [
      {
        "name": "default",
        "signingConfig": "release",
        "compatibleSdkVersion": "5.0.2(14)",
        "runtimeOS": "HarmonyOS"
      }
    ]
  }
}
```

## 3. 构建命令

```bash
hvigorw clean --no-daemon
hvigorw assembleHap --mode module -p product=default -p buildMode=release --no-daemon
```

产物：`entry/build/default/outputs/default/entry-default-signed.hap`

## 4. 上架前检查

- [x] bundleName 已定：`com.homenapod.app`（2026-09-10 随产品改名 HomenaPod 调整；如改用自有域名反写，需同步 `AppScope/app.json5` 与签名 Profile——改名后旧 Profile 不再匹配，需重新生成）
- [ ] versionCode/versionName 正确
- [ ] `ohos.permission.INTERNET`、`ohos.permission.KEEP_BACKGROUND_RUNNING` 用途说明
- [ ] 隐私政策、用户协议
- [ ] 图标 1024×1024、截图
- [x] 开源许可：GPL-3.0 与 AntennaPod 来源声明（见 `antennapod-harmony/NOTICE.md`）
