/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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

import {
  BaseConstants,
  BreakpointConstants,
  CurrentFeature,
  CurrentPage,
  Logger,
  CircleButton,
  Vibrator,
} from '@ohos/base';
import ChatDetailNone from '../views/Chat/ChatDetailNone';
import { ProfilePage } from './ProfilePage';
import { ChatDetail } from './Chat/ChatDetail';
import { ChatList } from '../views/Chat/ChatList';
import { HomeConstants } from '../constants/HomeConstants';
import { emitter } from '@kit.BasicServicesKit';
import { PhoneNumber, VerifyCode, Password } from './Login/Index';
import { PushSettings } from './PushSettings';
import { NativeSeenChat, sessionService, telegramSyncService } from '../api';
import { HashMap } from '@kit.ArkTS';
import { ChatDataSource } from '../viewmodel/Chat/ChatDataSource';
import { MessageDataSource } from '../viewmodel/Message/MessageDataSource';
import { curves, SymbolGlyphModifier } from '@kit.ArkUI';
import { SeenChat } from '../entities/SeenChat';
import { ForumTopicList } from './Chat/Group/ForumTopicList';
import { ParticipantList } from './Chat/Group/ParticipantList';
import { EventConstants } from '../constants/EventConstants';
import { Contacts } from './Contacts';
import { Me } from './Me';
import { common } from '@kit.AbilityKit';

