import { HashMap } from '@kit.ArkTS';
import { ChatDataSource } from '../viewmodel/Chat/ChatDataSource';
import { MessageDataSource } from '../viewmodel/Message/MessageDataSource';
import { SeenChat } from '../entities/SeenChat';

export interface TelegramRuntimeContext {
  chatDataSource: ChatDataSource;
  messagesOfChatMap: HashMap<string, MessageDataSource>;
  seenChatsMap: HashMap<string, SeenChat>;
}

export class HashMapEntry<T> {
  key: string;
  value: T;

  constructor(key: string, value: T) {
    this.key = key;
    this.value = value;
  }
}

export class TelegramRuntimeState {
  private context?: TelegramRuntimeContext;
  private hydrated: boolean = false;

  setContext(context: TelegramRuntimeContext): void {
    this.context = context;
  }

  getContext(): TelegramRuntimeContext | undefined {
    return this.context;
  }

  isHydrated(): boolean {
    return this.hydrated;
  }

  markHydrated(): void {
    this.hydrated = true;
  }

  ensureMessages(chatId: number): MessageDataSource {
    if (!this.context) {
      return new MessageDataSource();
    }
    const key = chatId.toString();
    let dataSource = this.context.messagesOfChatMap.get(key);
    if (!dataSource) {
      dataSource = new MessageDataSource();
      this.context.messagesOfChatMap.set(key, dataSource);
    }
    return dataSource;
  }

  entries<T>(map: HashMap<string, T>): Array<HashMapEntry<T>> {
    const result: Array<HashMapEntry<T>> = [];
    for (const key of map.keys()) {
      const value = map.get(key);
      if (value !== undefined) {
        result.push(new HashMapEntry<T>(key, value));
      }
    }
    return result;
  }
}
