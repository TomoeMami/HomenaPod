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

  getDataArray(): T[] {
    return this.data;
  }
}
