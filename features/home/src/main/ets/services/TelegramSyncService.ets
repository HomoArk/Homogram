import { Logger } from '@ohos/base';
import { HashMap } from '@kit.ArkTS';
import { telegramBridge, NativeChat, NativeMessage, NativeSeenChat } from '../bridge/TelegramBridge';
import { telegramCacheRepository } from '../repositories/TelegramCacheRepository';
import { Chat } from '../entities/Chat';
import { Message } from '../entities/Message';
import { SeenChat } from '../entities/SeenChat';
import { ChatDataSource } from '../viewmodel/Chat/ChatDataSource';
import { MessageDataSource } from '../viewmodel/Message/MessageDataSource';

export interface TelegramRuntimeContext {
  chatDataSource: ChatDataSource;
  messagesOfChatMap: HashMap<string, MessageDataSource>;
  seenChatsMap: HashMap<string, SeenChat>;
}

class TelegramSyncService {
  private context?: TelegramRuntimeContext;
  private hydrated: boolean = false;

  async initialize(context: TelegramRuntimeContext): Promise<void> {
    this.context = context;
    await telegramBridge.initialize({
      onSeenChatCached: async (seenChat: NativeSeenChat): Promise<void> => this.onSeenChatCached(seenChat),
      onChatUpdated: async (seenChat: NativeSeenChat, chat: NativeChat, messages: NativeMessage[]): Promise<void> =>
        this.onChatUpdated(seenChat, chat, messages),
      onIncomingMessage: async (chat: NativeChat | undefined, message: NativeMessage): Promise<void> =>
        this.onIncomingMessage(chat, message),
    });
  }

  async hydrateFromCache(): Promise<void> {
    if (!this.context || this.hydrated) {
      return;
    }

    const cached = await telegramCacheRepository.hydrate();
    this.context.chatDataSource.replaceAll(cached.chats);
    this.context.seenChatsMap.clear();
    for (const seenChat of cached.seenChatsMap.values()) {
      this.context.seenChatsMap.set(seenChat.chatId.toString(), seenChat);
    }
    this.context.messagesOfChatMap.clear();
    const entries = this.entries(cached.messagesByChatId);
    for (let i = 0; i < entries.length; i++) {
      this.context.messagesOfChatMap.set(entries[i].key, entries[i].value);
    }
    await telegramBridge.syncCachesFromLocalDb(
      cached.packedChats,
      cached.chats.map((chat) => chat.toNative()),
    );
    this.hydrated = true;
  }

  async refreshChats(): Promise<void> {
    if (!this.context) {
      return;
    }

    const lastMessageIds = new Map<string, number>();
    for (const chat of this.context.chatDataSource.getPinnedChatsArray()) {
      lastMessageIds.set(chat.chatId.toString(), chat.lastMessageId);
    }
    for (const chat of this.context.chatDataSource.getSortedUnpinnedChatsArray()) {
      lastMessageIds.set(chat.chatId.toString(), chat.lastMessageId);
    }
    const lastMessageIdsRecord: Record<string, number> = {};
    for (const key of lastMessageIds.keys()) {
      const value = lastMessageIds.get(key);
      if (value !== undefined) {
        lastMessageIdsRecord[key] = value;
      }
    }
    await telegramBridge.loadChatsWithOffset(lastMessageIdsRecord);
  }

  async start(): Promise<void> {
    await telegramBridge.startSync();
  }

  async stop(): Promise<void> {
    await telegramBridge.stopSync();
  }

  async reconnectAndStart(): Promise<boolean> {
    const authorized = await telegramBridge.reconnect();
    if (authorized) {
      await this.start();
    }
    return authorized;
  }

  private async onSeenChatCached(nativeSeenChat: NativeSeenChat): Promise<void> {
    if (!this.context) {
      return;
    }

    const seenChat = await telegramCacheRepository.cacheSeenChat(nativeSeenChat);
    this.context.seenChatsMap.set(seenChat.chatId.toString(), seenChat);
  }

  private async onChatUpdated(nativeSeenChat: NativeSeenChat, nativeChat: NativeChat, nativeMessages: NativeMessage[]): Promise<void> {
    if (!this.context) {
      return;
    }

    const cachedPair = await telegramCacheRepository.cacheChatPair(nativeSeenChat, nativeChat);
    const messages = await telegramCacheRepository.cacheMessages(nativeMessages);

    this.context.seenChatsMap.set(cachedPair.seenChat.chatId.toString(), cachedPair.seenChat);
    this.context.chatDataSource.upsert(cachedPair.chat);
    this.ensureMessages(cachedPair.chat.chatId).append(messages);
  }

  private async onIncomingMessage(nativeChat: NativeChat | undefined, nativeMessage: NativeMessage): Promise<void> {
    if (!this.context) {
      return;
    }

    const message = await telegramCacheRepository.cacheMessage(nativeMessage);
    const messageDataSource = this.ensureMessages(message.chatId);

    if (nativeChat) {
      const chat = await telegramCacheRepository.cacheChat(nativeChat);
      this.context.chatDataSource.upsert(chat);
    } else {
      const existingChat = this.context.chatDataSource.get(message.chatId.toString());
      if (existingChat) {
        existingChat.lastMessageId = message.messageId;
        existingChat.lastMessageSenderName = message.senderName;
        existingChat.lastMessageText = message.text;
        existingChat.lastMessageTimestamp = message.timestamp;
        this.context.chatDataSource.upsert(existingChat);
        await telegramCacheRepository.cacheChat(existingChat.toNative());
      } else {
        Logger.error(`Incoming message received for unknown chat ${message.chatId}`);
      }
    }

    messageDataSource.upsert(message);
  }

  private ensureMessages(chatId: number): MessageDataSource {
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

  private entries<T>(map: HashMap<string, T>): Array<HashMapEntry<T>> {
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

export const telegramSyncService = new TelegramSyncService();

class HashMapEntry<T> {
  key: string;
  value: T;

  constructor(key: string, value: T) {
    this.key = key;
    this.value = value;
  }
}
