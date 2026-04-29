import { HashMap } from '@kit.ArkTS';
import { Chat } from '../entities/Chat';
import { Message } from '../entities/Message';
import { SeenChat } from '../entities/SeenChat';
import { NativeChat, NativeMessage, NativePackedChat, NativeSeenChat } from '../bridge/TelegramBridge';
import { chatDao } from '../dao/ChatDao';
import { messageDao } from '../dao/MessageDao';
import { seenChatDao } from '../dao/SeenChatDao';
import { MessageDataSource } from '../viewmodel/Message/MessageDataSource';

export interface CachedTelegramState {
  packedChats: NativePackedChat[];
  chats: Chat[];
  seenChatsMap: HashMap<string, SeenChat>;
  messagesByChatId: HashMap<string, MessageDataSource>;
}

export interface CachedChatPair {
  seenChat: SeenChat;
  chat: Chat;
}

class PackedChatRecord implements NativePackedChat {
  chatId: number;
  packedChat: string;

  constructor(chatId: number, packedChat: string) {
    this.chatId = chatId;
    this.packedChat = packedChat;
  }
}

class CachedTelegramStateRecord implements CachedTelegramState {
  packedChats: NativePackedChat[];
  chats: Chat[];
  seenChatsMap: HashMap<string, SeenChat>;
  messagesByChatId: HashMap<string, MessageDataSource>;

  constructor(
    packedChats: NativePackedChat[],
    chats: Chat[],
    seenChatsMap: HashMap<string, SeenChat>,
    messagesByChatId: HashMap<string, MessageDataSource>,
  ) {
    this.packedChats = packedChats;
    this.chats = chats;
    this.seenChatsMap = seenChatsMap;
    this.messagesByChatId = messagesByChatId;
  }
}

class TelegramCacheRepository {
  async hydrate(): Promise<CachedTelegramState> {
    const seenChats = await seenChatDao.getAllSeenChats();
    const chats = await chatDao.getAllChats();
    const seenChatsMap = new HashMap<string, SeenChat>();
    const messagesByChatId = new HashMap<string, MessageDataSource>();

    for (const seenChat of seenChats) {
      seenChatsMap.set(seenChat.chatId.toString(), seenChat);
    }

    for (const chat of chats) {
      const dataSource = new MessageDataSource();
      const messages = await messageDao.getRecentMessagesByChatId(chat.chatId, 100)
        .catch(async () => messageDao.getMessagesByChatId(chat.chatId));
      dataSource.setMessages(messages);
      messagesByChatId.set(chat.chatId.toString(), dataSource);
    }

    const packedChats: NativePackedChat[] = seenChats.map((value) => {
      return new PackedChatRecord(value.chatId, value.packedChat);
    });

    return new CachedTelegramStateRecord(
      packedChats,
      chats,
      seenChatsMap,
      messagesByChatId,
    );
  }

  async cacheSeenChat(nativeSeenChat: NativeSeenChat): Promise<SeenChat> {
    const seenChat = SeenChat.fromNative(nativeSeenChat);
    await seenChatDao.insertSeenChat(seenChat);
    return seenChat;
  }

  async cacheChat(nativeChat: NativeChat): Promise<Chat> {
    const chat = Chat.fromNative(nativeChat);
    await chatDao.insertChat(chat);
    return chat;
  }

  async cacheChatPair(nativeSeenChat: NativeSeenChat, nativeChat: NativeChat): Promise<CachedChatPair> {
    const chat = await this.cacheChat(nativeChat);
    const seenChat = await this.cacheSeenChat(nativeSeenChat);
    return new CachedChatPairRecord(seenChat, chat);
  }

  async cacheMessages(nativeMessages: NativeMessage[]): Promise<Message[]> {
    const messages = nativeMessages.map((nativeMessage) => Message.fromNative(nativeMessage));
    if (messages.length > 0) {
      await messageDao.insertMessages(messages);
    }
    return messages;
  }

  async cacheMessage(nativeMessage: NativeMessage): Promise<Message> {
    const message = Message.fromNative(nativeMessage);
    await messageDao.insertMessage(message);
    return message;
  }
}

class CachedChatPairRecord implements CachedChatPair {
  seenChat: SeenChat;
  chat: Chat;

  constructor(seenChat: SeenChat, chat: Chat) {
    this.seenChat = seenChat;
    this.chat = chat;
  }
}

export const telegramCacheRepository = new TelegramCacheRepository();
