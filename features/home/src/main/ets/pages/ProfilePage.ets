import { NativeSeenChat } from "../api";
import { Profile } from "../views/Profile"
import { ComposeListItem, curves, IconType } from "@kit.ArkUI";
import { PushSettings } from './PushSettings';
import { BaseConstants } from '@ohos/base';
import {
  HeaderGradientBlur,
  HeaderIconButton,
  HeaderTitleCapsule,
  HeaderTextButton,
  HdsHeaderMetrics,
  navHeaderGradientHeight,
  rootHeaderTopPadding
} from '../views/common/HdsHeaderPrimitives';

@Component
struct ProfileRootTopBar {
  @StorageProp('topRectHeight') topRectHeight: number = 0;
  @Prop title: ResourceStr = 'Profile';
  @Prop isCollapsed: boolean = false;

  build() {
    Stack({ alignContent: Alignment.Top }) {
      HeaderGradientBlur({ materialHeight: this.getTopGradientHeight() })

      Row() {
        HeaderIconButton({
          icon: $r('sys.symbol.more'),
          buttonSize: HdsHeaderMetrics.ROOT_ACTION_SIZE,
          iconSize: 22,
        })

        Text(this.title)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(BaseConstants.LAYOUT_WEIGHT_ONE)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .opacity(this.isCollapsed ? 1 : 0)

        HeaderTextButton({ text: 'Edit' })
      }
      .width(BaseConstants.FULL_WIDTH)
      .alignItems(VerticalAlign.Center)
      .padding({
        left: HdsHeaderMetrics.ROOT_HORIZONTAL_PADDING,
        right: HdsHeaderMetrics.ROOT_HORIZONTAL_PADDING,
        top: rootHeaderTopPadding(this.topRectHeight),
        bottom: 8,
      })
    }
    .expandSafeArea([SafeAreaType.SYSTEM])
    .width(BaseConstants.FULL_WIDTH)
    .backgroundColor(Color.Transparent)
    .animation({ curve: curves.springMotion(0.6, 0.8) })
  }

  private getTopGradientHeight(): number {
    return rootHeaderTopPadding(this.topRectHeight) + HdsHeaderMetrics.ROOT_ACTION_SIZE + 16;
  }
}

@Component
struct ProfileRootHeader {
  @StorageProp('topRectHeight') topRectHeight: number = 0;
  @Prop title: ResourceStr = 'Profile';
  @Prop subtitle: string = '';
  @Prop isPhotoExpanded: boolean = false;
  @Prop isCollapsed: boolean = false;

  build() {
    Column() {
      if (this.isPhotoExpanded) {
        Stack({ alignContent: Alignment.BottomStart }) {
          Image($r('app.media.avatar1'))
            .width(BaseConstants.FULL_WIDTH)
            .height(360)
            .objectFit(ImageFit.Cover)
            .geometryTransition('homogram-me-profile-photo')
            .transition(TransitionEffect.OPACITY.animation({ curve: curves.springMotion(0.7, 0.85) }))

          Column() {
            Text(this.title)
              .fontWeight(FontWeight.Bold)
              .fontSize(22)
              .lineHeight(30)
              .fontColor(Color.White)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if (this.subtitle) {
              Text(this.subtitle)
                .fontSize(15)
                .fontColor('#DDFFFFFF')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 2 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .width(BaseConstants.FULL_WIDTH)
          .padding({
            left: HdsHeaderMetrics.ROOT_HORIZONTAL_PADDING,
            right: HdsHeaderMetrics.ROOT_HORIZONTAL_PADDING,
            bottom: 28,
          })
        }
        .height(360)
        .width(BaseConstants.FULL_WIDTH)
        .backgroundColor('#222222')
      } else {
        Image($r('app.media.avatar1'))
          .width(64)
          .height(64)
          .borderRadius(32)
          .backgroundColor($r('app.color.background_color_grey_two'))
          .geometryTransition('homogram-me-profile-photo')
          .transition(TransitionEffect.OPACITY.animation({ curve: curves.springMotion(0.7, 0.85) }))
          .opacity(this.isCollapsed ? 0 : 1)

        Text(this.title)
          .fontWeight(FontWeight.Bold)
          .fontSize(21)
          .lineHeight(28)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textAlign(TextAlign.Center)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 12 })
          .opacity(this.isCollapsed ? 0 : 1)

        if (this.subtitle) {
          Text(this.subtitle)
            .fontSize(15)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textAlign(TextAlign.Center)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
            .opacity(this.isCollapsed ? 0 : 1)
        }
      }
    }
    .expandSafeArea([SafeAreaType.SYSTEM])
    .alignItems(HorizontalAlign.Center)
    .width(BaseConstants.FULL_WIDTH)
    .backgroundColor(Color.Transparent)
    .padding({
      left: this.isPhotoExpanded ? 0 : HdsHeaderMetrics.ROOT_HORIZONTAL_PADDING,
      right: this.isPhotoExpanded ? 0 : HdsHeaderMetrics.ROOT_HORIZONTAL_PADDING,
      top: this.isPhotoExpanded ? 0 : rootHeaderTopPadding(this.topRectHeight) +
      HdsHeaderMetrics.ROOT_ACTION_SIZE + 18,
      bottom: HdsHeaderMetrics.ROOT_BOTTOM_PADDING,
    })
    .animation({ curve: curves.springMotion(0.7, 0.85) })
  }
}

