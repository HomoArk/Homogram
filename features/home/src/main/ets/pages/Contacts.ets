import { BaseConstants, BreakpointConstants, Logger } from '@ohos/base';
import { deviceInfo } from '@kit.BasicServicesKit';
import { curves, promptAction } from '@kit.ArkUI';
import { SeenChat } from '../entities/SeenChat';
import { telegramSyncService } from '../api';
import { ContactsItem } from '../views/Contacts/ContactsItem';

@Component
export struct Contacts {
  @StorageProp('currentBreakpoint') currentBreakpoint: string = BreakpointConstants.BREAKPOINT_SM;
  @Consume('pageInfo') pageInfo: NavPathStack;
  @Consume currentChatId: string;
  @State contacts: SeenChat[] = [];
  @State loading: boolean = false;

  @Builder
  Header() {
    Flex({ alignItems: ItemAlign.Center, justifyContent: FlexAlign.SpaceBetween }) {
      Text($r('app.string.contacts'))
        .fontWeight(800)
        .fontSize(BaseConstants.FONT_SIZE_TWENTY_FOUR)
        .fontFamily('HarmonyOS Sans Condensed')
      if (this.loading) {
        LoadingProgress()
          .width(24)
          .height(24)
          .margin({ right: $r('app.float.phone_icon_right') })
      } else {
        Button() {
          Image($r('app.media.ic_public_refresh'))
            .width(24)
            .height(24)
        }
        .width(36)
        .height(36)
        .backgroundColor(Color.Transparent)
        .margin({ right: $r('app.float.phone_icon_right') })
        .onClick(() => {
          this.loadContacts(true);
        })
      }
    }
    .expandSafeArea([SafeAreaType.SYSTEM])
    .width(BaseConstants.FULL_WIDTH)
    .backgroundBlurStyle(BlurStyle.Thin)
    .backgroundColor(Color.Transparent)
    .padding({
      left: $r('app.float.phone_icon_left'),
      top: $r('app.float.device_padding_top'),
      bottom: $r('app.float.top_nav_pad_btm'),
    })
  }

  build(): void {
    Stack({ alignContent: Alignment.Top }) {
      this.Header()
      List() {
        ListItem() {
          Row()
            .height(102)
            .margin({ bottom: -20 })
            .width(BaseConstants.FULL_WIDTH)
        }

        ForEach(this.contacts, (contact: SeenChat) => {
          ListItem() {
            ContactsItem({ contact: contact })
              .onClick(() => {
                this.openContact(contact);
              })
          }
        }, (contact: SeenChat) => contact.chatId.toString())

        ListItem() {
          Row()
            .height((this.currentBreakpoint === BreakpointConstants.BREAKPOINT_LG ||
              this.currentBreakpoint === BreakpointConstants.BREAKPOINT_XL) ? BaseConstants.FULL_PERCENT :
              (deviceInfo.deviceType === BaseConstants.DEVICE_TYPES[0] ? $r('app.float.tab_size_lg') :
              $r('app.float.tab_size')))
            .width(BaseConstants.FULL_WIDTH)
        }
      }
      .height(BaseConstants.FULL_PERCENT)
      .width(BaseConstants.FULL_WIDTH)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .animation({ curve: curves.springMotion(0.6, 0.8) })
    }
    .expandSafeArea([SafeAreaType.SYSTEM])
  }

  aboutToAppear(): void {
    this.loadContacts(false);
  }

  private async loadContacts(force: boolean): Promise<void> {
    if (this.loading || (!force && this.contacts.length > 0)) {
      return;
    }
    this.loading = true;
    try {
      this.contacts = await telegramSyncService.loadContacts();
    } catch (error) {
      Logger.error('Contacts load failed: ' + JSON.stringify(error));
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.load_failed'),
        duration: 2000,
        showMode: promptAction.ToastShowMode.DEFAULT,
        bottom: 100
      });
    } finally {
      this.loading = false;
    }
  }

  private async openContact(contact: SeenChat): Promise<void> {
    try {
      await telegramSyncService.openChat(contact.chatId);
      this.currentChatId = contact.chatId.toString();
      const isSplitMode: boolean = this.currentBreakpoint !== BreakpointConstants.BREAKPOINT_SM;
      const hasChatDetail: boolean = this.pageInfo.size() >= 1 &&
        this.pageInfo.getParamByName('ChatDetail')?.length > 0;
      if (isSplitMode && hasChatDetail) {
        this.pageInfo.replacePath({ name: 'ChatDetail' });
      } else {
        this.pageInfo.pushPath({ name: 'ChatDetail' });
      }
    } catch (error) {
      Logger.error('Contacts open failed: ' + JSON.stringify(error));
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.load_failed'),
        duration: 2000,
        showMode: promptAction.ToastShowMode.DEFAULT,
        bottom: 100
      });
    }
  }
}
