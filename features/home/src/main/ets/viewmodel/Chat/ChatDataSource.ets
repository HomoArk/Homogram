import { HashMap } from '@kit.ArkTS';
import { Logger } from '@ohos/base';
import { SortedHashMap } from '@ohos/base';
import { Chat } from '../../entities/Chat';
import { ChatRowState } from './ChatRowState';

export class ChatDataSource implements IDataSource {
  private pinnedChatsMap: HashMap<string, ChatRowState> = new HashMap<string, ChatRowState>();
  private pinnedChatsArray: ChatRowState[] =
    []; // instead using pinnedChatsMap.values() to iterate, we use this array to make it faster
  private sortedUnpinnedChatsMap: SortedHashMap<string, ChatRowState> = new SortedHashMap<string, ChatRowState>();
  // private readonly fetchInProgress: HashSet<number> = new HashSet<number>();
  private listeners: DataChangeListener[] = [];

  constructor() {
  }

  totalCount(): number {
    return this.sortedUnpinnedChatsMap.length() + this.pinnedChatsMap.length;
  }

  getData(index: number): ChatRowState | undefined {
    if (index < this.pinnedChatsMap.length) {
      return this.pinnedChatsArray[index];
    }
    return this.sortedUnpinnedChatsMap.getValueAt(index - this.pinnedChatsMap.length);
  }

  get(chatId: string): Chat | undefined {
    // always check pinned chats first
    if (this.pinnedChatsMap.hasKey(chatId)) {
      return this.pinnedChatsMap.get(chatId)?.toChat();
    }
    return this.sortedUnpinnedChatsMap.get(chatId)?.toChat();
  }

  // ArkTS doesn't support generator so we cannot merge the iterators into one

  pinnedChats(): IterableIterator<Chat> {
    return this.rowsToChats(this.pinnedChatsArray).values();
  }

  unsortedUnpinnedChats(): IterableIterator<Chat> {
    return this.rowsIteratorToChats(this.sortedUnpinnedChatsMap.valuesIterator()).values();
  }

  sortedUnpinnedChats(): IterableIterator<Chat> {
    return this.rowsIteratorToChats(this.sortedUnpinnedChatsMap.sortedValuesIterator()).values();
  }

  getPinnedChatsArray(): Chat[] {
    return this.rowsToChats(this.pinnedChatsArray);
  }

  getSortedUnpinnedChatsArray(): Chat[] {
    return this.rowsToChats(this.sortedUnpinnedChatsMap.getSortedValues());
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
      const row = this.pinnedChatsMap.get(key);
      this.pinnedChatsMap.remove(key);
      if (pinnedIndex >= 0) {
        this.pinnedChatsArray.splice(pinnedIndex, 1);
      }
      if (row) {
        row.applyChat(chat);
        this.sortedUnpinnedChatsMap.set(key, row);
        this.notifyDataReload();
        return;
      }
    }

    const existingRow = this.sortedUnpinnedChatsMap.get(key);
    if (existingRow) {
      const oldLength = this.sortedUnpinnedChatsMap.length();
      const previousIndex = this.sortedUnpinnedChatsMap.delete(key);
      existingRow.applyChat(chat);
      const update = this.sortedUnpinnedChatsMap.set(key, existingRow);
      const newIndex = update.index + this.pinnedChatsArray.length;
      if (previousIndex >= 0 && previousIndex !== update.index) {
        this.notifyDataMove(previousIndex + this.pinnedChatsArray.length, newIndex);
        this.notifyDataChange(newIndex);
      } else if (oldLength === this.sortedUnpinnedChatsMap.length()) {
        this.notifyDataChange(newIndex);
      }
    } else {
      const update = this.sortedUnpinnedChatsMap.set(key, new ChatRowState(chat));
      this.notifyDataAdd(update.index + this.pinnedChatsArray.length);
    }
  }

  addChatsFromPinnedAndUnpinnedArrays(pinnedChats: Chat[], unpinnedChats: Chat[]): void {
    this.pinnedChatsArray = [];
    this.pinnedChatsMap.clear();
    this.sortedUnpinnedChatsMap.clear();
    for (let i = 0; i < pinnedChats.length; i++) {
      const row = new ChatRowState(pinnedChats[i]);
      this.pinnedChatsArray.push(row);
      this.pinnedChatsMap.set(row.chatId.toString(), row);
    }
    for (let i = 0; i < unpinnedChats.length; i++) {
      this.sortedUnpinnedChatsMap.set(unpinnedChats[i].chatId.toString(), new ChatRowState(unpinnedChats[i]));
    }
    this.notifyDataReload();
  }

  async addChatsFromSingleArray(chats: Chat[]): Promise<void> {
    this.replaceAll(chats);
  }

  addAllPinned(chats: Chat[]): void {
    let oldLength = this.pinnedChatsMap.length;
    for (let i = 0; i < chats.length; i++) {
      const row = new ChatRowState(chats[i]);
      this.pinnedChatsArray.push(row);
      this.pinnedChatsMap.set(row.chatId.toString(),
        row); // we cannot use setAll because it takes a HashMap but not an array
      this.notifyDataAdd(oldLength + i);
    }
    // this.notifyDataReload(); // no need to notify data reload since we assume number of pinned chats is limited
  }

  addAllUnpinned(chats: Chat[]): void {
    for (let i = 0; i < chats.length; i++) {
      this.sortedUnpinnedChatsMap.set(chats[i].chatId.toString(), new ChatRowState(chats[i]));
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
        const row = new ChatRowState(chat);
        this.pinnedChatsArray.push(row);
        this.pinnedChatsMap.set(chat.chatId.toString(), row);
      } else {
        this.sortedUnpinnedChatsMap.set(chat.chatId.toString(), new ChatRowState(chat));
      }
    }
    this.notifyDataReload();
  }

  modify(chat: Chat): void {
    this.upsert(chat);
  }

  // I don't think this method will be used but just in case we need it
  modifyAt(index: number, chat: Chat): void {
    this.upsert(chat);
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
        oldPinned.applyChat(chat);
        this.notifyDataChange(index);
      }
      return;
    }

    const unpinnedIndex = this.sortedUnpinnedChatsMap.indexOf(key);
    if (unpinnedIndex >= 0) {
      const row = this.sortedUnpinnedChatsMap.get(key);
      this.sortedUnpinnedChatsMap.delete(key);
      if (row) {
        row.applyChat(chat);
        this.pinnedChatsArray.push(row);
        this.pinnedChatsMap.set(key, row);
        this.notifyDataReload();
        return;
      }
    }

    const row = new ChatRowState(chat);
    this.pinnedChatsArray.push(row);
    this.pinnedChatsMap.set(key, row);
    this.notifyDataAdd(this.pinnedChatsArray.length - 1);
  }

  private rowsToChats(rows: ChatRowState[]): Chat[] {
    const chats: Chat[] = [];
    for (let i = 0; i < rows.length; i++) {
      chats.push(rows[i].toChat());
    }
    return chats;
  }

  private rowsIteratorToChats(rows: IterableIterator<ChatRowState>): Chat[] {
    const chats: Chat[] = [];
    for (const row of rows) {
      chats.push(row.toChat());
    }
    return chats;
  }
}
