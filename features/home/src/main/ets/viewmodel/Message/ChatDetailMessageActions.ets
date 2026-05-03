import { Logger } from '@ohos/base';
import { PromptAction, promptAction } from '@kit.ArkUI';
import { telegramSyncService } from '../../services/TelegramSyncService';
import { MessageDataSource } from './MessageDataSource';

export class ChatDetailMessageActions {
  async deleteMessage(chatId: number, messageId: number, messageDataSource: MessageDataSource,
    prompt: PromptAction): Promise<number> {
    try {
      await telegramSyncService.deleteMessages(chatId, [messageId]);
      messageDataSource.deleteById(messageId);
    } catch (error) {
      Logger.error('ChatDetail delete message failed: ' + JSON.stringify(error));
      this.showActionError(prompt);
    }
    return messageDataSource.totalCount();
  }

  markChatRead(chatId: number): void {
    telegramSyncService.markChatRead(chatId)
      .catch((error: Error) => {
        Logger.error('ChatDetail mark read failed: ' + JSON.stringify(error));
      });
  }

  private showActionError(prompt: PromptAction): void {
    prompt.showToast({
      message: $r("app.string.load_failed"),
      duration: 2000,
      showMode: promptAction.ToastShowMode.DEFAULT,
      bottom: 100
    });
  }
}
