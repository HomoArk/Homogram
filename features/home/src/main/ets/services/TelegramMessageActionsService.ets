import { ChatActionResult, NativeDeletedMessages, telegramBridge } from '../bridge/TelegramBridge';
import { TelegramUpdateService } from './TelegramUpdateService';

class DeletedMessagesRecord implements NativeDeletedMessages {
  chatId?: number;
  messageIds: number[];

  constructor(chatId: number, messageIds: number[]) {
    this.chatId = chatId;
    this.messageIds = messageIds;
  }
}

export class TelegramMessageActionsService {
  private updateService: TelegramUpdateService;

  constructor(updateService: TelegramUpdateService) {
    this.updateService = updateService;
  }

  async deleteMessages(chatId: number, messageIds: number[]): Promise<ChatActionResult> {
    const result = await telegramBridge.deleteMessages(chatId, messageIds);
    await this.updateService.applyDeletedMessages(new DeletedMessagesRecord(chatId, messageIds));
    return result;
  }
}
