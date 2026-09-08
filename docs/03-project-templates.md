# 03 · DevEco 工程骨架模板（照抄即可）

> 用途：T0.3 创建 `antennapod-harmony/` 时逐文件照抄。模板基于 DevEco Studio 5.x（HarmonyOS 5.0，API 12）默认工程格式。
>
> 注意事项：
> 1. 先建**资源文件**，再建引用资源的配置；顺序已按依赖排列。
> 2. `bundleName` 使用 `de.danoeh.antennapod` 仅作占位，上架前按实际账号改成自有域名反写（如 `org.antennapod.harmony`）。
> 3. 真机安装需要签名：DevEco Studio 中 File → Project Structure → Signing Configs 勾选自动签名；或由用户提供证书/Profile 后回填根 `build-profile.json5` 的 `signingConfigs`。
> 4. 命令行构建前置：安装 DevEco Command Line Tools（hvigorw/ohpm），并设置 `DEVECO_SDK_HOME` 指向 SDK 目录。

## 文件清单与顺序

```
antennapod-harmony/
├── .gitignore
├── build-profile.json5                 # 1
├── hvigorfile.ts                       # 2
├── hvigor/hvigor-config.json5          # 3
├── oh-package.json5                    # 4
├── AppScope/
│   ├── app.json5                       # 5
│   └── resources/base/
│       ├── element/string.json         # 6
│       └── media/app_icon.svg          # 7
└── entry/
    ├── build-profile.json5             # 8
    ├── hvigorfile.ts                   # 9
    ├── oh-package.json5                # 10
    ├── obfuscation-rules.txt           # 11（空文件）
    └── src/main/
        ├── module.json5                # 12
        ├── ets/
        │   ├── entryability/EntryAbility.ets   # 13
        │   └── pages/Index.ets                 # 14
        └── resources/
            ├── base/
            │   ├── element/
            │   │   ├── string.json     # 15
            │   │   └── color.json      # 16
            │   ├── media/app_icon.svg  # 17
            │   └── profile/main_pages.json      # 18
            ├── en_US/element/string.json        # 19
            └── zh_CN/element/string.json        # 20
```

---

## 1 · 根 `build-profile.json5`

```json5
{
  "app": {
    "signingConfigs": [],
    "products": [
      {
        "name": "default",
        "signingConfig": "default",
        "compatibleSdkVersion": "5.0.0(12)",
        "runtimeOS": "HarmonyOS",
        "buildOption": {
          "strictMode": {
            "caseSensitiveCheck": true,
            "useNormalizedOHMUrl": true
          }
        }
      }
    ],
    "buildModeSet": [
      {
        "name": "debug"
      },
      {
        "name": "release"
      }
    ]
  },
  "modules": [
    {
      "name": "entry",
      "srcPath": "./entry",
      "targets": [
        {
          "name": "default",
          "applyToProducts": [
            "default"
          ]
        }
      ]
    }
  ]
}
```

## 2 · 根 `hvigorfile.ts`

```ts
import { appTasks } from '@ohos/hvigor-ohos-plugin';

export default {
  system: appTasks,
  plugins: []
}
```

## 3 · `hvigor/hvigor-config.json5`

```json5
{
  "modelVersion": "5.0.0",
  "dependencies": {}
}
```

## 4 · 根 `oh-package.json5`

```json5
{
  "modelVersion": "5.0.0",
  "description": "AntennaPod for HarmonyOS NEXT",
  "dependencies": {},
  "devDependencies": {}
}
```

## 5 · `AppScope/app.json5`

```json5
{
  "app": {
    "bundleName": "de.danoeh.antennapod",
    "vendor": "antennapod",
    "versionCode": 1000000,
    "versionName": "1.0.0",
    "icon": "$media:app_icon",
    "label": "$string:app_name"
  }
}
```

## 6 · `AppScope/resources/base/element/string.json`

```json
{
  "string": [
    {
      "name": "app_name",
      "value": "AntennaPod"
    }
  ]
}
```

## 7 · `AppScope/resources/base/media/app_icon.svg`

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" rx="224" fill="#2962FF"/>
  <circle cx="512" cy="512" r="132" fill="#FFFFFF"/>
  <path d="M280 340 L744 684 M744 340 L280 684" stroke="#FFFFFF" stroke-width="56" stroke-linecap="round"/>
</svg>
```

## 8 · `entry/build-profile.json5`

```json5
{
  "apiType": "stageMode",
  "buildOption": {},
  "buildOptionSet": [
    {
      "name": "release",
      "arkOptions": {
        "obfuscation": {
          "ruleOptions": {
            "enable": false,
            "files": [
              "./obfuscation-rules.txt"
            ]
          }
        }
      }
    }
  ],
  "targets": [
    {
      "name": "default"
    },
    {
      "name": "ohosTest"
    }
  ]
}
```

## 9 · `entry/hvigorfile.ts`

```ts
import { hapTasks } from '@ohos/hvigor-ohos-plugin';

