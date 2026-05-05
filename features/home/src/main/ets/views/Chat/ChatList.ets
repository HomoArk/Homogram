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

import { BaseConstants, BreakpointConstants, Logger, Vibrator } from '@ohos/base';
import { ChatItem } from './ChatItem';
import { HomeTopSearch } from '../common/HomeTopSearch';
import { HeaderFloatingSearchButton, HdsHeaderMetrics } from '../common/HdsHeaderPrimitives';
import { HomeConstants } from '../../constants/HomeConstants';
import { deviceInfo } from '@kit.BasicServicesKit';
import { ChatType } from '../../api';
import { Chat } from '../../entities/Chat';
import { ChatDataSource } from '../../viewmodel/Chat/ChatDataSource';
import { ChatListActions } from '../../viewmodel/Chat/ChatListActions';
import { ChatRowState } from '../../viewmodel/Chat/ChatRowState';
import { curves } from '@kit.ArkUI';

@Component
export struct ChatList {
  @StorageProp('currentBreakpoint') currentBreakpoint: string = BreakpointConstants.BREAKPOINT_SM;
  @Consume chatDataSource: ChatDataSource;
  @Consume currentChatId: string;
  @Link isShowSearchIcon: boolean;
  @Link isFromHideSearchBar: boolean;
  @Consume('pageInfo') pageInfo?: NavPathStack;
  @State searchValue: string = '';
  @State isSearchExpanded: boolean = false;
  @State searchCollapseProgress: number = 0;
  @State homeTopSearchHeight: Length = 176;
  @StorageProp('bottomRectHeight') bottomRectHeight: number = 0;
  @Consume isAppFirstLoad: boolean;
  @Consume currentForumId: string;
  @State chatItemTransitionEffect: TransitionEffect | undefined = undefined;
  @Prop isInTopicPage: boolean = false;
  private scroller: Scroller = new Scroller();
  private searchController: SearchController = new SearchController();
  private lastIndexInOneScreen: number = -1;
  private onScrollIndexCounter: number = 0;
  private actions: ChatListActions = new ChatListActions();
  private readonly floatingTabBarHeight: number = 56;
  private readonly floatingTabBarBottomMargin: number = 8;
  private readonly listBottomBreathingRoom: number = 16;
  private readonly listTopBreathingRoom: number = 20;
  private readonly searchCollapseDistance: number = 96;

  @Styles
  animationStyle() {
    .animation({ curve: curves.springMotion(0.6, 0.8) })
    .transition(TransitionEffect.move(TransitionEdge.TOP)
      .animation({ curve: curves.springMotion(0.6, 0.8) }))
  }

  @Styles
  chatListAnimationStyle() {
    .animation({ curve: curves.springMotion(0.6, 0.8) })
    .transition(this.chatItemTransitionEffect)
  }

  @Builder
  FloatingSearchButton() {
    HeaderFloatingSearchButton({ buttonSize: this.floatingTabBarHeight })
      .onClick(() => {
        this.isSearchExpanded = true;
      })
  }

