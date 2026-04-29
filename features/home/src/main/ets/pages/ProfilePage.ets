import { NativeSeenChat } from "../api";
import { Profile } from "../views/Profile"
import { ComposeListItem, IconType } from "@kit.ArkUI";
import { PushSettings } from './PushSettings';
import { BaseConstants } from '@ohos/base';

@ComponentV2
export struct ProfilePage {
  @Local pageInfo: NavPathStack = new NavPathStack();
  @Param user: NativeSeenChat | null = null;
  @Param chatId: string = '';
  @Param title: Resource | string = 'Profile';
  @Param device: string | false = false;
  @Local showPushSettings: boolean = false;
  pathStack: NavPathStack | undefined = undefined;
  pageParam: string = '';

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          if (this.user) {
            // 鏄剧ず鐢ㄦ埛璧勬枡
            Profile({
              avatar: this.user.photoThumb ? this.getAvatarFromBytes(this.user.photoThumb) : "",
              name: this.user.fullName,
              bio: this.user.bio ?? "",
            })

            // 璇︾粏淇℃伅鍒楄〃
            this.showList(this.user)
            Row().height(48)
          } else {
            // 鍔犺浇涓?- 鏄剧ず skeleton
            Column({ space: 16 }) {
              LoadingProgress()
                .size({
                  width: 60,
                  height: 60
                })
              Text($r('app.string.profile_loading_chat'))
                .fontSize(BaseConstants.FONT_SIZE_SIXTEEN)
                .fontColor($r('sys.color.font_secondary'))
            }
            .alignItems(HorizontalAlign.Center)
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .height('100%')
          }
        }
        .width('100%')
        .padding(16)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Auto)
    }
    .bindSheet($$this.showPushSettings, this.pushSettingsSheet(), {
      height: '90%',
      showClose: true,
      title: { title: $r('app.string.push_settings') },
      onDisappear: () => {
        this.showPushSettings = false;
      }
    })
    .title(this.user?.fullName ?? this.title, { barStyle: BarStyle.STACK })
    .onAppear(() => {
      if (!this.user) {

      }
    })
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      this.pageParam = context.pathInfo.param as string;
    })
  }

  @Builder
  showList(user: NativeSeenChat) {
    List() {
      // 鐢ㄦ埛鍚?
      if (user.username) {
        ListItem() {
          ComposeListItem({
            contentItem: {
              iconStyle: IconType.SYSTEM_ICON,
              icon: $r('sys.symbol.edit_colour'),
              primaryText: $r('app.string.profile_username'),
              secondaryText: `@${user.username}`
            }
          })
        }
      }

      // 鐢佃瘽鍙风爜
      if (user.phone) {
        ListItem() {
          ComposeListItem({
            contentItem: {
              iconStyle: IconType.SYSTEM_ICON,
              icon: $r('sys.media.ohos_ic_public_phone'),
              primaryText: $r('app.string.profile_phone'),
              secondaryText: user.phone
            }
          })
        }
      }

      // 鍚嶅瓧
      ListItem() {
        ComposeListItem({
          contentItem: {
            iconStyle: IconType.SYSTEM_ICON,
            icon: $r('sys.media.ohos_ic_public_edit'),
            primaryText: $r('app.string.profile_first_name'),
            secondaryText: user.firstName
          }
        })
      }

      // 濮撴皬
      if (user.lastName) {
        ListItem() {
          ComposeListItem({
            contentItem: {
              iconStyle: IconType.SYSTEM_ICON,
              icon: $r('sys.media.ohos_ic_public_edit'),
              primaryText: $r('app.string.profile_last_name'),
              secondaryText: user.lastName
            }
          })
        }
      }

      // 鐢熸棩
      if (user.dateOfBirth) {
        ListItem() {
          ComposeListItem({
            contentItem: {
              iconStyle: IconType.SYSTEM_ICON,
              icon: $r('sys.symbol.calendar'),
              primaryText: $r('app.string.profile_birthday'),
              secondaryText: this.formatDate(user.dateOfBirth)
            }
          })
        }
      }

      // 鑱旂郴浜虹姸鎬?
      ListItem() {
        ComposeListItem({
          contentItem: {
            iconStyle: IconType.SYSTEM_ICON,
            icon: $r('sys.symbol.person'),
            primaryText: $r('app.string.profile_contact'),
            secondaryText: user.isContact ? $r('app.string.profile_yes') : $r('app.string.profile_no')
          }
        })
      }

      // 浜掔浉鑱旂郴浜?
      if (user.isContact) {
        ListItem() {
          ComposeListItem({
            contentItem: {
              iconStyle: IconType.SYSTEM_ICON,
              icon: $r('sys.symbol.person_2'),
              primaryText: $r('app.string.profile_mutual_contact'),
              secondaryText: user.isMutualContact ? $r('app.string.profile_yes') : $r('app.string.profile_no')
            }
          })
        }
      }

      // 璁哄潧鏍囪瘑
      if (user.forum) {
        ListItem() {
          ComposeListItem({
            contentItem: {
              primaryText: $r('app.string.profile_forum'),
              secondaryText: $r('app.string.profile_yes')
            }
          })
        }
      }

      // Chat ID (璋冭瘯鐢?
      ListItem() {
        ComposeListItem({
          contentItem: {
            iconStyle: IconType.SYSTEM_ICON,
            icon: $r('sys.symbol.eye'),
            primaryText: 'Chat ID',
            secondaryText: user.chatId.toString()
          }
        })
      }

      // Chat 绫诲瀷
      ListItem() {
        ComposeListItem({
          contentItem: {
            iconStyle: IconType.SYSTEM_ICON,
            icon: $r('sys.media.ohos_ic_public_more'),
            primaryText: $r('app.string.profile_type'),
            secondaryText: this.getChatTypeString(user.chatType)
          }
        })
      }

      if (this.device) {
        ListItem() {
          ComposeListItem({
            contentItem: {
              iconStyle: IconType.SYSTEM_ICON,
              icon: $r('sys.symbol.paperplane'),
              primaryText: $r('app.string.profile_device'),
              secondaryText: this.device,
            }
          })
        }

        // 鎺ㄩ€佽缃叆鍙?
        ListItem() {
          Button({ type: ButtonType.Normal }) {
            Row() {
              SymbolGlyph($r('sys.symbol.bell'))
                .fontSize($r('sys.float.ohos_id_text_size_headline3'))
                .fontColor([$r('sys.color.ohos_id_color_emphasize')])
              Column({ space: 4 }) {
                Text($r('app.string.push_settings'))
                  .fontSize(BaseConstants.FONT_SIZE_SIXTEEN)
                  .fontWeight(FontWeight.Medium)
                  .alignSelf(ItemAlign.Start)
                Text($r('app.string.push_settings_desc'))
                  .fontSize(BaseConstants.FONT_SIZE_FOURTEEN)
                  .fontColor($r('sys.color.font_secondary'))
                  .alignSelf(ItemAlign.Start)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .margin({ left: 12 })
            }
            .width('100%')
            .padding(12)
          }
          .width('100%')
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            console.log('Push Settings button clicked');
            this.showPushSettings = true;
          })
        }
      }
    }
    .width('100%')
    .padding({ top: 4 })
  }

  @Builder
  pushSettingsSheet() {
    Column() {
      PushSettings()
    }
    .width('100%')
    .height('100%')
  }

  private getAvatarFromBytes(bytes: ArrayBuffer | number[]): string {
    // TODO: 灏嗗瓧鑺傛暟缁勮浆鎹负 base64 鎴栧浘鐗?URI
    // 杩欏彇鍐充簬浣犵殑鍥剧墖澶勭悊鏂瑰紡
    return "";
  }

  private formatDate(timestamp: number): string {
    const date = new Date(timestamp * 1000);
    return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate()
      .toString()
      .padStart(2, '0')}`;
  }

  private getChatTypeString(chatType: number): ResourceStr {
    // 鏍规嵁 ChatType 鏋氫妇鍊艰皟鏁?
    switch (chatType) {
      case 0:
        return $r('app.string.profile_chat_type_user');
      case 1:
        return $r('app.string.profile_chat_type_group');
      case 2:
        return $r('app.string.profile_chat_type_channel');
      default:
        return $r('app.string.profile_chat_type_unknown');
    }
  }
}


