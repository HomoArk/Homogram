import { common } from '@kit.AbilityKit';
import { Logger } from '@ohos/base';
import { telegramBridge, LoginState, NativeSeenChat } from '../bridge/TelegramBridge';
import { autoRegisterPushIfNeeded } from '../utils';
import { telegramSyncService } from './TelegramSyncService';

class SessionService {
  async isLoggedIn(): Promise<boolean> {
    const authorized = await telegramBridge.isLoggedIn();
    Logger.info('SessionService isLoggedIn: ' + authorized);
    return authorized;
  }

  async login(phoneNumber: string): Promise<LoginState> {
    return telegramBridge.login(phoneNumber);
  }

  async verifyCode(code: string): Promise<LoginState> {
    return telegramBridge.verifyCode(code);
  }

  async password(password: string): Promise<LoginState> {
    return telegramBridge.password(password);
  }

  async signOut(): Promise<boolean> {
    await telegramSyncService.stop();
    return telegramBridge.signOut();
  }

  async getMe(): Promise<NativeSeenChat> {
    return telegramBridge.getMe();
  }

  async onAuthorized(context: common.UIAbilityContext): Promise<NativeSeenChat> {
    Logger.info('SessionService onAuthorized: refresh chats');
    await telegramSyncService.refreshChats();
    Logger.info('SessionService onAuthorized: get self profile');
    const me = await this.getMe();
    await autoRegisterPushIfNeeded(context);
    await telegramSyncService.start();
    return me;
  }

  async onForeground(context: common.UIAbilityContext): Promise<boolean> {
    const authorized = await telegramSyncService.reconnectAndStart();
    if (authorized) {
      await autoRegisterPushIfNeeded(context);
    }
    return authorized;
  }
}

export const sessionService = new SessionService();
