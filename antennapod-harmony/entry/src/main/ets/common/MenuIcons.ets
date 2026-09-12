import { SymbolGlyphModifier } from '@ohos.arkui.modifier';

/**
 * 菜单项前置图标。
 * `MenuItemOptions.startIcon` 只接受图片资源（不支持 `sys.symbol`），符号图标必须走
 * `symbolStartIcon`（API 12 起），其类型为 `SymbolGlyphModifier`。
 */
export function menuIcon(src: Resource): SymbolGlyphModifier {
  const modifier: SymbolGlyphModifier = new SymbolGlyphModifier(src);
  modifier.fontSize(20);
  modifier.fontColor([$r('app.color.text_secondary')]);
  return modifier;
}
