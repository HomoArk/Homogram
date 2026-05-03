import { ChatActionResult, telegramBridge } from '../bridge/TelegramBridge';
import { Chat } from '../entities/Chat';
import { TelegramRuntimeState } from './TelegramRuntimeState';
import { TelegramUpdateService } from './TelegramUpdateService';

export class TelegramChatActionsService {
  private state: TelegramRuntimeState;
  private updateService: TelegramUpdateService;

  constructor(state: TelegramRuntimeState, updateService: TelegramUpdateService) {
    this.state = state;
    this.updateService = updateService;
  }

  async openChat(chatId: number): Promise<Chat | undefined> {
    const result = await telegramBridge.openChat(chatId);
    return this.updateService.cacheSearchResult(result);
  }

  async markChatRead(chatId: number): Promise<ChatActionResult> {
    const result = await telegramBridge.markChatRead(chatId);
    const context = this.state.getContext();
    if (context) {
      const chat = context.chatDataSource.get(chatId.toString());
      if (chat) {
        chat.unreadCount = 0;
        context.chatDataSource.upsert(chat);
      }
    }
    return result;
  }

  async setPinned(chatId: number, pinned: boolean): Promise<ChatActionResult> {
    const result = await telegramBridge.setChatPinned(chatId, pinned);
    this.applyPinned(chatId, pinned);
    return result;
  }

  async setMuted(chatId: number, muted: boolean): Promise<ChatActionResult> {
    const result = await telegramBridge.setChatMuted(chatId, muted);
    this.applyMuted(chatId, muted);
    return result;
  }

  async setArchived(chatId: number, archived: boolean): Promise<ChatActionResult> {
    const result = await telegramBridge.setChatArchived(chatId, archived);
    this.applyArchived(chatId, archived);
    return result;
  }

  private applyPinned(chatId: number, pinned: boolean): void {
    const chat = this.getChat(chatId);
    if (!chat) {
      return;
    }
    chat.pinned = pinned;
    this.upsert(chat);
  }

  private applyMuted(chatId: number, muted: boolean): void {
    const chat = this.getChat(chatId);
    if (!chat) {
      return;
    }
    chat.muted = muted;
    this.upsert(chat);
  }

  private applyArchived(chatId: number, archived: boolean): void {
    const chat = this.getChat(chatId);
    if (!chat) {
      return;
    }
    chat.archived = archived;
    this.upsert(chat);
  }

  private getChat(chatId: number): Chat | undefined {
    const context = this.state.getContext();
    if (!context) {
      return undefined;
    }
    return context.chatDataSource.get(chatId.toString());
  }

  private upsert(chat: Chat): void {
    const context = this.state.getContext();
    if (context) {
      context.chatDataSource.upsert(chat);
    }
  }
}