export default {
  system: hapTasks,
  plugins: []
}
```

## 10 · `entry/oh-package.json5`

```json5
{
  "name": "entry",
  "version": "1.0.0",
  "description": "AntennaPod HarmonyOS NEXT entry module",
  "main": "",
  "author": "",
  "license": "GPL-3.0-only",
  "dependencies": {},
  "devDependencies": {}
}
```

## 11 · `entry/obfuscation-rules.txt`

空文件（0 字节）。

## 12 · `entry/src/main/module.json5`

```json5
{
  "module": {
    "name": "entry",
    "type": "entry",
    "description": "$string:module_desc",
    "mainElement": "EntryAbility",
    "deviceTypes": [
      "phone",
      "tablet"
    ],
    "deliveryWithInstall": true,
    "installationFree": false,
    "pages": "$profile:main_pages",
    "abilities": [
      {
        "name": "EntryAbility",
        "srcEntry": "./ets/entryability/EntryAbility.ets",
        "description": "$string:EntryAbility_desc",
        "icon": "$media:app_icon",
        "label": "$string:EntryAbility_label",
        "startWindowIcon": "$media:app_icon",
        "startWindowBackground": "$color:start_window_background",
        "exported": true,
        "backgroundModes": [
          "audioPlayback"
        ],
        "skills": [
          {
            "entities": [
              "entity.system.home"
            ],
            "actions": [
              "action.system.home"
            ]
          }
        ]
      }
    ],
    "requestPermissions": [
      {
        "name": "ohos.permission.INTERNET"
      },
      {
        "name": "ohos.permission.GET_NETWORK_INFO"
      },
      {
        "name": "ohos.permission.KEEP_BACKGROUND_RUNNING"
      }
    ]
  }
}
```

## 13 · `entry/src/main/ets/entryability/EntryAbility.ets`

```ts
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'APod/EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, 'EntryAbility onCreate');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, TAG, 'loadContent failed, code=%{public}d', err.code);
        return;
      }
      hilog.info(0x0000, TAG, 'loadContent succeeded');
    });
  }
}
```

## 14 · `entry/src/main/ets/pages/Index.ets`

```ts
@Entry
@Component
struct Index {
  build() {
    Column({ space: 8 }) {
      Text($r('app.string.app_name'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
      Text($r('app.string.skeleton_hint'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
```

## 15 · `entry/src/main/resources/base/element/string.json`

```json
{
  "string": [
    {
      "name": "module_desc",
      "value": "AntennaPod entry module"
    },
    {
      "name": "EntryAbility_desc",
      "value": "AntennaPod main ability"
    },
    {
      "name": "EntryAbility_label",
      "value": "AntennaPod"
    },
    {
      "name": "skeleton_hint",
      "value": "Porting in progress"
    }
  ]
}
```

## 16 · `entry/src/main/resources/base/element/color.json`

```json
{
  "color": [
    {
      "name": "start_window_background",
      "value": "#FFFFFF"
    },
    {
      "name": "text_secondary",
      "value": "#66000000"
    }
  ]
}
```

## 17 · `entry/src/main/resources/base/media/app_icon.svg`

与第 7 份文件相同（复制）。

## 18 · `entry/src/main/resources/base/profile/main_pages.json`

```json
{
  "src": [
    "pages/Index"
  ]
}
```

## 19 · `entry/src/main/resources/en_US/element/string.json`

```json
{
  "string": [
    {
      "name": "module_desc",
      "value": "AntennaPod entry module"
    },
    {
      "name": "EntryAbility_desc",
      "value": "AntennaPod main ability"
    },
    {
      "name": "EntryAbility_label",
      "value": "AntennaPod"
    },
    {
      "name": "skeleton_hint",
      "value": "Porting in progress"
    }
  ]
}
```

## 20 · `entry/src/main/resources/zh_CN/element/string.json`

```json
{
  "string": [
    {
      "name": "module_desc",
      "value": "AntennaPod 入口模块"
    },
    {
      "name": "EntryAbility_desc",
      "value": "AntennaPod 主程序"
    },
    {
      "name": "EntryAbility_label",
      "value": "AntennaPod"
    },
    {
      "name": "skeleton_hint",
      "value": "移植进行中"
    }
  ]
}
```

## 附 · `.gitignore`

```
/node_modules
/oh_modules
/local.properties
/.idea
**/build
/.hvigor
**/.test
/.appanalyzer
```

## 附 · 骨架建好后目录自查命令

```bash
cd antennapod-harmony
find . -type f | sort
# 期望：上述 20 个文件 + obfuscation-rules.txt + .gitignore 全部出现
```

## 附 · 工具链可用时的构建命令

```bash
cd antennapod-harmony
export DEVECO_SDK_HOME=/path/to/command-line-tools/sdk   # 按实际
hvigorw clean --no-daemon
hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
# 产物：entry/build/default/outputs/default/entry-default-unsigned.hap
```
