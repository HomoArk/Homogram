import { Logger } from '@ohos/base';
import {
  telegramBridge,
  NativeChat,
  NativeDeletedMessages,
  NativeDialog,
  NativeDialogPage,
  NativeMessage,
  NativeReadState,
  NativeSeenChat
} from '../bridge/TelegramBridge';
import { Chat } from '../entities/Chat';
import { SeenChat } from '../entities/SeenChat';
import { MessageDataSource } from '../viewmodel/Message/MessageDataSource';
import { TelegramRuntimeContext, TelegramRuntimeState } from './TelegramRuntimeState';
import { TelegramUpdateService } from './TelegramUpdateService';

export class TelegramRuntimeService {
  private state: TelegramRuntimeState;
  private updateService: TelegramUpdateService;

  constructor(state: TelegramRuntimeState, updateService: TelegramUpdateService) {
    this.state = state;
    this.updateService = updateService;
  }

  async initialize(context: TelegramRuntimeContext): Promise<void> {
    Logger.info('TelegramRuntimeService initialize');
    this.state.setContext(context);
    await telegramBridge.initialize({
      onSeenChatCached: async (seenChat: NativeSeenChat): Promise<void> =>
        this.updateService.applySeenChatCached(seenChat),
      onChatUpdated: async (seenChat: NativeSeenChat | undefined, chat: NativeChat, messages: NativeMessage[]): Promise<void> =>
        this.updateService.applyChatUpdated(seenChat, chat, messages),
      onIncomingMessage: async (chat: NativeChat | undefined, message: NativeMessage): Promise<void> =>
        this.updateService.applyIncomingMessage(chat, message),
      onEditedMessage: async (message: NativeMessage): Promise<void> =>
        this.updateService.applyEditedMessage(message),
      onDeletedMessages: async (deletedMessages: NativeDeletedMessages): Promise<void> =>
        this.updateService.applyDeletedMessages(deletedMessages),
      onReadState: async (readState: NativeReadState): Promise<void> =>
        this.updateService.applyReadState(readState),
    });
  }

  async hydrateFromCache(): Promise<void> {
    const context = this.state.getContext();
    if (!context || this.state.isHydrated()) {
      Logger.debug('TelegramRuntimeService hydrateFromCache skipped');
      return;
    }

    Logger.info('TelegramRuntimeService hydrateFromCache start');
    await this.loadNativeDialogs(context);
    this.state.markHydrated();
    Logger.info('TelegramRuntimeService hydrateFromCache done');
  }

  async refreshChats(): Promise<void> {
    const context = this.state.getContext();
    if (!context) {
      Logger.debug('TelegramRuntimeService refreshChats skipped without context');
      return;
    }

    Logger.info('TelegramRuntimeService refreshChats start');
    await telegramBridge.startSync();
    await this.loadNativeDialogs(context);
    Logger.info('TelegramRuntimeService refreshChats done');
  }

  async start(): Promise<void> {
    Logger.info('TelegramRuntimeService start');
    await telegramBridge.startSync();
  }

  async stop(): Promise<void> {
    await telegramBridge.stopSync();
  }

  async reconnectAndStart(): Promise<boolean> {
    Logger.info('TelegramRuntimeService reconnectAndStart start');
    const authorized = await telegramBridge.reconnect();
    if (authorized) {
      await this.start();
    }
    Logger.info('TelegramRuntimeService reconnectAndStart authorized=' + authorized);
    return authorized;
  }

  private async loadNativeDialogs(context: TelegramRuntimeContext): Promise<void> {
    const page: NativeDialogPage = await telegramBridge.getDialogs(undefined, 100);
    const chats: Chat[] = [];
    context.seenChatsMap.clear();
    Logger.info('TelegramRuntimeService loadNativeDialogs dialogs=' + page.dialogs.length);
    for (let i = 0; i < page.dialogs.length; i++) {
      const dialog: NativeDialog = page.dialogs[i];
      const seenChat = SeenChat.fromNative(dialog.peer);
      const chat = Chat.fromNative(dialog.chat);
      context.seenChatsMap.set(seenChat.chatId.toString(), seenChat);
      chats.push(chat);

      if (!context.messagesOfChatMap.hasKey(chat.chatId.toString())) {
        const dataSource = new MessageDataSource();
        context.messagesOfChatMap.set(chat.chatId.toString(), dataSource);
      }
    }
    context.chatDataSource.replaceAll(chats);
    Logger.info('TelegramRuntimeService loadNativeDialogs applied chats=' + chats.length);
  }
}
