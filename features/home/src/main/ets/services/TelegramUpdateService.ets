import { Logger } from '@ohos/base';
import {
  NativeChat,
  NativeDeletedMessages,
  NativeMessage,
  NativeReadState,
  NativeSearchResult,
  NativeSeenChat
} from '../bridge/TelegramBridge';
import { Chat } from '../entities/Chat';
import { Message } from '../entities/Message';
import { SeenChat } from '../entities/SeenChat';
import { MessageDataSource } from '../viewmodel/Message/MessageDataSource';
import { HashMapEntry, TelegramRuntimeContext, TelegramRuntimeState } from './TelegramRuntimeState';

export class TelegramUpdateService {
  private state: TelegramRuntimeState;

  constructor(state: TelegramRuntimeState) {
    this.state = state;
  }

  async applySeenChatCached(nativeSeenChat: NativeSeenChat): Promise<void> {
    const context = this.state.getContext();
    if (!context) {
      return;
    }

    const seenChat = SeenChat.fromNative(nativeSeenChat);
    context.seenChatsMap.set(seenChat.chatId.toString(), seenChat);
  }

  async applyChatUpdated(nativeSeenChat: NativeSeenChat | undefined, nativeChat: NativeChat,
    nativeMessages: NativeMessage[]): Promise<void> {
    const context = this.state.getContext();
    if (!context) {
      return;
    }

    if (nativeSeenChat) {
      const seenChat = SeenChat.fromNative(nativeSeenChat);
      context.seenChatsMap.set(seenChat.chatId.toString(), seenChat);
    }
    const chat = Chat.fromNative(nativeChat);
    const messages = this.toMessages(nativeMessages);
    Logger.info('TelegramUpdateService applyChatUpdated chatId=' + chat.chatId + ' messages=' + messages.length);
    context.chatDataSource.upsert(chat);
    if (messages.length > 0) {
      this.state.ensureMessages(chat.chatId).append(messages);
    }
  }

  async applyIncomingMessage(nativeChat: NativeChat | undefined, nativeMessage: NativeMessage): Promise<void> {
    const context = this.state.getContext();
    if (!context) {
      Logger.debug('TelegramUpdateService incoming message ignored before runtime context is ready');
      return;
    }

    const message = Message.fromNative(nativeMessage);
    const messageDataSource = this.state.ensureMessages(message.chatId);
    Logger.info('TelegramUpdateService applyIncomingMessage chatId=' + message.chatId +
      ' messageId=' + message.messageId + ' hasChat=' + (nativeChat !== undefined));

    if (nativeChat) {
      const chat = Chat.fromNative(nativeChat);
      chat.lastMessageId = message.messageId;
      chat.lastMessageSenderName = message.senderName;
      chat.lastMessageText = message.text;
      chat.lastMessageTimestamp = message.timestamp;
      context.chatDataSource.upsert(chat);
    } else {
      this.updateExistingChatPreview(context, message);
    }

    messageDataSource.upsert(message);
  }

  async applyEditedMessage(nativeMessage: NativeMessage): Promise<void> {
    const context = this.state.getContext();
    if (!context) {
      return;
    }

    const message = Message.fromNative(nativeMessage);
    this.state.ensureMessages(message.chatId).upsert(message);

    const existingChat = context.chatDataSource.get(message.chatId.toString());
    if (existingChat && existingChat.lastMessageId === message.messageId) {
      existingChat.lastMessageText = message.text;
      existingChat.lastMessageSenderName = message.senderName;
      existingChat.lastMessageTimestamp = message.timestamp;
      context.chatDataSource.upsert(existingChat);
    }
  }

  async applyDeletedMessages(nativeDeletedMessages: NativeDeletedMessages): Promise<void> {
    const context = this.state.getContext();
    if (!context) {
      return;
    }

    if (nativeDeletedMessages.chatId !== undefined && nativeDeletedMessages.chatId !== null) {
      const dataSource = context.messagesOfChatMap.get(nativeDeletedMessages.chatId.toString());
      if (dataSource) {
        this.deleteMessagesFromDataSource(dataSource, nativeDeletedMessages.messageIds);
      }
      return;
    }

    const mapEntries = this.state.entries(context.messagesOfChatMap);
    for (let i = 0; i < mapEntries.length; i++) {
      this.deleteMessagesFromEntry(mapEntries[i], nativeDeletedMessages.messageIds);
    }
  }

  async applyReadState(nativeReadState: NativeReadState): Promise<void> {
    const context = this.state.getContext();
    if (!context) {
      return;
    }

    const chat = context.chatDataSource.get(nativeReadState.chatId.toString());
    if (!chat) {
      return;
    }
    if (nativeReadState.inbox) {
      chat.readInboxMaxId = nativeReadState.maxId;
      chat.unreadCount = nativeReadState.unreadCount;
    } else {
      chat.readOutboxMaxId = nativeReadState.maxId;
    }
    context.chatDataSource.upsert(chat);
  }

  async cacheSearchResult(result: NativeSearchResult): Promise<Chat | undefined> {
    const context = this.state.getContext();
    if (result.seenChat && context) {
      const seenChat = SeenChat.fromNative(result.seenChat);
      context.seenChatsMap.set(seenChat.chatId.toString(), seenChat);
    }
    if (result.chat && context) {
      const chat = Chat.fromNative(result.chat);
      context.chatDataSource.upsert(chat);
      this.state.ensureMessages(chat.chatId);
      return chat;
    }
    return undefined;
  }

  private updateExistingChatPreview(context: TelegramRuntimeContext, message: Message): void {
    const existingChat = context.chatDataSource.get(message.chatId.toString());
    if (existingChat) {
      existingChat.lastMessageId = message.messageId;
      existingChat.lastMessageSenderName = message.senderName;
      existingChat.lastMessageText = message.text;
      existingChat.lastMessageTimestamp = message.timestamp;
      context.chatDataSource.upsert(existingChat);
      return;
    }
    Logger.error(`Incoming message received for unknown chat ${message.chatId}`);
  }

  private toMessages(nativeMessages: NativeMessage[]): Message[] {
    const messages: Message[] = [];
    for (let i = 0; i < nativeMessages.length; i++) {
      messages.push(Message.fromNative(nativeMessages[i]));
    }
    return messages;
  }

  private deleteMessagesFromEntry(entry: HashMapEntry<MessageDataSource>, messageIds: number[]): void {
    this.deleteMessagesFromDataSource(entry.value, messageIds);
  }

  private deleteMessagesFromDataSource(dataSource: MessageDataSource, messageIds: number[]): void {
    for (let i = 0; i < messageIds.length; i++) {
      dataSource.deleteById(messageIds[i]);
    }
  }
}
