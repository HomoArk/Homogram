import { Logger } from '@ohos/base';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { registerPush as nativeRegisterPush, unregisterPush as nativeUnregisterPush } from '../api';

export const PUSH_NICKNAME_KEY = 'push_nickname';

export const PUSH_LAST_REGISTER_TIME_KEY = 'push_last_register_time';

export const PUSH_REGISTER_INTERVAL = 24 * 60 * 60 * 1000; // 24 hours

export const CHUCKFANG_APP_ID = 'com.chuckfang.meow';

interface WebPushKey {
  p256dh: string;
  auth: string
};

// Web Push key configuration.
const WEB_PUSH_KEYS: WebPushKey = {
  p256dh: 'BIo_GhL2d7bnPfWcXF-7ApQsa11I6jYZ6xRIBXCQzoEVJ3xRN56sreC9FDbeLMaTW9ubQrKEWeFuu-rUHz8PqCY',
  auth: '6vUzFvnXAa9_PeOK8s-5iQ'
};

/**
 * Generate the push token.
 */
function generatePushEndpoint(nickname: string, fake = false): string {
  return JSON.stringify({
    endpoint: `https://gramonotify.dokodemodoor.workers.dev/tg/${fake ? 'fake' : "webpush"}/${encodeURIComponent(nickname)}`,
    keys: WEB_PUSH_KEYS
  });
}

/**
 * Push service manager.
 */
export class PushService {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  /**
   * Load the saved nickname.
   */
  async loadNickname(): Promise<string> {
    try {
      const dataPreferences = await preferences.getPreferences(this.context, 'push_settings');
      return await dataPreferences.get(PUSH_NICKNAME_KEY, '') as string;
    } catch (e) {
      Logger.error('PushService loadNickname error: ' + JSON.stringify(e));
      return '';
    }
  }

  /**
   * Save the nickname.
   */
  async saveNickname(nickname: string): Promise<boolean> {
    try {
      const dataPreferences = await preferences.getPreferences(this.context, 'push_settings');
      await dataPreferences.put(PUSH_NICKNAME_KEY, nickname);
      await dataPreferences.flush();
      return true;
    } catch (e) {
      Logger.error('PushService saveNickname error: ' + JSON.stringify(e));
    }
    return false;
  }

  /**
   * Save the last registration time.
   */
  async saveLastRegisterTime(): Promise<boolean> {
    try {
      const dataPreferences = await preferences.getPreferences(this.context, 'push_settings');
      await dataPreferences.put(PUSH_LAST_REGISTER_TIME_KEY, Date.now());
      await dataPreferences.flush();
      return true;
    } catch (e) {
      Logger.error('PushService saveLastRegisterTime error: ' + JSON.stringify(e));
    }
    return false;
  }

  /**
   * Get the last registration time.
   */
  async getLastRegisterTime(): Promise<number> {
    try {
      const dataPreferences = await preferences.getPreferences(this.context, 'push_settings');
      return await dataPreferences.get(PUSH_LAST_REGISTER_TIME_KEY, 0) as number;
    } catch (e) {
      Logger.error('PushService getLastRegisterTime error: ' + JSON.stringify(e));
      return 0;
    }
  }

  /**
   * Check whether push registration needs to be refreshed.
   */
  async shouldRegisterPush(): Promise<boolean> {
    try {
      const lastRegisterTime = await this.getLastRegisterTime();
      const now = Date.now();

      if (lastRegisterTime === 0) {
        Logger.debug('shouldRegisterPush: Never registered before');
        return true;
      }

      const elapsed = now - lastRegisterTime;
      const shouldRegister = elapsed >= PUSH_REGISTER_INTERVAL;

      Logger.debug(`shouldRegisterPush: elapsed=${elapsed}ms, shouldRegister=${shouldRegister}`);
      return shouldRegister;
    } catch (e) {
      Logger.error(`shouldRegisterPush error: ${e}`);
      return false;
    }
  }

  /**
   * Register push notifications.
   */
  async registerPush(nickname: string): Promise<string> {
    const token = generatePushEndpoint(nickname);

    try {
      const result = await nativeRegisterPush(10, token);
      await this.saveNickname(nickname);
      await this.saveLastRegisterTime();

      Logger.debug(`PushService registered push, result: ${result}`);
      return result;
    } catch (e) {
      Logger.error('PushService registerPush error: ' + JSON.stringify(e));
    }
    return "";
  }

  /**
   * Unregister push notifications.
   */
  async unregisterPush(nickname: string): Promise<string> {
    let token = generatePushEndpoint(nickname);

    try {
      const result = await nativeUnregisterPush(10, token);
      Logger.warn(`PushService unregisterPush: ` + JSON.stringify(result));
      token = generatePushEndpoint(nickname, true);
      await nativeRegisterPush(10, token);
      // Clear saved data.
      const dataPreferences = await preferences.getPreferences(this.context, 'push_settings');
      await dataPreferences.delete(PUSH_NICKNAME_KEY);
      await dataPreferences.delete(PUSH_LAST_REGISTER_TIME_KEY);
      await dataPreferences.flush();

      Logger.debug(`PushService unregistered push, result: ${result}`);
      return result;
    } catch (e) {
      Logger.error('PushService unregisterPush error: ' + JSON.stringify(e));
    }
    return "";
  }

  /**
   * Test push notifications.
   */
  async testPush(nickname: string): Promise<string | false> {
    const testUrl = `https://gramonotify.dokodemodoor.workers.dev/tg/notify`;

    try {
      Logger.debug(`PushService testPush: Sending test notification to ${nickname}`);

      const httpRequest = http.createHttp();
      const response = await httpRequest.request(testUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
        },
        extraData: JSON.stringify({
          nick: nickname,
          title: 'Telegram 测试',
          msg: '这是一条测试推送消息',
          url: 'tg://launchohos',
        })
      });

      Logger.debug(`PushService testPush response: ${JSON.stringify(response.result)}`);

      const resultText = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      const fullResponse = `状态码: ${response.responseCode}\n响应: ${resultText}`;

      Logger.info(`PushService test push result: ${fullResponse}`);
      httpRequest.destroy();

      return fullResponse;
    } catch (e) {
      Logger.error(`PushService testPush error: ${JSON.stringify(e)}`);
    }
    return false;
  }

  /**
   * Automatically register push notifications if needed.
   */
  async autoRegisterIfNeeded(): Promise<void> {
    try {
      const nickname = await this.loadNickname();

      if (!nickname) {
        Logger.debug('PushService autoRegisterIfNeeded: No nickname saved, skipping auto registration');
        return;
      }

      const shouldRegister = await this.shouldRegisterPush();

      if (!shouldRegister) {
        Logger.debug('PushService autoRegisterIfNeeded: Registration not needed yet');
        return;
      }

      Logger.info(`PushService autoRegisterIfNeeded: Registering push for ${nickname}`);
      await this.registerPush(nickname);
      Logger.info('PushService autoRegisterIfNeeded: Push registered successfully');
    } catch (e) {
      Logger.error(`PushService autoRegisterIfNeeded error: ${e}`);
    }
  }
}



