import { common } from '@kit.AbilityKit';
import { pushService } from '@kit.PushKit';
import { telegramBridge } from '../bridge/TelegramBridge';
import { sessionService } from './SessionService';
import { isTelegramFixtureMode } from '../testing/TestMode';

class AppLifecycleService {
  async registerDevice(): Promise<void> {
    if (isTelegramFixtureMode()) {
      await telegramBridge.registerDevice('fixture-device-token');
      return;
    }
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
