import { telegramBridge, NativeSeenChat } from '../bridge/TelegramBridge';
import { SeenChat } from '../entities/SeenChat';
import { TelegramRuntimeState } from './TelegramRuntimeState';

export class TelegramContactsService {
  private state: TelegramRuntimeState;

  constructor(state: TelegramRuntimeState) {
    this.state = state;
  }

  async loadContacts(): Promise<SeenChat[]> {
    const nativeContacts: NativeSeenChat[] = await telegramBridge.getContacts();
    const contacts: SeenChat[] = [];
    const context = this.state.getContext();
    for (let i = 0; i < nativeContacts.length; i++) {
      const seenChat = SeenChat.fromNative(nativeContacts[i]);
      contacts.push(seenChat);
      if (context) {
        context.seenChatsMap.set(seenChat.chatId.toString(), seenChat);
      }
    }
    return contacts;
  }
}
