import { Logger } from '@ohos/base';
import {
  NativeChat,
  NativeDeletedMessages,
  NativeDialog,
  NativeLoadSource,
  NativeMessage,
  NativeMessageLoadType,
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
    const mergedChat = this.chatWithAuthoritativeMessagePreview(chat, messages);
    Logger.info('TelegramUpdateService applyChatUpdated chatId=' + mergedChat.chatId + ' messages=' + messages.length +
      ' top=' + mergedChat.lastMessageId + '/' + mergedChat.lastMessageTimestamp +
      ' preview=' + mergedChat.lastMessageText);
    context.chatDataSource.upsert(mergedChat);
    if (messages.length > 0) {
      this.state.ensureMessages(chat.chatId).upsertMany(messages);
    }
  }

  async applyDialogsLoaded(nativeDialogs: NativeDialog[], nativeMessages: NativeMessage[],
    source: NativeLoadSource | undefined): Promise<void> {
    const context = this.state.getContext();
    if (!context) {
      return;
    }

    const messages = this.toMessages(nativeMessages);
    const chats: Chat[] = [];
    for (let i = 0; i < nativeDialogs.length; i++) {
      const dialog = nativeDialogs[i];
      const seenChat = SeenChat.fromNative(dialog.peer);
      const previewMessage = this.messageFromNative(dialog.topMessage);
      const chat = this.chatWithPreviewMessage(Chat.fromNative(dialog.chat), previewMessage);
      context.seenChatsMap.set(seenChat.chatId.toString(), seenChat);
      chats.push(chat);
      this.state.ensureMessages(chat.chatId);
      if (previewMessage !== undefined) {
        this.state.ensureMessages(chat.chatId).upsert(previewMessage);
      }
    }
    Logger.info('TelegramUpdateService applyDialogsLoaded source=' + (source !== undefined ? source.toString() : 'none') +
      ' dialogs=' + chats.length + ' messages=' + nativeMessages.length);
    if (context.chatDataSource.totalCount() === 0 && chats.length > 0) {
      context.chatDataSource.replaceAll(chats);
    } else {
      for (let i = 0; i < chats.length; i++) {
        context.chatDataSource.upsert(chats[i]);
      }
    }
    this.upsertMessages(messages);
  }

  async applyMessagesLoaded(nativeChat: NativeChat | undefined, nativeMessages: NativeMessage[],
    source: NativeLoadSource | undefined, loadType: NativeMessageLoadType | undefined): Promise<void> {
    const context = this.state.getContext();
    if (!context) {
      return;
    }
    Logger.info('TelegramUpdateService applyMessagesLoaded source=' + (source !== undefined ? source.toString() : 'none') +
      ' loadType=' + (loadType !== undefined ? loadType.toString() : 'none') + ' messages=' + nativeMessages.length +
      ' hasChat=' + (nativeChat !== undefined));
    const messages = this.toMessages(nativeMessages);
    if (nativeChat) {
      context.chatDataSource.upsert(this.chatWithAuthoritativeMessagePreview(Chat.fromNative(nativeChat), messages));
    }
    this.upsertMessages(messages);
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
      context.chatDataSource.upsert(this.chatWithAuthoritativeMessagePreview(chat, [message]));
    } else {
      Logger.warn('TelegramUpdateService incoming message did not include native chat snapshot chatId=' + message.chatId);
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
      context.chatDataSource.upsert(this.copyChatWithPreview(existingChat, message));
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

  private toMessages(nativeMessages: NativeMessage[]): Message[] {
    const messages: Message[] = [];
    for (let i = 0; i < nativeMessages.length; i++) {
      messages.push(Message.fromNative(nativeMessages[i]));
    }
    return messages;
  }

  private messageFromNative(nativeMessage: NativeMessage | undefined): Message | undefined {
    if (nativeMessage === undefined) {
      return undefined;
    }
    return Message.fromNative(nativeMessage);
  }

  private upsertMessages(messages: Message[]): void {
    for (let i = 0; i < messages.length; i++) {
      const message = messages[i];
      this.state.ensureMessages(message.chatId).upsert(message);
    }
  }

  private updateExistingChatPreview(context: TelegramRuntimeContext, message: Message): void {
    const chat = context.chatDataSource.get(message.chatId.toString());
    if (!chat) {
      Logger.warn('TelegramUpdateService cannot update preview for unknown chatId=' + message.chatId +
        ' messageId=' + message.messageId);
      return;
    }
    if (!this.isNewerThanChatTop(chat, message)) {
      Logger.debug('TelegramUpdateService skipped stale preview update chatId=' + message.chatId +
        ' messageId=' + message.messageId + ' currentTop=' + chat.lastMessageId);
      return;
    }

    context.chatDataSource.upsert(this.copyChatWithPreview(chat, message));
  }

  private chatWithAuthoritativeMessagePreview(chat: Chat, messages: Message[]): Chat {
    let newestMessage: Message | undefined = undefined;
    for (let i = 0; i < messages.length; i++) {
      const message = messages[i];
      if (message.chatId !== chat.chatId) {
        continue;
      }
      if (!this.isAtLeastChatTop(chat, message)) {
        continue;
      }
      if (newestMessage === undefined || this.isNewerThanMessage(newestMessage, message)) {
        newestMessage = message;
      }
    }
    if (newestMessage === undefined) {
      return chat;
    }
    return this.copyChatWithPreview(chat, newestMessage);
  }

  private chatWithPreviewMessage(chat: Chat, message: Message | undefined): Chat {
    if (message === undefined || message.chatId !== chat.chatId) {
      return chat;
    }
    return this.copyChatWithPreview(chat, message);
  }

  private copyChatWithPreview(chat: Chat, message: Message): Chat {
    return new Chat(
      chat.chatId,
      chat.chatType,
      chat.name,
      chat.pinned,
      message.messageId,
      message.senderName,
      message.text,
      message.timestamp,
      chat.megagroup,
      chat.forum,
      chat.unreadCount,
      chat.readInboxMaxId,
      chat.readOutboxMaxId,
      chat.muted,
      chat.archived
    );
  }

  private isNewerThanChatTop(chat: Chat, message: Message): boolean {
    if (chat.lastMessageId <= 0) {
      return true;
    }
    if (message.timestamp !== chat.lastMessageTimestamp) {
      return message.timestamp > chat.lastMessageTimestamp;
    }
    return message.messageId > chat.lastMessageId;
  }

  private isAtLeastChatTop(chat: Chat, message: Message): boolean {
    if (chat.lastMessageId <= 0) {
      return true;
    }
    if (message.timestamp !== chat.lastMessageTimestamp) {
      return message.timestamp > chat.lastMessageTimestamp;
    }
    return message.messageId >= chat.lastMessageId;
  }

  private isNewerThanMessage(current: Message, candidate: Message): boolean {
    if (candidate.timestamp !== current.timestamp) {
      return candidate.timestamp > current.timestamp;
    }
    return candidate.messageId > current.messageId;
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
