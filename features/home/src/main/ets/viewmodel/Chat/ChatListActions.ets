import { Logger } from '@ohos/base';
import { PromptAction, promptAction } from '@kit.ArkUI';
import { Chat } from '../../entities/Chat';
import { telegramSyncService } from '../../services/TelegramSyncService';

export class ChatListActions {
  async setPinned(chat: Chat, pinned: boolean, prompt: PromptAction): Promise<void> {
    try {
      await telegramSyncService.setChatPinned(chat.chatId, pinned);
    } catch (error) {
      this.showActionError(error as Error, prompt);
    }
  }

  async setMuted(chat: Chat, muted: boolean, prompt: PromptAction): Promise<void> {
    try {
      await telegramSyncService.setChatMuted(chat.chatId, muted);
    } catch (error) {
      this.showActionError(error as Error, prompt);
    }
  }

  async setArchived(chat: Chat, archived: boolean, prompt: PromptAction): Promise<void> {
    try {
      await telegramSyncService.setChatArchived(chat.chatId, archived);
    } catch (error) {
      this.showActionError(error as Error, prompt);
    }
  }

  async markRead(chat: Chat, prompt: PromptAction): Promise<void> {
    try {
      await telegramSyncService.markChatRead(chat.chatId);
    } catch (error) {
      this.showActionError(error as Error, prompt);
    }
  }

  private showActionError(error: Error, prompt: PromptAction): void {
    Logger.error('Chat action failed: ' + JSON.stringify(error));
    prompt.showToast({
      message: $r('app.string.load_failed'),
      duration: 2000,
      showMode: promptAction.ToastShowMode.DEFAULT,
      bottom: 100
    });
  }
}
