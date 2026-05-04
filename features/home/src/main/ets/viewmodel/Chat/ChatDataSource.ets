import { HashMap } from '@kit.ArkTS';
import { Logger } from '@ohos/base';
import { SortedHashMap } from '@ohos/base';
import { Chat } from '../../entities/Chat';

export class ChatDataSource implements IDataSource {
  private pinnedChatsMap: HashMap<string, Chat> = new HashMap<string, Chat>();
  private pinnedChatsArray: Chat[] =
    []; // instead using pinnedChatsMap.values() to iterate, we use this array to make it faster
  private sortedUnpinnedChatsMap: SortedHashMap<string, Chat> = new SortedHashMap<string, Chat>();
  // private readonly fetchInProgress: HashSet<number> = new HashSet<number>();
  private listeners: DataChangeListener[] = [];

  constructor() {
  }

  totalCount(): number {
    return this.sortedUnpinnedChatsMap.length() + this.pinnedChatsMap.length;
  }

  getData(index: number): Chat | undefined {
    if (index < this.pinnedChatsMap.length) {
      return this.pinnedChatsArray[index];
    }
    return this.sortedUnpinnedChatsMap.getValueAt(index - this.pinnedChatsMap.length);
  }

  get(chatId: string): Chat | undefined {
    // always check pinned chats first
    if (this.pinnedChatsMap.hasKey(chatId)) {
      return this.pinnedChatsMap.get(chatId);
    }
    return this.sortedUnpinnedChatsMap.get(chatId);
  }

  // ArkTS doesn't support generator so we cannot merge the iterators into one

  pinnedChats(): IterableIterator<Chat> {
    return this.pinnedChatsMap.values();
  }

  unsortedUnpinnedChats(): IterableIterator<Chat> {
    return this.sortedUnpinnedChatsMap.valuesIterator();
  }

  sortedUnpinnedChats(): IterableIterator<Chat> {
    return this.sortedUnpinnedChatsMap.sortedValuesIterator();
  }

  getPinnedChatsArray(): Chat[] {
    return [...this.pinnedChatsArray];
  }

  getSortedUnpinnedChatsArray(): Chat[] {
    return this.sortedUnpinnedChatsMap.getSortedValues();
  }

  add(chat: Chat): void {
    this.upsert(chat);
  }

  upsert(chat: Chat): void {
    const key = chat.chatId.toString();
    if (chat.pinned) {
      this.upsertPinned(key, chat);
      return;
    }

    if (this.pinnedChatsMap.hasKey(key)) {
      const pinnedIndex = this.pinnedChatsArray.findIndex((value) => value.chatId.toString() === key);
      this.pinnedChatsMap.remove(key);
      if (pinnedIndex >= 0) {
        this.pinnedChatsArray.splice(pinnedIndex, 1);
        this.notifyDataDelete(pinnedIndex);
      }
    }

    const update = this.sortedUnpinnedChatsMap.set(key, chat);
    if (update.previousIndex >= 0) {
      this.notifyDataReload();
    } else {
      this.notifyDataAdd(update.index + this.pinnedChatsArray.length);
    }
  }

  addChatsFromPinnedAndUnpinnedArrays(pinnedChats: Chat[], unpinnedChats: Chat[]): void {
    this.pinnedChatsArray = pinnedChats;
    for (let i = 0; i < pinnedChats.length; i++) {
      this.pinnedChatsMap.set(pinnedChats[i].chatId.toString(), pinnedChats[i]);
    }
    for (let i = 0; i < unpinnedChats.length; i++) {
      this.sortedUnpinnedChatsMap.set(unpinnedChats[i].chatId.toString(), unpinnedChats[i]);
    }
    this.notifyDataReload();
  }

  async addChatsFromSingleArray(chats: Chat[]): Promise<void> {
    this.replaceAll(chats);
  }

  addAllPinned(chats: Chat[]): void {
    this.pinnedChatsArray.push(...chats);
    let oldLength = this.pinnedChatsMap.length;
    for (let i = 0; i < chats.length; i++) {
      this.pinnedChatsMap.set(chats[i].chatId.toString(),
        chats[i]); // we cannot use setAll because it takes a HashMap but not an array
      this.notifyDataAdd(oldLength + i);
    }
    // this.notifyDataReload(); // no need to notify data reload since we assume number of pinned chats is limited
  }

