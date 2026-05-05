/*
 * Copyright (c) 2022 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { display, window } from '@kit.ArkUI';
import { AsyncCallback, BusinessError, commonEventManager, emitter } from '@kit.BasicServicesKit';
import { BaseConstants, BreakpointConstants, Logger, WindowUtil } from '@ohos/base/Index';
import { deviceInfo } from '@kit.BasicServicesKit';
import { appLifecycleService, applyTelegramFixtureModeFromUri, EventConstants, isTelegramFixtureMode } from '@ohos/home';
import { ImageKnife } from '@ohos/imageknife';

export default class EntryAbility extends UIAbility {
  private windowObj?: window.Window;
  private isFirstOnForeground: boolean = true;
  private subscriber: commonEventManager.CommonEventSubscriber | null = null;
  private subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
    events: [
      commonEventManager.Support.COMMON_EVENT_MY_PACKAGE_UNSUSPENDED,
      commonEventManager.Support.COMMON_EVENT_MY_PACKAGE_SUSPENDED,
      commonEventManager.Support.COMMON_EVENT_PACKAGES_SUSPENDED,
    ]
  };

  onCreate(want?: Want, launchParam?: AbilityConstant.LaunchParam): void {
    if (want?.uri) {
      Logger.info(`Deep Linking onCreate - URI: ${want.uri}`);
    }
    this.applyTestModeFromWant(want);

    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    ImageKnife.getInstance().initFileCache(this.context, 256, 256 * 1024 * 1024);

    appLifecycleService.registerDevice().catch((err: Error) => {
      Logger.error('Failed to register device. Cause: ' + err.name + '-' + err.message);
    });

    try {
      commonEventManager.createSubscriber(this.subscribeInfo, this.createCB);
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      Logger.error(`commonEvent createSubscriber failed, code is ${err.code}, message is ${err.message}`);
    }

    hilog.info(0x0000, 'EntryAbility', '%{public}s', 'Ability onCreate');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'EntryAbility', '%{public}s', 'Ability onNewWant');
    if (want?.uri) {
      Logger.info(`Deep Linking onNewWant - URI: ${want.uri}`);
    }
    this.applyTestModeFromWant(want);
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    hilog.info(0x0000, 'EntryAbility', '%{public}s', 'Ability onWindowStageCreate');
    windowStage.getMainWindow((err: BusinessError<void>, data) => {
      if (err.code) {
        hilog.info(0x0000, 'EntryAbility', '%{public}s', 'getMainWindow failed');
        return;
      }
      this.windowObj = data;
      this.applyTranslucentNavigationBar(data);
      this.applyFixtureWindowPolicy(data);
      const windowWidth = this.windowObj.getWindowProperties().windowRect.width;
      const windowHeight = this.windowObj.getWindowProperties().windowRect.height;
      this.updateWidthBp(windowWidth);
      this.updateHeightBp(windowWidth, windowHeight);
      this.windowObj.on('windowSizeChange', (windowSize: window.Size) => {
        this.updateWidthBp(windowSize.width);
        this.updateHeightBp(windowSize.width, windowSize.height);
      })
      if (deviceInfo.deviceType !== BaseConstants.DEVICE_2IN1) {
        // reserved for future device-specific adjustments
      }
    })

    const windowUtil = WindowUtil.getInstance();
    if (windowUtil !== undefined) {
      windowUtil.setWindowStage(windowStage);
      windowUtil.setMainWindowPortrait();
    }

    windowStage.loadContent('pages/Index', (err, data) => {
      if (err.code) {
        hilog.error(0x0000, 'EntryAbility', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      this.updateNavigationIndicatorHeight();
      this.updateTopSystemAvoidHeight();

      this.windowObj?.on('avoidAreaChange', (areaData) => {
        if (areaData.type === window.AvoidAreaType.TYPE_SYSTEM) {
          AppStorage.setOrCreate('topRectHeight', this.pxToVp(areaData.area.topRect.height));
        } else if (areaData.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          AppStorage.setOrCreate('bottomRectHeight', this.pxToVp(areaData.area.bottomRect.height));
        }
      });
      hilog.info(0x0000, 'EntryAbility', 'Succeeded in loading the content. Data: %{public}s', JSON.stringify(data) ?? '');
    });
  }

  async onForeground(): Promise<void> {
    hilog.info(0x0000, 'EntryAbility', '%{public}s', 'Ability onForeground');
    if (!this.isFirstOnForeground) {
      emitter.emit(EventConstants.onForegroundEvent);
    }
  }

  onBackground(): void {
    hilog.info(0x0000, 'EntryAbility', '%{public}s', 'Ability onBackground');
    this.isFirstOnForeground = false;
    appLifecycleService.onBackground().catch((err: Error) => {
      Logger.error('onBackground failed. Cause: ' + err.name + '-' + err.message)
    })
  }

  private subscribeCB: AsyncCallback<commonEventManager.CommonEventData, void> =
    (err: BusinessError, data: commonEventManager.CommonEventData) => {
      if (err) {
        Logger.error(`commonEvent subscribe failed, code is ${err.code}, message is ${err.message}`);
      } else {
        Logger.info('commonEvent subscribe success ' + JSON.stringify(data));
      }
    }

  private createCB: AsyncCallback<commonEventManager.CommonEventSubscriber, void> =
    (err: BusinessError, commonEventSubscriber: commonEventManager.CommonEventSubscriber) => {
      if (!err) {
        this.subscriber = commonEventSubscriber;
        try {
          commonEventManager.subscribe(this.subscriber, this.subscribeCB);
        } catch (error) {
          const eventErr: BusinessError = error as BusinessError;
          Logger.error(`commonEvent subscribe failed, code is ${eventErr.code}, message is ${eventErr.message}`);
        }
      } else {
        Logger.error(`commonEvent createSubscriber failed, code is ${err.code}, message is ${err.message}`);
      }
    }

  private updateWidthBp(windowWidth: number): void {
    const windowWidthVp = windowWidth / display.getDefaultDisplaySync().densityPixels;
    let widthBp: string = '';
    if (windowWidthVp < 320) {
      widthBp = BreakpointConstants.BREAKPOINT_XS;
    } else if (windowWidthVp < 600) {
      widthBp = BreakpointConstants.BREAKPOINT_SM;
    } else if (windowWidthVp < 840) {
      widthBp = BreakpointConstants.BREAKPOINT_MD;
    } else if (windowWidthVp < 1440) {
      widthBp = BreakpointConstants.BREAKPOINT_LG;
    } else {
      widthBp = BreakpointConstants.BREAKPOINT_XL;
    }
    AppStorage.setOrCreate('currentBreakpoint', widthBp);
  }

  private applyTestModeFromWant(want?: Want): void {
    if (applyTelegramFixtureModeFromUri(want?.uri)) {
      Logger.info('Telegram fixture mode enabled from launch URI');
    }
  }

  private applyTranslucentNavigationBar(windowObj: window.Window): void {
    windowObj.setWindowLayoutFullScreen(true).catch((err: BusinessError<void>) => {
      Logger.error('Failed to make window layout immersive. Cause: ' + JSON.stringify(err));
    });

    windowObj.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000',
      navigationBarContentColor: '#66000000',
      isNavigationBarLightIcon: false,
      enableNavigationBarAnimation: false
    }).catch((err: BusinessError<void>) => {
      Logger.error('Failed to set translucent navigation bar. Cause: ' + JSON.stringify(err));
    });

    windowObj.setSpecificSystemBarEnabled('navigationIndicator', true, false).catch((err: BusinessError<void>) => {
      Logger.error('Failed to enable navigation indicator. Cause: ' + JSON.stringify(err));
    });
  }

  private applyFixtureWindowPolicy(windowObj: window.Window): void {
    if (!isTelegramFixtureMode()) {
      return;
    }

    windowObj.setWindowKeepScreenOn(true).catch((err: BusinessError<void>) => {
      Logger.error('Failed to keep the UITest window awake. Cause: ' + JSON.stringify(err));
    });
  }

  private updateNavigationIndicatorHeight(): void {
    const avoidArea = this.windowObj?.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
    AppStorage.setOrCreate('bottomRectHeight', this.pxToVp(avoidArea?.bottomRect.height));
  }

  private updateTopSystemAvoidHeight(): void {
    const avoidArea = this.windowObj?.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    AppStorage.setOrCreate('topRectHeight', this.pxToVp(avoidArea?.topRect.height));
  }

  private pxToVp(value?: number): number {
    if (value === undefined) {
      return 0;
    }

    const density = display.getDefaultDisplaySync().densityPixels;
    return density > 0 ? value / density : value;
  }

  private updateHeightBp(windowWidth: number, windowHeight: number): void {
    const windowWidthVp = windowWidth / display.getDefaultDisplaySync().densityPixels;
    const windowHeightVp = windowHeight / display.getDefaultDisplaySync().densityPixels;
    const aspectRatio: number = windowHeightVp / windowWidthVp;
    let heightBp: string = '';
    if (aspectRatio < 0.8) {
      heightBp = BreakpointConstants.BREAKPOINT_SM;
    } else if (aspectRatio < 1.2) {
      heightBp = BreakpointConstants.BREAKPOINT_MD;
    } else {
      heightBp = BreakpointConstants.BREAKPOINT_LG;
    }
    AppStorage.setOrCreate('currentHeightBreakpoint', heightBp);
  }
}