@ComponentV2
export struct ProfilePage {
  @Local pageInfo: NavPathStack = new NavPathStack();
  @Param user: NativeSeenChat | null = null;
  @Param chatId: string = '';
  @Param title: ResourceStr = 'Profile';
  @Param device: string | false = false;
  @Param isRootTab: boolean = false;
  @Local showPushSettings: boolean = false;
  @Local isRootHeaderCollapsed: boolean = false;
  @Local isProfilePhotoExpanded: boolean = false;
  pathStack: NavPathStack | undefined = undefined;
  pageParam: string = '';
  private rootScroller: Scroller = new Scroller();
  private rootScrollOffset: number = 0;
  private hasRootScrolledPastHeader: boolean = false;
  private rootPullStartY: number = 0;

  @Builder
  TitleBuilder() {
    Stack({ alignContent: Alignment.Top }) {
      HeaderGradientBlur({ materialHeight: navHeaderGradientHeight() })

      Row() {
        HeaderIconButton({
          icon: $r("sys.symbol.arrow_left"),
          buttonSize: HdsHeaderMetrics.NAV_ACTION_SIZE,
          iconSize: 22,
        })
          .onClick(() => {
            this.handleBackNavigation();
          })

        HeaderTitleCapsule({
          title: this.user?.fullName ?? this.title,
          subtitle: this.getRootSubtitle(),
          capsuleWidth: BaseConstants.FULL_WIDTH,
          capsuleHeight: HdsHeaderMetrics.NAV_TITLE_BASE_HEIGHT,
        })
          .layoutWeight(BaseConstants.LAYOUT_WEIGHT_ONE)
          .margin({ left: 8, right: 8 })

        HeaderIconButton({
          icon: $r('sys.symbol.more'),
          buttonSize: HdsHeaderMetrics.NAV_ACTION_SIZE,
          iconSize: 22,
        })
      }
      .alignItems(VerticalAlign.Center)
      .height('100%')
      .width(BaseConstants.FULL_WIDTH)
      .padding({
        left: HdsHeaderMetrics.NAV_HORIZONTAL_PADDING,
        right: HdsHeaderMetrics.NAV_HORIZONTAL_PADDING,
        top: HdsHeaderMetrics.NAV_TITLE_TOP_PADDING,
      })
    }
    .height('100%')
    .width(BaseConstants.FULL_WIDTH)
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        Scroll(this.rootScroller) {
          Column() {
            if (this.isRootTab) {
              ProfileRootHeader({
                title: this.user?.fullName ?? this.title,
                subtitle: this.getRootSubtitle(),
                isPhotoExpanded: this.isProfilePhotoExpanded,
                isCollapsed: this.isRootHeaderCollapsed,
              })
            }

            Column() {
              if (this.user) {
                if (!this.isRootTab) {
                  // Show user profile.
                  Profile({
                    avatar: this.user.photoThumb ? this.getAvatarFromBytes(this.user.photoThumb) : "",
                    name: this.user.fullName,
                    bio: this.user.bio ?? "",
                  })
                }

                if (this.isRootTab) {
                  this.showRootSettingsList(this.user)
                } else {
                  // Details list.
                  this.showList(this.user)
                }
                Row().height(48)
              } else {
                // Loading: show skeleton content.
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
            .padding({
              left: this.isRootTab ? 0 : 16,
              right: this.isRootTab ? 0 : 16,
              top: this.isRootTab ? 12 : 16,
              bottom: 16,
            })
          }
          .width('100%')
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Auto)
        .backgroundColor(this.isRootTab ? '#F4F4F8' : Color.Transparent)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .onReachStart(() => {
          if (this.isRootTab && this.hasRootScrolledPastHeader) {
            this.rootScrollOffset = 0;
            this.hasRootScrolledPastHeader = false;
            this.isRootHeaderCollapsed = false;
            this.setProfilePhotoExpanded(true);
          }
        })
        .onScrollFrameBegin((offset: number, state: ScrollState) => {
          this.updateRootScrollState(offset, this.rootScroller.currentOffset().yOffset);
          return { offsetRemain: offset };
        })
        .onTouch((event: TouchEvent) => {
          this.handleRootPullGesture(event);
        })

        if (this.isRootTab) {
          ProfileRootTopBar({
            title: this.user?.fullName ?? this.title,
            isCollapsed: this.isRootHeaderCollapsed,
          })
            .zIndex(2)
        }
      }
      .width('100%')
      .height('100%')
    }
    .bindSheet($$this.showPushSettings, this.pushSettingsSheet(), {
      height: '90%',
      showClose: true,
      title: { title: $r('app.string.push_settings') },
      onDisappear: () => {
        this.showPushSettings = false;
      }
    })
    .title({
      builder: () => {
        this.TitleBuilder();
      },
      height: HdsHeaderMetrics.NAV_TITLE_BASE_HEIGHT + HdsHeaderMetrics.NAV_TITLE_TOP_PADDING,
    }, {
      backgroundColor: Color.Transparent,
      barStyle: BarStyle.STANDARD,
    })
    .hideTitleBar(this.isRootTab)
    .hideBackButton(true)
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
  showRootSettingsList(user: NativeSeenChat) {
    Column({ space: 14 }) {
      this.RootPhotoAction()

      Column() {
        this.RootMenuRow($r('sys.symbol.person'), 'My Profile', '', true)
        this.RootMenuRow($r('sys.symbol.paperplane'), 'Saved Messages', '', true)
        this.RootMenuRow($r('sys.symbol.bell'), 'Notifications', '', false)
      }
      .width('100%')
      .borderRadius(24)
      .backgroundColor(Color.White)

      Column() {
        this.RootMenuRow($r('sys.symbol.person_2'), 'Contacts', user.isContact ? 'Synced' : '', true)
        this.RootMenuRow($r('sys.symbol.more'), 'Recent Calls', '', true)
        this.RootMenuRow($r('sys.symbol.square_grid_2x2'), 'Devices', this.device ? 'This device' : '', true)
        this.RootMenuRow($r('sys.symbol.ohos_folder_badge_plus'), 'Chat Folders', '', false)
      }
      .width('100%')
      .borderRadius(24)
      .backgroundColor(Color.White)

      Column() {
        this.RootMenuRow($r('sys.symbol.bell'), 'Push Settings', '', false)
      }
      .width('100%')
      .borderRadius(24)
      .backgroundColor(Color.White)
    }
    .width('100%')
    .padding({
      left: HdsHeaderMetrics.ROOT_HORIZONTAL_PADDING,
      right: HdsHeaderMetrics.ROOT_HORIZONTAL_PADDING,
      bottom: 24,
    })
  }

  @Builder
  RootPhotoAction() {
    Row({ space: 14 }) {
      SymbolGlyph($r('sys.symbol.plus_square'))
        .fontSize(24)
        .fontColor([$r('sys.color.ohos_id_color_emphasize')])
        .width(42)

      Text('Change Profile Photo')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_emphasize'))
        .layoutWeight(BaseConstants.LAYOUT_WEIGHT_ONE)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(52)
    .width('100%')
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .borderRadius(24)
    .backgroundColor(Color.White)
  }

  @Builder
  RootMenuRow(icon: Resource, title: string, trailing: string, showDivider: boolean) {
    Column() {
      Row({ space: 14 }) {
        SymbolGlyph(icon)
          .fontSize(22)
          .fontColor([$r('sys.color.font_primary')])
          .width(42)

        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(BaseConstants.LAYOUT_WEIGHT_ONE)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (trailing.length > 0) {
          Text(trailing)
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        SymbolGlyph($r('sys.symbol.arrow_left'))
          .fontSize(16)
          .fontColor([$r('sys.color.font_secondary')])
          .rotate({ angle: 180 })
      }
      .height(50)
      .width('100%')
      .padding({ left: 16, right: 14 })
      .alignItems(VerticalAlign.Center)

      if (showDivider) {
        Divider()
          .strokeWidth(0.5)
          .color('#1A000000')
          .margin({ left: 72 })
      }
    }
    .width('100%')
    .onClick(() => {
      if (title === 'Push Settings') {
        this.showPushSettings = true;
      }
    })
  }

  @Builder
  showList(user: NativeSeenChat) {
    List() {
      // Username.
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

      // Phone number.
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

      // First name.
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

      // Last name.
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

      // Birthday.
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

      // Contact status.
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

      // Mutual contact.
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

      // Forum flag.
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

      // Chat ID for debugging.
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

      // Chat type.
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

        // Push settings entry.
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
    // TODO: Convert the byte array to base64 or an image URI.
    // The exact format depends on the image handling path.
    return "";
  }

  private getRootSubtitle(): string {
    if (!this.user) {
      return '';
    }

    let subtitle = '';
    if (this.user.phone) {
      subtitle = this.user.phone;
    }
    if (this.user.username) {
      subtitle += (subtitle.length > 0 ? ' - ' : '') + '@' + this.user.username;
    }
    if (subtitle.length === 0 && this.device) {
      subtitle = this.device;
    }
    return subtitle;
  }

  private updateRootScrollState(offset: number, currentYOffset: number): void {
    if (!this.isRootTab) {
      return;
    }

    this.rootScrollOffset = Math.max(0, currentYOffset);
    this.isRootHeaderCollapsed = this.rootScrollOffset > 72;
    if (this.isRootHeaderCollapsed) {
      this.hasRootScrolledPastHeader = true;
    }

    if (offset < -8 && currentYOffset <= 0) {
      this.setProfilePhotoExpanded(true);
      return;
    }

    if (this.rootScrollOffset > 12) {
      this.setProfilePhotoExpanded(false);
    }
  }

  private setProfilePhotoExpanded(expanded: boolean): void {
    if (this.isProfilePhotoExpanded === expanded) {
      return;
    }

    animateTo({
      curve: curves.springMotion(0.7, 0.85),
      duration: 420
    }, () => {
      this.isProfilePhotoExpanded = expanded;
    });
  }

  private handleRootPullGesture(event: TouchEvent): void {
    if (!this.isRootTab || event.touches.length === 0) {
      return;
    }

    const touchY = event.touches[0].windowY;
    if (event.type === TouchType.Down) {
      this.rootPullStartY = touchY;
      return;
    }

    if (event.type === TouchType.Move && this.rootScrollOffset <= 0 &&
      touchY - this.rootPullStartY > 72) {
      this.setProfilePhotoExpanded(true);
      return;
    }

    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.rootPullStartY = 0;
    }
  }

  private formatDate(timestamp: number): string {
    const date = new Date(timestamp * 1000);
    return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate()
      .toString()
      .padStart(2, '0')}`;
  }

  private getChatTypeString(chatType: number): ResourceStr {
    // Adjust this mapping according to ChatType enum values.
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

  private handleBackNavigation(): void {
    this.pathStack?.pop();
  }
}


