# Release Checklist（M5）

- [ ] 第一次 DevEco 工具链构建通过：`hvigorw assembleHap`
- [ ] 修复全部 ArkTS 编译错误，无 `any`、无资源硬编码
- [ ] T1.8 解析回归 9/9 通过
- [ ] A1–A10 真机验收记录完成（若可用设备）
- [ ] 深色模式/中英文切换全页面检查
- [ ] 权限说明：INTERNET、KEEP_BACKGROUND_RUNNING 用途文案
- [x] 图标、名称（已改：**HomenaPod** / `com.homenapod.app`）
- [ ] release 签名配置与 HAP 产物
- [x] 开源许可：GPL-3.0 声明保留，来源标注 AntennaPod（见 `antennapod-harmony/NOTICE.md`；发布前补 `LICENSE` 全文）
