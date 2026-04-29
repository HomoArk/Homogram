import { common } from '@kit.AbilityKit';
import { pushService } from '@kit.PushKit';
import { telegramBridge } from '../bridge/TelegramBridge';
import { sessionService } from './SessionService';

class AppLifecycleService {
  async registerDevice(): Promise<void> {
    const token = await pushService.getToken();
    await telegramBridge.registerDevice(token);
  }

  async onForeground(context: common.UIAbilityContext): Promise<boolean> {
    return sessionService.onForeground(context);
  }

  async onBackground(): Promise<void> {
    await telegramBridge.stopSync();
  }
}

export const appLifecycleService = new AppLifecycleService();