  @Builder
  ChatContextMenu(chat: Chat) {
    Menu() {
      MenuItem({
        startIcon: $r('app.media.ic_public_add_norm'),
        content: chat.pinned ? 'Unpin' : 'Pin'
      })
        .onClick(() => {
          this.actions.setPinned(chat, !chat.pinned, this.getUIContext().getPromptAction());
        })
      MenuItem({
        startIcon: $r('app.media.ic_public_sound'),
        content: chat.muted ? 'Unmute' : 'Mute'
      })
        .onClick(() => {
          this.actions.setMuted(chat, !chat.muted, this.getUIContext().getPromptAction());
        })
      MenuItem({
        startIcon: chat.archived ? $r('app.media.ic_public_refresh') : $r('app.media.ic_public_cloud_upload'),
        content: chat.archived ? 'Unarchive' : 'Archive'
      })
        .onClick(() => {
          this.actions.setArchived(chat, !chat.archived, this.getUIContext().getPromptAction());
        })
      if (chat.unreadCount > 0) {
        MenuItem({
          startIcon: $r('app.media.ic_public_email_send'),
          content: 'Mark as read'
        })
          .onClick(() => {
            this.actions.markRead(chat, this.getUIContext().getPromptAction());
          })
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      HomeTopSearch({
        title: 'Chats',
        isCompact: $isShowSearchIcon,
        isSearchExpanded: $isSearchExpanded,
        searchValue: $searchValue,
        searchCollapseProgress: this.searchCollapseProgress,
      })
        .expandSafeArea([SafeAreaType.SYSTEM])
        .zIndex(1)
        .onAreaChange((oldValue: Area, newValue: Area) => {
          this.homeTopSearchHeight = newValue.height
          console.debug("homeTopSearchHeight", oldValue.height.toString(), "to", newValue.height)
        })

      List({
        scroller: this.scroller,
      }) {
        // if (this.isShowTopPadding) {
        //   ListItem() {
        //     Row()
        //       .width(BaseConstants.FULL_WIDTH)
        //       .height(BaseConstants.NAV_TITLE_BAR_HEIGHT)
        //       .backgroundColor(Color.Black)
        //   }
        //   .transition(TransitionEffect.move(TransitionEdge.BOTTOM)
        //     .animation({ curve: curves.responsiveSpringMotion() }))
        //   .animation({ curve: curves.responsiveSpringMotion() })
        // }


        // ListItem() {
        //   if (!this.isShowSearchIcon) {
        //     // search bar
        //     Search({
        //       value: this.searchValue,
        //       placeholder: $r('app.string.search_placeholder'),
        //       controller: this.searchController,
        //     })
        //       .width(HomeConstants.CHAT_LIST_SEARCH_BAR_WIDTH)
        //       .height(!this.isShowSearchIcon ? HomeConstants.CHAT_LIST_SEARCH_BAR_HEIGHT :
        //         HomeConstants.CHAT_LIST_SEARCH_BAR_HEIGHT + 20)
        //       .padding({
        //         bottom: HomeConstants.CHAT_LIST_SEARCH_BAR_PADDING
        //       })
        //       .margin({
        //         left: HomeConstants.CHAT_LIST_SEARCH_BAR_MARGIN,
        //         right: HomeConstants.CHAT_LIST_SEARCH_BAR_MARGIN,
        //         // top: HomeConstants.CHAT_LIST_SEARCH_BAR_MARGIN,
        //         // top: 56
        //       })
        //       .textFont({
        //         size: HomeConstants.CHAT_LIST_SEARCH_BAR_FONT_SIZE
        //       })
        //       .animationStyle()
        //   }
        // }
        // .margin({
        //   bottom: this.isShowSearchIcon ? 30 : 0
        // })

        // .animationStyle() // forbidden, will cause a mass

        ListItem() { // Placeholder to prevent HomeTopSearch from overlapping ChatItems.
          Row()
            .height(this.getTopSpacerHeight())
            .margin({ bottom: -20 })
            .width(BaseConstants.FULL_WIDTH)
        }

        LazyForEach(this.chatDataSource, (item: ChatRowState, index: number) => {
          ListItem() {
            ChatItem({
              chatData: item,
              isInTopicPage: this.isInTopicPage
            })
              .id('hg-chat-row-' + item.chatId.toString())
              .onClick(() => {
                this.currentChatId = item.chatId.toString();
                let chat = this.chatDataSource.get(this.currentChatId);
                Logger.debug('ChatList ChatItem onClick chatType: ' + chat?.chatType + ' forum: ' + chat?.forum);

                // Check whether split mode is active. This means the breakpoint is not sm.
                const isSplitMode = this.currentBreakpoint !== BreakpointConstants.BREAKPOINT_SM;
                // Check whether a ChatDetail page already exists.
                let hasChatDetail: undefined | boolean = undefined;
                try {
                  hasChatDetail = this.pageInfo && this.pageInfo?.size() >= 1 &&
                  this.pageInfo.getParamByName('ChatDetail')?.length > 0;
                } catch (e) {
                  console.error(e);
                }

                if (chat?.chatType === ChatType.Group && chat?.forum) {
                  if (this.isInTopicPage) {
                    if (this.currentForumId !== this.currentChatId) {
                      if (isSplitMode && hasChatDetail) {
                        this.pageInfo?.replacePath({ name: 'ChatDetail' });
                      } else {
                        this.pageInfo?.pushPath({ name: 'ChatDetail' });
                      }
                    } else {
                      this.currentForumId = "";
                      this.pageInfo?.pop();
                      return;
                    }
                  } else {
                    if (isSplitMode && hasChatDetail) {
                      this.pageInfo?.replacePath({ name: 'ChatDetail' });
                    } else {
                      this.pageInfo?.pushPath({ name: 'ChatDetail' });
                    }
                  }
                  this.currentForumId = this.currentChatId;
                } else {
                  if (isSplitMode && hasChatDetail) {
                    this.pageInfo?.replacePath({ name: 'ChatDetail' });
                  } else {
                    this.pageInfo?.pushPath({ name: 'ChatDetail' });
                  }
                }
              })
              .bindContextMenu(this.ChatContextMenu(item.toChat()), ResponseType.LongPress)
              .animation({ curve: curves.springMotion(0.6, 0.8) })
          }

          // .height(Adaptive.ContactItemHeight(this.currentBreakpoint))
          // .margin({
          //   top: (index === 0 && this.isShowSearchIcon) ? 56 : 0
          // })

          // .animation({ curve: curves.springMotion(0.6, 0.8) })
          // .animationStyle()

          // .animation(this.isShowSearchIcon ? { curve: curves.springMotion(0.6, 0.8) } : {})

          // .chatListAnimationStyle()
        }, (item: ChatRowState) => item.chatId.toString())

        ListItem() {
          Row()
            .height(this.getBottomSpacerHeight())
            .width(BaseConstants.FULL_WIDTH)
        }
      }
      .id('hg-chat-list')
      .height(BaseConstants.FULL_PERCENT)
      .cachedCount(BaseConstants.LAZY_FOR_EACH_CACHED_COUNT)
      .padding({
        bottom: deviceInfo.deviceType !== BaseConstants.DEVICE_2IN1 &&
          (this.currentBreakpoint === BreakpointConstants.BREAKPOINT_LG || this.currentBreakpoint === BreakpointConstants.BREAKPOINT_XL) ?
        $r('app.float.tab_content_pb') : $r('app.float.zero')
      })
      .onScrollIndex((start, end, center) => {
        Logger.debug('ChatList onScrollIndex start: ' + start + ' end: ' + end + ' center: ' + center +
          ' lastIndexInOneScreen: ' + this.lastIndexInOneScreen + ' isFromHideSearchBar: ' + this.isFromHideSearchBar);
        if (this.onScrollIndexCounter < 3) {
          this.onScrollIndexCounter++;
          this.lastIndexInOneScreen = end;
          if (this.onScrollIndexCounter === 3) {
            this.chatItemTransitionEffect = undefined;
          }
          return;
        }
        this.chatItemTransitionEffect = undefined;
        this.updateSearchCollapseProgress();
      })
      .onScrollFrameBegin((offset, state) => {
        // Logger.debug('ChatList onScrollFrameBegin offset: ' + offset + ' state: ' + state.toString());
        let result = this.scroller.currentOffset();
        // Logger.debug('ChatList onScrollFrameBegin currentOffset: xOffset: ' + result.xOffset + ' yOffset: ' +
        // result.yOffset);
        if (offset < 0 && result.yOffset <= 0) {
          this.resetSearchCollapse();
          // Vibrator.kata();
          Logger.debug('ChatList onScrollFrameBegin isShowSearchIcon: ' + this.isShowSearchIcon);
        } else {
          this.updateSearchCollapseProgress(Math.max(0, result.yOffset + offset));
        }
        return { offsetRemain: offset };
      })
      .onDidScroll((scrollOffset: number, scrollState: ScrollState) => {
        this.updateSearchCollapseProgress();
      })
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .onReachStart(() => {
        Logger.debug('ChatList onReachStart isFromHideSearchBar: ' + this.isFromHideSearchBar);
        // this.isShowSearchIcon = false;
        // this.homeNavTitleBarStyle = BarStyle.STANDARD;
      })
      .chatListAnimationStyle()
      // .divider({
      //   strokeWidth: $r('app.float.chat_list_divider_stroke_width'),
      //   color: $r('app.float.chat_list_divider_stroke_width'),
      //   startMargin: HomeConstants.CHAT_LIST_DIVIDER_START_MARGIN,
      //   endMargin: HomeConstants.CHAT_LIST_DIVIDER_END_MARGIN
      // })

      if (this.isShowSearchIcon && !this.isSearchExpanded) {
        Row() {
          this.FloatingSearchButton()
        }
        .width(BaseConstants.FULL_WIDTH)
        .height(BaseConstants.FULL_HEIGHT)
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Bottom)
        .padding({
          right: HdsHeaderMetrics.ROOT_HORIZONTAL_PADDING,
          bottom: this.getFloatingSearchBottomMargin(),
        })
        .hitTestBehavior(HitTestMode.Transparent)
        .zIndex(3)
        .opacity(this.getFloatingSearchOpacity())
        .scale({
          x: this.getFloatingSearchScale(),
          y: this.getFloatingSearchScale()
        })
        .transition(TransitionEffect.OPACITY.animation({ curve: curves.springMotion(0.6, 0.8) })
          .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })
            .animation({ curve: curves.springMotion(0.6, 0.8) })))
      }
    }
    .expandSafeArea([SafeAreaType.SYSTEM])
    .onAppear(() => {
      AppStorage.setOrCreate("chatListScroller", this.scroller);
    })

    // .backgroundColor($r('app.color.chat_clicked_bg_color'))
  }

  aboutToAppear(): void {
    if (this.isAppFirstLoad) {
      this.isAppFirstLoad = false;
      this.chatItemTransitionEffect = TransitionEffect.move(TransitionEdge.BOTTOM)
        .animation({ curve: curves.springMotion(0.6, 0.8) });
    } else {
      this.chatItemTransitionEffect = undefined;
    }
  }

  private getBottomSpacerHeight(): Length {
    if (this.currentBreakpoint === BreakpointConstants.BREAKPOINT_LG ||
      this.currentBreakpoint === BreakpointConstants.BREAKPOINT_XL) {
      return BaseConstants.FULL_PERCENT;
    }

    if (deviceInfo.deviceType === BaseConstants.DEVICE_2IN1) {
      return this.floatingTabBarHeight;
    }

    return this.floatingTabBarHeight + this.floatingTabBarBottomMargin + this.bottomRectHeight +
      this.listBottomBreathingRoom;
  }

  private getTopSpacerHeight(): Length {
    if (typeof this.homeTopSearchHeight === 'number') {
      return this.homeTopSearchHeight + this.listTopBreathingRoom;
    }

    return this.homeTopSearchHeight;
  }

  private getFloatingSearchBottomMargin(): Length {
    return this.floatingTabBarBottomMargin;
  }

  private updateSearchCollapseProgress(yOffset?: number): void {
    if (this.isSearchExpanded) {
      return;
    }

    const currentYOffset = yOffset === undefined ? this.getCurrentScrollYOffset() : yOffset;
    const nextProgress = Math.min(1, Math.max(0, currentYOffset / this.searchCollapseDistance));
    if (Math.abs(nextProgress - this.searchCollapseProgress) > 0.01) {
      this.searchCollapseProgress = nextProgress;
    }

    const shouldShowFloatingSearch = nextProgress >= 0.98;
    if (this.isShowSearchIcon !== shouldShowFloatingSearch) {
      this.isShowSearchIcon = shouldShowFloatingSearch;
    }
    this.isFromHideSearchBar = nextProgress > 0.05;
  }

  private resetSearchCollapse(): void {
    this.searchCollapseProgress = 0;
    this.isShowSearchIcon = false;
    this.isFromHideSearchBar = false;
    this.isSearchExpanded = false;
  }

  private getCurrentScrollYOffset(): number {
    const result = this.scroller.currentOffset();
    return Math.max(0, result.yOffset);
  }

  private getFloatingSearchOpacity(): number {
    return Math.min(1, Math.max(0, (this.searchCollapseProgress - 0.82) / 0.18));
  }

  private getFloatingSearchScale(): number {
    return 0.9 + this.getFloatingSearchOpacity() * 0.1;
  }

}


