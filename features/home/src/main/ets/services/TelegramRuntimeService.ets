import { Logger } from '@ohos/base';
import {
  telegramBridge,
  NativeChat,
  NativeDeletedMessages,
  NativeDialog,
  NativeDialogPage,
  NativeLoadSource,
  NativeMessage,
  NativeMessageLoadType,
  NativeReadState,
  NativeSeenChat
} from '../bridge/TelegramBridge';
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
      onDialogsLoaded: async (dialogs: NativeDialog[], messages: NativeMessage[], source: NativeLoadSource | undefined): Promise<void> =>
        this.updateService.applyDialogsLoaded(dialogs, messages, source),
      onMessagesLoaded: async (chat: NativeChat | undefined, messages: NativeMessage[], source: NativeLoadSource | undefined,
        loadType: NativeMessageLoadType | undefined): Promise<void> =>
        this.updateService.applyMessagesLoaded(chat, messages, source, loadType),
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
    context.seenChatsMap.clear();
    Logger.info('TelegramRuntimeService loadNativeDialogs dialogs=' + page.dialogs.length);
    await this.updateService.applyDialogsLoaded(page.dialogs, [], NativeLoadSource.Cache);
    Logger.info('TelegramRuntimeService loadNativeDialogs applied dialogs=' + page.dialogs.length);
  }
}
