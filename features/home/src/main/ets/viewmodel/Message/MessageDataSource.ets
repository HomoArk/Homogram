import { SortedHashMap } from '@ohos/base';
import { Message } from '../../entities/Message';
import { IDataSourcePrefetching } from '@kit.ArkUI';

const nullMessage = new Message(0, 0, false, false, 0, '', 0, '', 0);

export class MessageDataSource implements IDataSourcePrefetching {
  public sortedMessages: SortedHashMap<number, Message> = new SortedHashMap<number, Message>();
  private listeners: DataChangeListener[] = [];

  public replaceSnapshot(messages: Message[]): void {
    this.sortedMessages.clear();
    for (let i = 0; i < messages.length; i++) {
      this.sortedMessages.set(messages[i].messageId, messages[i]);
    }
    this.notifyDataReload();
  }

  prefetch(index: number): void | Promise<void> {
  }

  cancel?(index: number): void | Promise<void> {
  }

  public totalCount(): number {
    return this.sortedMessages.length();
  }

  // to satisfy the interface
  public getData(index: number): Message {
    return this.get(index);
  }

  // ArkUI presents oldest-to-newest, while the backing store mirrors Telegram Android newest-first ordering.
  public get(index: number): Message {
    return this.sortedMessages.getValueAt(this.toBackingIndex(index)) || nullMessage;
  }

  public oldestMessage(): Message | undefined {
    const length = this.sortedMessages.length();
    if (length <= 0) {
      return undefined;
    }
    return this.sortedMessages.getValueAt(length - 1);
  }

  public newestMessage(): Message | undefined {
    return this.sortedMessages.getValueAt(0);
  }

  public getMessageById(messageId: number): Message | undefined {
    return this.sortedMessages.get(messageId);
  }

  public getAll(): Message[] {
    const values = this.sortedMessages.getSortedValues();
    const result: Message[] = [];
    for (let i = values.length - 1; i >= 0; i--) {
      result.push(values[i]);
    }
    return result;
  }

  public indexOf(messageId: number): number {
    return this.toVisualIndex(this.sortedMessages.indexOf(messageId), this.sortedMessages.length());
  }

  public upsertMany(data: Message[]): void {
    if (data.length === 0) {
      return;
    }
    for (let i = 0; i < data.length; i++) {
      this.upsert(data[i]);
    }
  }

  public upsert(data: Message): void {
    const oldLength = this.sortedMessages.length();
    const update = this.sortedMessages.set(data.messageId, data);
    const newLength = this.sortedMessages.length();
    const index = this.toVisualIndex(update.index, newLength);
    if (update.previousIndex >= 0 && update.previousIndex !== update.index) {
      const previousIndex = this.toVisualIndex(update.previousIndex, oldLength);
      this.notifyDataMove(previousIndex, index);
      this.notifyDataChange(index);
    } else if (update.previousIndex >= 0) {
      this.notifyDataChange(index);
    } else {
      this.notifyDataAdd(index);
    }
  }

  public delete(index: number): void {
    const backingIndex = this.toBackingIndex(index);
    let value = this.sortedMessages.getValueAt(backingIndex);
    if (value) {
      this.sortedMessages.delete(value.messageId);
      this.notifyDataDelete(index);
    }

  }

  public deleteById(messageId: number): void {
    const backingIndex = this.sortedMessages.indexOf(messageId);
    if (backingIndex >= 0) {
      const index = this.toVisualIndex(backingIndex, this.sortedMessages.length());
      this.sortedMessages.delete(messageId);
      this.notifyDataDelete(index);
    }
  }

  //
  // public move(from: number, to: number): void {
  //   // TODO: optimize
  //   let temp: Message = this.sortedMessages[from];
  //   this.sortedMessages[from] = this.sortedMessages[to];
  //   this.sortedMessages[to] = temp;
  //   this.notifyDataMove(from, to);
  // }

  public reload(): void {
    this.notifyDataReload();
  }

  public modify(index: number, data: Message): void {
    let id = this.get(index)?.messageId;
    if (id) {
      this.upsert(data);
    }
  }

  private toBackingIndex(visualIndex: number): number {
    return this.sortedMessages.length() - 1 - visualIndex;
  }

  private toVisualIndex(backingIndex: number, length: number): number {
    if (backingIndex < 0) {
      return -1;
    }
    return length - 1 - backingIndex;
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      console.info('add listener');
      this.listeners.push(listener);
    }
  }

  // 通知LazyForEach组件需要重载所有子组件
  notifyDataReload(): void {
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    })
  }

  // 通知LazyForEach组件需要在index对应索引处添加子组件
  notifyDataAdd(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataAdd(index);
    })
  }

  // 通知LazyForEach组件在index对应索引处数据有变化，需要重建该子组件
  notifyDataChange(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataChange(index);
    })
  }

  // 通知LazyForEach组件需要在index对应索引处删除该子组件
  notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataDelete(index);
    })
  }

  // 通知LazyForEach组件将from索引和to索引处的子组件进行交换
  notifyDataMove(from: number, to: number): void {
    this.listeners.forEach(listener => {
      listener.onDataMove(from, to);
    })
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      console.info('remove listener');
      this.listeners.splice(pos, 1);
    }
  }
}
