import { ChatActionResult } from '../bridge/TelegramBridge';
import { Chat } from '../entities/Chat';
import { SeenChat } from '../entities/SeenChat';
import { TelegramChatActionsService } from './TelegramChatActionsService';
import { TelegramContactsService } from './TelegramContactsService';
import { TelegramMessageActionsService } from './TelegramMessageActionsService';
import { TelegramRuntimeContext, TelegramRuntimeState } from './TelegramRuntimeState';
import { TelegramRuntimeService } from './TelegramRuntimeService';
import { TelegramUpdateService } from './TelegramUpdateService';

class TelegramSyncService {
  private state: TelegramRuntimeState = new TelegramRuntimeState();
  private updateService: TelegramUpdateService = new TelegramUpdateService(this.state);
  private runtimeService: TelegramRuntimeService = new TelegramRuntimeService(this.state, this.updateService);
  private contactsService: TelegramContactsService = new TelegramContactsService(this.state);
  private chatActionsService: TelegramChatActionsService =
    new TelegramChatActionsService(this.state, this.updateService);
  private messageActionsService: TelegramMessageActionsService =
    new TelegramMessageActionsService(this.updateService);

  async initialize(context: TelegramRuntimeContext): Promise<void> {
    await this.runtimeService.initialize(context);
  }

  async hydrateFromCache(): Promise<void> {
    await this.runtimeService.hydrateFromCache();
  }

  async refreshChats(): Promise<void> {
    await this.runtimeService.refreshChats();
  }

  async start(): Promise<void> {
    await this.runtimeService.start();
  }

  async stop(): Promise<void> {
    await this.runtimeService.stop();
  }

  async reconnectAndStart(): Promise<boolean> {
    return this.runtimeService.reconnectAndStart();
  }

  async loadContacts(): Promise<SeenChat[]> {
    return this.contactsService.loadContacts();
  }

  async openChat(chatId: number): Promise<Chat | undefined> {
    return this.chatActionsService.openChat(chatId);
  }

  async deleteMessages(chatId: number, messageIds: number[]): Promise<ChatActionResult> {
    return this.messageActionsService.deleteMessages(chatId, messageIds);
  }

  async markChatRead(chatId: number): Promise<ChatActionResult> {
    return this.chatActionsService.markChatRead(chatId);
  }

  async setChatPinned(chatId: number, pinned: boolean): Promise<ChatActionResult> {
    return this.chatActionsService.setPinned(chatId, pinned);
  }

  async setChatMuted(chatId: number, muted: boolean): Promise<ChatActionResult> {
    return this.chatActionsService.setMuted(chatId, muted);
  }

  async setChatArchived(chatId: number, archived: boolean): Promise<ChatActionResult> {
    return this.chatActionsService.setArchived(chatId, archived);
  }
}

export const telegramSyncService = new TelegramSyncService();
