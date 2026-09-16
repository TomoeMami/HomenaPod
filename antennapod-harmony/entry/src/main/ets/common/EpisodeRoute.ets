import router from '@ohos.router';

/**
 * 单集行的统一单击入口：打开单集详情页
 * （对照上游 `EpisodeItemListAdapter` 单击 → `ItemPagerFragment`）。
 *
 * 所有带单集行的页面（收件箱 / 订阅详情 / 单集总表 / 收藏 / 历史 / 队列 / 搜索 / 首页 / 下载）
 * 都走这里，保证「单击 = 看详情」在各处一致；行内 48vp 次级操作钮（播放 / 下载 / 收藏）
 * 仍由各行自己的 `EpisodeRow.onAction` 处理，不受这里影响。
 */
export function openEpisodeDetail(itemId: number): void {
  if (itemId <= 0) {
    return;
  }
  router.pushUrl({ url: 'pages/EpisodeDetailPage', params: { itemId: itemId } });
}
