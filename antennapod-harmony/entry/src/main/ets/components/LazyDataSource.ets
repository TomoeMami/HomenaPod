// ArkUI LazyForEach 通用数据源
export class LazyDataSource<T> implements IDataSource {
  private data: T[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.data.length;
  }

  getData(index: number): T {
    return this.data[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener);
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const idx: number = this.listeners.indexOf(listener);
    if (idx >= 0) {
      this.listeners.splice(idx, 1);
    }
  }

  setData(data: T[]): void {
    this.data = data;
    for (const listener of this.listeners) {
      listener.onDataReloaded();
    }
  }

  /**
   * 静默换数据：只把底层数组换成新的一份，**不通知**列表重建。
   * 用于「顺序（键值）完全没变、只是对象重新从库里读了一遍」的场景：
   * `onDataReloaded` 会让列表重建并把滚动位置拉回顶部，而这里保留已渲染的行。
   * 同时保证 `getDataArray()` 与调用方随后持有的数组是**同一个对象**——
   * 拖拽排序（`move` 就地改数组）和「顺序落库」都依赖这个约定。
   */
  replaceData(data: T[]): void {
    this.data = data;
  }

  /** 增量追加（分页加载下一页）：逐条通知，避免 onDataReloaded 让列表回到顶部 */
  appendData(items: T[]): void {
    if (items.length === 0) {
      return;
    }
    const start: number = this.data.length;
    for (const item of items) {
      this.data.push(item);
    }
    for (const listener of this.listeners) {
      for (let i: number = 0; i < items.length; i++) {
        listener.onDataAdd(start + i);
      }
    }
  }

  /** 单条变化（下载进度 / 播放状态 / 已播标记）：只重绘该行，不重建整个列表 */
  notifyDataChange(index: number): void {
    if (index < 0 || index >= this.data.length) {
      return;
    }
    for (const listener of this.listeners) {
      listener.onDataChange(index);
    }
  }

  /** 增量删除（列表内标记已播后移除一行）：保持滚动位置不变 */
  removeAt(index: number): void {
    if (index < 0 || index >= this.data.length) {
      return;
    }
    this.data.splice(index, 1);
    for (const listener of this.listeners) {
      listener.onDataDelete(index);
    }
  }

  /** 增量移动（拖拽排序）：通知 onDataMove，List 会播放位移动画 */
  move(from: number, to: number): void {
    if (from === to || from < 0 || to < 0 || from >= this.data.length || to >= this.data.length) {
      return;
    }
    const moved: T = this.data[from];
    this.data.splice(from, 1);
    this.data.splice(to, 0, moved);
    for (const listener of this.listeners) {
      listener.onDataMove(from, to);
    }
  }

  getDataArray(): T[] {
    return this.data;
  }
}