@Entry
@Component
export struct Index {
  @StorageProp('currentBreakpoint') @Watch('watchCurrentBreakpoint') currentBreakpoint: string =
    BreakpointConstants.BREAKPOINT_SM;
  @StorageProp('bottomRectHeight') bottomRectHeight: number = 0;
  @StorageProp('topRectHeight') topRectHeight: number = 0;
  @Provide chatDataSource: ChatDataSource = new ChatDataSource();
  @Provide messagesOfChatMap: HashMap<string, MessageDataSource> = new HashMap();
  @Provide seenChatsMap: HashMap<string, SeenChat> = new HashMap();
  @Provide('pageInfo') pageInfo: NavPathStack = new NavPathStack();
  @Provide me: NativeSeenChat | undefined = undefined;
  @Provide currentChatId: string = '';
  @Provide currentForumId: string = '';
  @State currentChatPinned: boolean = false;
  @State currentChatUserName: string = '';
  @State currentContactUserName: string = '';
  @State currentContactUserIcon: Resource = HomeConstants.DEFAULT_AVATAR;
  @State currentPageIndex: number = CurrentPage.HOME;
  @State currentFeatureIndex: Number = CurrentFeature.HOME;
  @State isSplitAppletScreen: boolean = BaseConstants.SPLIT_APPLET_SCREEN;
  @State isSplitDocumentScreen: boolean = BaseConstants.SPLIT_DOCUMENT_SCREEN;
  @State isLoggedIn: boolean = false;
  @State blurStyle: BlurStyle = BlurStyle.Thin;
  @State titleAndTabBarColor: Color | Resource = Color.Transparent;
  @State isShowNewMessageSheet: boolean = false;
  @State isShowSearchIcon: boolean = false;
  @State isLoadingNewMessages: boolean = false;
  @State isShowChatListTopPadding: boolean = false;
  @State titleMode: NavigationTitleMode = NavigationTitleMode.Free;
  @State barStyle: BarStyle = BarStyle.STANDARD;
  @State isInChatDetailPage: boolean = false;
  @State isOnTop: boolean = true;
  @Provide isAppFirstLoad: boolean = true;
  @State menuItems: Array<NavigationMenuItem> = [
    {
      value: 'menuItem1',
      symbolIcon: new SymbolGlyphModifier($r('sys.symbol.ohos_folder_badge_plus')).fontColor([Color.Red, Color.Green])
        .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR),
    },
  ];
  private searchIconTransitionEffect: TransitionEffect =
    TransitionEffect.OPACITY.animation({
      curve: curves.springMotion(0.6, 0.8)
    })
      .combine(TransitionEffect.scale({ x: 0, y: 0 }))
      .combine(TransitionEffect.rotate({ angle: 90 }))
      .combine(TransitionEffect.translate({ y: 150 }).animation({ curve: curves.springMotion() }))
      .combine(TransitionEffect.move(TransitionEdge.END));
  @State menuItems2: Array<NavigationMenuItem> = [
    {
      value: 'menuItem1',
      symbolIcon: new SymbolGlyphModifier($r('sys.symbol.ohos_folder_badge_plus')).fontColor([Color.Red, Color.Green])
        .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
    },
    {
      value: 'menuItem2',
      symbolIcon: new SymbolGlyphModifier($r('sys.symbol.magnifyingglass_circle')).transition(
        this.searchIconTransitionEffect
      )
    },
  ];
  private allowedCustomTransitionFromPageName: string[] = ['undefined'];
  private allowedCustomTransitionToPageName: string[] = ['TopicList'];

  watchCurrentBreakpoint() {
    if (this.currentBreakpoint === BreakpointConstants.BREAKPOINT_SM &&
      this.pageInfo.getParamByName('ChatDetailNone').length === 1 && this.pageInfo.size() === 1) {
      this.pageInfo.pop();
    }
  }

  @Builder
  NavigationMenus() {
    if (this.isShowSearchIcon) {
      Row() {
        CircleButton({
          icon: $r('sys.symbol.magnifyingglass_circle'),
        })
      }
      .alignItems(VerticalAlign.Bottom)
      .margin({
        top: HomeConstants.NAV_MENU_TOP_MARGIN,
        left: HomeConstants.NAV_TITLE_LEFT_MARGIN,
        right: HomeConstants.NAV_TITLE_LEFT_MARGIN
      })
      .transition(this.searchIconTransitionEffect)
    }
  }

  @Builder
  NewMessageSheet() {
    Column() {
      Text('New Message')
        .fontSize($r('sys.float.ohos_id_text_size_headline1'))
        .fontWeight(700)
        .lineHeight(41)
        .fontColor($r('sys.color.font_primary'))
        .margin({ top: 24, left: 24 })
    }
  }

  @Builder
  PageMap(name: string) {
    if (name === 'ChatDetail') {
      ChatDetail({ isInChatDetailPage: this.isInChatDetailPage });
    } else if (name === 'TopicList') {
      ForumTopicList({
        isShowChatListTopPadding: this.isShowChatListTopPadding,
        isShowSearchIcon: this.isShowSearchIcon,
      })
    } else if (name === 'ParticipantList') {
      ParticipantList()
    } else if (name === 'ChatDetailNone') {
      ChatDetailNone();
    } else if (name === 'Profile' || name === 'ProfilePage') {
      ProfilePage();
    } else if (name === 'PushSettings') {
      PushSettings();
    } else if (name === 'Login/PhoneNumber') {
      PhoneNumber();
    } else if (name === 'Login/VerifyCode') {
      VerifyCode();
    } else if (name === 'Login/Password') {
      Password();
    } else {
      ChatDetailNone();
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Row() {
        LoadingProgress()
          .size({
            width: HomeConstants.NAV_TITLE_FONT_SIZE,
            height: HomeConstants.NAV_TITLE_FONT_SIZE
          })
          .alignSelf(ItemAlign.Center)
        Text('Connecting...')
          .fontSize(HomeConstants.NAV_TITLE_FONT_SIZE)
      }
      .alignItems(VerticalAlign.Center)
      .visibility(this.isLoadingNewMessages && this.currentPageIndex === 0 && this.isOnTop ? Visibility.Visible :
        Visibility.Hidden)
      .zIndex(1)
      .transition(TransitionEffect.move(TransitionEdge.TOP).animation({ curve: curves.springMotion(0.6, 0.8) }))

      Navigation(this.pageInfo) {
        Tabs({
          barPosition: this.currentBreakpoint !== BreakpointConstants.BREAKPOINT_SM ? BarPosition.Start : BarPosition.End
        }) {
          TabContent() {
            ChatList({
              isFromHideSearchBar: $isShowChatListTopPadding,
              isShowSearchIcon: $isShowSearchIcon,
              isInTopicPage: false,
            })
              .expandSafeArea([SafeAreaType.SYSTEM])
              .width(BaseConstants.FULL_WIDTH)
          }
          .tabBar(new BottomTabBarStyle({
            normal: new SymbolGlyphModifier($r('sys.symbol.message_on_message')),
            selected: new SymbolGlyphModifier($r('sys.symbol.message_on_message_fill')),
          }, HomeConstants.TAB_BAR_TEXTS[0]))
          .expandSafeArea([SafeAreaType.SYSTEM])
          .padding({
            left: this.currentBreakpoint !== BreakpointConstants.BREAKPOINT_SM ? $r('app.float.bar_width') : 0
          })

          TabContent() {
            Contacts()
              .padding({
                left: this.currentBreakpoint !== BreakpointConstants.BREAKPOINT_SM ? $r('app.float.bar_width') : 0
              })
          }
          .tabBar(new BottomTabBarStyle({
            normal: new SymbolGlyphModifier($r('sys.symbol.person_2')),
            selected: new SymbolGlyphModifier($r('sys.symbol.person_2_fill')),
          }, HomeConstants.TAB_BAR_TEXTS[1]))

          TabContent() {
            Me()
              .padding({
                left: this.currentBreakpoint !== BreakpointConstants.BREAKPOINT_SM ? $r('app.float.bar_width') : 0
              })
          }
          .tabBar(new BottomTabBarStyle({
            normal: new SymbolGlyphModifier($r('sys.symbol.person')),
            selected: new SymbolGlyphModifier($r('sys.symbol.person_fill')),
          }, HomeConstants.TAB_BAR_TEXTS[2]))
        }
        .expandSafeArea([SafeAreaType.SYSTEM])
        .scrollable(false)
        .vertical(this.currentBreakpoint !== BreakpointConstants.BREAKPOINT_SM)
        .barWidth(this.currentBreakpoint !== BreakpointConstants.BREAKPOINT_SM ?
          $r('app.float.bar_width') : BaseConstants.FULL_PERCENT)
        .barOverlap(true)
        .barBackgroundColor(this.titleAndTabBarColor)
        .barBackgroundBlurStyle(this.blurStyle)
        .height(BaseConstants.FULL_HEIGHT)
        .width(BaseConstants.FULL_WIDTH)
        .onChange((index: number) => {
          this.currentPageIndex = index;
          Vibrator.kata();
        })
        .animationDuration(300)
        .animation({ curve: curves.springMotion(0.6, 0.8) })
      }
      .bindSheet($$this.isShowNewMessageSheet, this.NewMessageSheet, {
        height: '100%',
        dragBar: false,
        scrollSizeMode: ScrollSizeMode.CONTINUOUS,
        onDisappear: () => {
          this.isShowNewMessageSheet = !this.isShowNewMessageSheet;
        }
      })
      .menus(this.isShowSearchIcon ? this.menuItems2 : this.menuItems)
      .hideTitleBar(true)
      .titleMode(this.titleMode)
      .title(HomeConstants.TAB_BAR_TEXTS[this.currentPageIndex], {
        backgroundColor: this.titleAndTabBarColor,
        backgroundBlurStyle: this.blurStyle,
        barStyle: this.barStyle,
      })
      .hideToolBar(true)
      .hideBackButton(true)
      .navBarWidth(this.currentBreakpoint === BreakpointConstants.BREAKPOINT_XL ?
        HomeConstants.NAVIGATION_NAV_BAR_WIDTH_XL :
        (this.currentBreakpoint === BreakpointConstants.BREAKPOINT_LG ?
          HomeConstants.NAVIGATION_NAV_BAR_WIDTH_LG :
          HomeConstants.NAVIGATION_NAV_BAR_WIDTH_MD))
      .navDestination(this.PageMap)
      .mode((this.currentBreakpoint === BreakpointConstants.BREAKPOINT_SM || !this.isLoggedIn) ? NavigationMode.Stack :
        NavigationMode.Split)
      .width(BaseConstants.FULL_WIDTH)
      .onAppear(async () => {
        try {
          await telegramSyncService.initialize({
            chatDataSource: this.chatDataSource,
            messagesOfChatMap: this.messagesOfChatMap,
            seenChatsMap: this.seenChatsMap,
          });
          await telegramSyncService.hydrateFromCache();
          this.isLoggedIn = await sessionService.isLoggedIn();
          if (this.isLoggedIn) {
            this.isLoadingNewMessages = true;
            const context = getContext(this) as common.UIAbilityContext;
            this.me = await sessionService.onAuthorized(context);
            this.isLoadingNewMessages = false;
          } else if (this.pageInfo.size() === 0) {
            this.pageInfo.pushPath({ name: 'Login/PhoneNumber' });
          }
        } catch (error) {
          this.isLoadingNewMessages = false;
          Logger.error('Home page onAppear failed: ' + JSON.stringify(error));
        }
      })
      .animation({ curve: curves.springMotion(0.6, 0.8) })
      .transition(TransitionEffect.move(TransitionEdge.TOP).animation({ curve: curves.springMotion(0.6, 0.8) }))
      .onNavBarStateChange((isVisible: boolean) => {
        this.isOnTop = isVisible;
        this.titleMode = isVisible ? NavigationTitleMode.Free : NavigationTitleMode.Mini;
      })
      .customNavContentTransition((from: NavContentInfo, to: NavContentInfo) => {
        if ((!from || !to) || (!from.name || !to.name)) {
          return undefined;
        }
        if (!this.isCustomTransitionEnabled(from.name, to.name)) {
          return undefined;
        }
        return undefined;
      })
    }
    .transition(TransitionEffect.move(TransitionEdge.TOP).animation({ curve: curves.springMotion(0.6, 0.8) }))
    .height(BaseConstants.FULL_HEIGHT)
    .width(BaseConstants.FULL_WIDTH)
  }

  aboutToAppear(): void {
    let onForegroundEvent: emitter.InnerEvent = { eventId: 0 };
    emitter.on(onForegroundEvent, async () => {
      try {
        const context = getContext(this) as common.UIAbilityContext;
        const isAuthorized = await sessionService.onForeground(context);
        if (!isAuthorized) {
          Logger.debug('Home page onForegroundEvent reconnect not authorized');
        }
      } catch (error) {
        Logger.error('Home page onForegroundEvent reconnect error ' + JSON.stringify(error));
      }
    })
    emitter.on(EventConstants.onLoginEvent, async () => {
      this.isLoggedIn = true;
      this.isLoadingNewMessages = true;
      try {
        const context = getContext(this) as common.UIAbilityContext;
        this.me = await sessionService.onAuthorized(context);
      } catch (error) {
        Logger.error('Home page onLoginEvent failed: ' + JSON.stringify(error));
      } finally {
        this.isLoadingNewMessages = false;
      }
    })
  }

  private isCustomTransitionEnabled(fromName: string, toName: string): boolean {
    return ((this.allowedCustomTransitionFromPageName.includes(fromName)
      && this.allowedCustomTransitionToPageName.includes(toName))
      || (this.allowedCustomTransitionFromPageName.includes(toName)
        && this.allowedCustomTransitionToPageName.includes(fromName)));
  }
}