  addAllUnpinned(chats: Chat[]): void {
    for (let i = 0; i < chats.length; i++) {
      this.sortedUnpinnedChatsMap.set(chats[i].chatId.toString(), chats[i]);
    }
    this.notifyDataReload();
  }

  delete(chatId: string): void {
    if (this.pinnedChatsMap.hasKey(chatId)) {
      this.pinnedChatsMap.remove(chatId);
      const index = this.pinnedChatsArray.findIndex(chat => chat.chatId.toString() === chatId);
      if (index >= 0) {
        this.pinnedChatsArray.splice(index, 1);
        this.notifyDataDelete(index);
      }
    } else {
      const index = this.sortedUnpinnedChatsMap.delete(chatId);
      if (index >= 0) {
        this.notifyDataDelete(index + this.pinnedChatsMap.length);
      }
    }
  }

  async deleteAt(index: number): Promise<void> {
    const chatId = (await this.getData(index))?.chatId.toString();
    if (!chatId) {
      return;
    }
    this.delete(chatId);
    this.notifyDataChange(index);
  }

  deleteAll(): void {
    this.pinnedChatsMap.clear();
    this.pinnedChatsArray = [];
    this.sortedUnpinnedChatsMap.clear();
    this.notifyDataReload();
  }

  replaceAll(chats: Chat[]): void {
    this.pinnedChatsMap.clear();
    this.pinnedChatsArray = [];
    this.sortedUnpinnedChatsMap.clear();
    for (const chat of chats) {
      if (chat.pinned) {
        this.pinnedChatsArray.push(chat);
        this.pinnedChatsMap.set(chat.chatId.toString(), chat);
      } else {
        this.sortedUnpinnedChatsMap.set(chat.chatId.toString(), chat);
      }
    }
    this.notifyDataReload();
  }

  modify(chat: Chat): void {
    this.upsert(chat);
  }

  // I don't think this method will be used but just in case we need it
  modifyAt(index: number, chat: Chat): void {
    this.sortedUnpinnedChatsMap.set(chat.chatId.toString(), chat);
    this.notifyDataChange(index);
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      console.info('add listener');
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      console.info('remove listener');
      this.listeners.splice(pos, 1);
    }
  }

  // 通知LazyForEach组件需要重载所有子组件
  notifyDataReload(): void {
    Logger.debug('notifyDataReload');
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    })
  }

  // 通知LazyForEach组件需要在index对应索引处添加子组件
  notifyDataAdd(index: number): void {
    Logger.debug('notifyDataAdd: ' + index);
    this.listeners.forEach(listener => {
      listener.onDataAdd(index);
    })
  }

  // 通知LazyForEach组件在index对应索引处数据有变化，需要重建该子组件
  notifyDataChange(index: number): void {
    Logger.debug('notifyDataChange: ' + index);
    this.listeners.forEach(listener => {
      listener.onDataChange(index);
    })
  }

  // 通知LazyForEach组件需要在index对应索引处删除该子组件
  notifyDataDelete(index: number): void {
    Logger.debug('notifyDataDelete: ' + index);
    this.listeners.forEach(listener => {
      listener.onDataDelete(index);
    })
  }

  // 通知LazyForEach组件将from索引和to索引处的子组件进行交换
  notifyDataMove(from: number, to: number): void {
    Logger.debug('notifyDataMove: ' + from + ' ' + to);
    this.listeners.forEach(listener => {
      listener.onDataMove(from, to);
    })
  }

  private upsertPinned(key: string, chat: Chat): void {
    const oldPinned = this.pinnedChatsMap.get(key);
    if (oldPinned) {
      const index = this.pinnedChatsArray.indexOf(oldPinned);
      if (index >= 0) {
        this.pinnedChatsArray[index] = chat;
        this.pinnedChatsMap.set(key, chat);
        this.notifyDataReload();
      }
      return;
    }

    const unpinnedIndex = this.sortedUnpinnedChatsMap.indexOf(key);
    if (unpinnedIndex >= 0) {
      this.sortedUnpinnedChatsMap.delete(key);
      this.notifyDataDelete(unpinnedIndex + this.pinnedChatsArray.length);
    }

    this.pinnedChatsArray.push(chat);
    this.pinnedChatsMap.set(key, chat);
    this.notifyDataAdd(this.pinnedChatsArray.length - 1);
  }
}
