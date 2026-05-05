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
import { ChatDetailBottom } from '../../views/Chat/ChatDetailBottom';
import ChatDetailItem from '../../views/Chat/ChatDetailItem';
// import { ChatDetailTopSearch } from '../../views/Chat/ChatDetailTopSearch';
import { HomeConstants } from '../../constants/HomeConstants';
import { Message } from '../../entities/Message';
import { SeenChat } from '../../entities/SeenChat';
import { HashMap } from '@kit.ArkTS';
import { ChatDataSource } from '../../viewmodel/Chat/ChatDataSource';
import { MessageDataSource } from '../../viewmodel/Message/MessageDataSource';
import { ChatDetailMessageActions } from '../../viewmodel/Message/ChatDetailMessageActions';
import { ChatType, loadHistoryMessages, forwardMessages, NativeMessage, NativeSeenChat } from '../../api';
import { curves, promptAction } from '@kit.ArkUI';
import {
  HeaderAvatar,
  HeaderGradientBlur,
  HeaderIconButton,
  HeaderTitleCapsule,
  HdsHeaderMetrics,
  navHeaderGradientHeight
} from '../../views/common/HdsHeaderPrimitives';

@AnimatableExtend(NavDestination)
  function animatableBlur(blurRadius: number) {
  .blur(blurRadius)
}

@Component
export struct ChatDetail {
  @StorageProp('currentBreakpoint') currentBreakpoint: string = BreakpointConstants.BREAKPOINT_SM;
  // @Consume pinnedChatsMap: HashMap<string, Chat>;
  // @Consume chatsMap: Map<string, Chat>;
  @Consume chatDataSource: ChatDataSource;
  @Consume messagesOfChatMap: HashMap<string, MessageDataSource>;
  @Consume seenChatsMap: HashMap<string, SeenChat>;
  @Consume currentChatId: string;
  @Consume me: NativeSeenChat | undefined;
  @Consume('pageInfo') pageInfo: NavPathStack;
  @State currentChatUserName: string = '';
  @State isShowMediaSheet: boolean = false;
  @State blurStyle: BlurStyle = BlurStyle.Thin;
  @State titleAndTabBarColor: Color | Resource = Color.Transparent;
  @Prop isInChatDetailPage: boolean;
  @Provide continuousChatDetailBlurRadius: number = 0;
  @Provide discreteChatDetailBlurRadius: number = 0;
  @Provide isScrollingDueToReplyToMessage: boolean = false;
  @Provide scrollToRepliedMessageIndex: number = -1;
  @State messageTransitionEffect: TransitionEffect | undefined = undefined;
  @State replyToMessageId?: number = undefined;
  @State isLoadingHistory: boolean = false;
  @State selectedMessageId: number = -1;
  @State hasReachedSwipeBoundary: boolean = false;

  private shouldTransferToOnScrollIndex = false;
  private beforeFinalScrollIndex: number = -1;
  private messageListScroller: ListScroller = new ListScroller();
  private isAtEnd: boolean = false;
  private length: number = 0;
  private chatType: ChatType = ChatType.User;
  private isGroupOrChannel: boolean = false;
  private messageActions: ChatDetailMessageActions = new ChatDetailMessageActions();
  private initialMessagesLoaded: boolean = false;
  private historyPaginationArmed: boolean = false;
  @State messageDataSource: MessageDataSource = this.messagesOfChatMap.get(this.currentChatId) ?? new MessageDataSource();

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
          title: this.currentChatUserName,
          subtitle: this.getHeaderSubtitle(),
          capsuleWidth: BaseConstants.FULL_WIDTH,
          capsuleHeight: HdsHeaderMetrics.NAV_TITLE_BASE_HEIGHT,
          titleFontSize: 17,
          subtitleFontSize: 12,
        })
          .layoutWeight(BaseConstants.LAYOUT_WEIGHT_ONE)
          .margin({ left: 8, right: 8 })
          .onClick(() => {
            if (this.isGroupOrChannel) {
              Logger.debug('ChatDetail title clicked, navigating to ParticipantList');
              this.pageInfo.pushPath({ name: 'ParticipantList' });
            }
          })

        HeaderAvatar({
          source: HomeConstants.DEFAULT_AVATAR,
          avatarSize: HdsHeaderMetrics.NAV_ACTION_SIZE,
        })
          .border({
            width: 1,
            color: '#80FFFFFF'
          })
      }
      .alignItems(VerticalAlign.Center)
      .height(this.getChatTitleHeight())
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

  @Styles
  messageAnimationStyle() {
    .animation({ curve: curves.springMotion(0.6, 0.8) })
      .transition(this.messageTransitionEffect)
  }

  // @Builder
  // NavigationTitle() {
  //   Row() {
  //     Text(this.currentChatUserName)
  //       .fontColor($r('sys.color.font_primary'))
  //       .fontSize(HomeConstants.NAV_TITLE_FONT_SIZE_LARGE)
  //       .lineHeight(41)
  //       .fontWeight(700)
  //       .gesture(GestureGroup(GestureMode.Exclusive,
  //         TapGesture({ count: 2 })
  //           .onAction(() => {
  //             console.info('TapGesture 2');
  //             let scroller = AppStorage.get(HomeConstants.CHAT_LIST_SCROLLER) as Scroller;
  //             Logger.debug('Home page title onAction TapGesture 2 scroller is ' + scroller);
  //             scroller.scrollToIndex(0, true);
  //           }),
  //         TapGesture({ count: 1 })
  //           .onAction(() => {
  //             console.info('TapGesture 1'); // ignore
  //           })
  //       ))
  //   }
  // }

  @Builder
  QuickReplyIcon() {
    Row() {
      SymbolGlyph($r("sys.symbol.arrow_left"))
        .fontColor([$r('sys.color.ohos_id_color_text_primary')])
        .fontSize(24)
    }
    .backgroundColor(HomeConstants.MESSAGE_BACKGROUND_COLOR)
      .height(48)
      .width(48)
      .justifyContent(FlexAlign.Center)
      .borderRadius(24)
  }

  @Builder
  MessageContextMenu() {
    Menu() {
      MenuItem({
        startIcon: $r('sys.symbol.arrow_left'),
        content: $r('app.string.reply')
      })
        .onClick(() => {
          this.replyToMessageId = this.selectedMessageId;
          this.getUIContext().getPromptAction().showToast({
            message: $r("app.string.reply_selected"),
            duration: 2000,
            showMode: promptAction.ToastShowMode.DEFAULT,
            bottom: 100
          });
        })

      MenuItem({
        startIcon: $r('sys.symbol.arrowshape_turn_up_right_fill'),
        content: $r('app.string.forward')
      })
        .onClick(() => {
          this.getUIContext().getPromptAction().showToast({
            message: $r("app.string.unsupported_functionality"),
            duration: 2000,
            showMode: promptAction.ToastShowMode.DEFAULT,
            bottom: 100
          });
        })

      MenuItem({
        startIcon: $r('sys.symbol.heart_fill'),
        content: $r('app.string.save_message')
      })
        .onClick(async () => {
          if (!this.me?.chatId) {
            this.getUIContext().getPromptAction().showToast({
              message: 'User is not logged in.',
              duration: 2000,
              showMode: promptAction.ToastShowMode.DEFAULT,
              bottom: 100
            });
            return;
          }
          const result: Array<NativeMessage | undefined> =
            await forwardMessages(parseInt(this.currentChatId), this.me.chatId, [this.selectedMessageId]);
          console.info(JSON.stringify(result));
          const forwardedMessage: NativeMessage | undefined = result.length >= 1 ? result[0] : undefined;
          let success: boolean = forwardedMessage !== undefined && forwardedMessage.messageId > 0;
          this.getUIContext().getPromptAction().showToast({
            message: success ? $r("app.string.message_saved") : $r("app.string.save_message_failed"),
            duration: 2000,
            showMode: promptAction.ToastShowMode.DEFAULT,
            bottom: 100
          });
        })

      MenuItem({
        startIcon: $r('sys.symbol.trash'),
        content: $r('app.string.delete_message')
      })
        .onClick(async () => {
          this.length = await this.messageActions.deleteMessage(
            parseInt(this.currentChatId),
            this.selectedMessageId,
            this.messageDataSource,
            this.getUIContext().getPromptAction(),
          );
        })
    }
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        // Row() {
        //   ChatDetailTopSearch({
        //     currentChatUserName: this.currentChatUserName,
        //   })
        // }
        // .height(Adaptive.ContactItemHeight(this.currentBreakpoint))
        // .expandSafeArea([SafeAreaType.KEYBOARD])
        // .zIndex(1)
        // .backgroundColor($r('app.color.background_color_grey'))

        List({
          initialIndex: this.length - 1,
          scroller: this.messageListScroller
        }) {
          LazyForEach(this.messageDataSource, (item: Message, index: number) => {
            ListItem() {
              ChatDetailItem({
                chatType: this.chatType,
                isAppletMsg: false,
                isDocumentMsg: false,
                message: item,
                messageListScroller: this.messageListScroller,
                showUserName: this.shouldShowUserName(item, index),
              })
            }
              .swipeAction({
                end: {
                  builder: this.QuickReplyIcon,
                  onAction: () => {
                    this.replyToMessageId = item.messageId;
                    this.getUIContext().getPromptAction().showToast({
                      message: $r("app.string.reply_selected"),
                      duration: 2000,
                      showMode: promptAction.ToastShowMode.DEFAULT,
                      bottom: 100
                    });
                  },
                  actionAreaDistance: 80,
                  onEnterActionArea: () => {
                    if (!this.hasReachedSwipeBoundary) {
                      this.hasReachedSwipeBoundary = true;
                      Vibrator.kata();
                      // TODO: fix
                    }
                  },
                  onExitActionArea: () => {
                    this.hasReachedSwipeBoundary = false;
                  }
                },
                edgeEffect: SwipeEdgeEffect.Spring
              })
              .bindContextMenu(this.MessageContextMenu, ResponseType.LongPress, {
                onAppear: () => {
                  this.selectedMessageId = item.messageId;
                }
              })
              .margin({
                top: index === 0 ? this.getChatContentTopSpacerHeight() : 0,
                bottom: index === this.length - 1 ? HomeConstants.NAV_SIGNAL_BAR_HEIGHT : 0
              })
          }, (item: Message) => `${item.chatId}-${item.messageId}`)
        }
        .id('hg-message-list-' + this.currentChatId)
        .height(BaseConstants.FULL_HEIGHT)
          .width(BaseConstants.FULL_WIDTH)
          .padding({
            bottom: "39vp",
          })
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .messageAnimationStyle()
          .onAppear(() => {
            this.messageTransitionEffect = TransitionEffect.move(TransitionEdge.BOTTOM)
              .animation({ curve: curves.springMotion(0.6, 0.8) });
          })
          .cachedCount(BaseConstants.LAZY_FOR_EACH_CACHED_COUNT)
          .onTouch((event: TouchEvent) => {
            if (this.initialMessagesLoaded && (event.type === TouchType.Down || event.type === TouchType.Move)) {
              this.historyPaginationArmed = true;
            }
          })
          .onReachEnd(() => {
            this.isAtEnd = true;
          })
          .onReachStart(() => {
            if (this.historyPaginationArmed) {
              this.historyPaginationArmed = false;
              this.loadHistoryMessagesIfNeeded();
            }
          })
          .onDidScroll((scrollOffset: number, scrollState: ScrollState) => {
            // Logger.debug('ChatDetail onDidScroll scrollOffset: ' + scrollOffset + ' scrollState: ' + scrollState);
            if (this.isScrollingDueToReplyToMessage) {
              if (scrollState === ScrollState.Fling && Math.abs(scrollOffset) < 20) {
                Logger.debug('ChatDetail onDidScroll isScrollingDueToReplyToMessage: ' +
                  this.scrollToRepliedMessageIndex);
                this.isScrollingDueToReplyToMessage = false;

                Logger.debug('ChatDetail onDidScroll isScrollingDueToReplyToMessage smoothly scrollToIndex sub-step 1: ' +
                  (this.scrollToRepliedMessageIndex + BaseConstants.LAZY_FOR_EACH_SCROLL_SMOOTH_BUFFER));
                this.messageListScroller.scrollToIndex(this.scrollToRepliedMessageIndex +
                  BaseConstants.LAZY_FOR_EACH_SCROLL_SMOOTH_BUFFER, false, ScrollAlign.CENTER);

                this.shouldTransferToOnScrollIndex = true;
                this.beforeFinalScrollIndex = this.scrollToRepliedMessageIndex +
                  BaseConstants.LAZY_FOR_EACH_SCROLL_SMOOTH_BUFFER;
                Logger.debug('ChatDetail onDidScroll isScrollingDueToReplyToMessage smoothly scrollToIndex sub-step 1 beforeFinalScrollIndex: ' +
                  this.beforeFinalScrollIndex);
                this.scrollToRepliedMessageIndex = -1;
              }
            }
          })
          .onScrollIndex((start, end, center) => {
            Logger.debug('ChatDetail onScrollIndex start: ' + start + ' end: ' + end + ' center: ' + center);
            if (this.shouldTransferToOnScrollIndex) {
              if (center === this.beforeFinalScrollIndex) {
                this.shouldTransferToOnScrollIndex = false;

                Logger.debug('ChatDetail onScrollIndex isScrollingDueToReplyToMessage smoothly scrollToIndex sub-step 2: ' +
                  this.beforeFinalScrollIndex);
                this.messageListScroller.scrollToIndex(this.beforeFinalScrollIndex -
                  BaseConstants.LAZY_FOR_EACH_SCROLL_SMOOTH_BUFFER, true, ScrollAlign.CENTER);

                this.beforeFinalScrollIndex = -1;
              }
            }
          })

        Row() {
          ChatDetailBottom({
            isShowMediaSheet: this.isShowMediaSheet,
            replyToMessageId: this.replyToMessageId,
          })
        }
        .id('hg-chat-composer-' + this.currentChatId)
      }
      .height(BaseConstants.FULL_HEIGHT)
        .width(BaseConstants.FULL_WIDTH)
    }
    .title({
      builder: () => {
        this.TitleBuilder();
      },
      height: navHeaderGradientHeight(),
    }, {
      backgroundColor: Color.Transparent,
      backgroundBlurStyle: BlurStyle.NONE,
      barStyle: BarStyle.STACK,
    })
      .hideBackButton(true)
      .backgroundColor(Color.Transparent)
      .blur(this.isShowMediaSheet ? this.continuousChatDetailBlurRadius : 0)

    // .animatableBlur(this.discreteChatDetailBlurRadius == 0 ? 0 : this.continuousChatDetailBlurRadius)
  }

  private getChatTitleHeight(): number {
    return HdsHeaderMetrics.NAV_TITLE_BASE_HEIGHT + HdsHeaderMetrics.NAV_TITLE_TOP_PADDING;
  }

  private getHeaderSubtitle(): string {
    if (this.isGroupOrChannel) {
      return 'tap for details';
    }

    return 'last seen a long time ago';
  }

  private getChatContentTopSpacerHeight(): Length {
    return navHeaderGradientHeight() + 10;
  }

  private handleBackNavigation(): void {
    if (this.currentBreakpoint === BreakpointConstants.BREAKPOINT_SM) {
      this.pageInfo.clear();
      return;
    }

    this.pageInfo.clear();
    this.pageInfo.pushPath({ name: 'ChatDetailNone' });
  }

  aboutToAppear(): void {
    // this.navTitleMode = NavigationTitleMode.Mini;
    const dataSource = this.messagesOfChatMap.get(this.currentChatId);
    if (dataSource) {
      this.messageDataSource = dataSource;
    } else {
      this.messageDataSource = new MessageDataSource();
      this.messagesOfChatMap.set(this.currentChatId, this.messageDataSource);
    }
    let chat = this.chatDataSource.get(this.currentChatId);
    this.chatType = chat?.chatType || ChatType.User;
    this.isGroupOrChannel = this.chatType === ChatType.Group || this.chatType === ChatType.Channel;
    // If chatDataSource does not have a name, try reading the username from seenChatsMap.
    if (chat?.name) {
      this.currentChatUserName = chat.name;
    } else {
      try {
        const seenChat = this.seenChatsMap.get(this.currentChatId);
        this.currentChatUserName = seenChat?.fullName || seenChat?.firstName || '';
      } catch (error) {
        Logger.error('ChatDetail aboutToAppear: failed to get seenChat', JSON.stringify(error));
      }
    }
    this.length = this.messageDataSource?.totalCount() || 0;
    this.initialMessagesLoaded = this.length > 0;
    this.historyPaginationArmed = false;
    this.messageActions.markChatRead(parseInt(this.currentChatId));
    this.loadInitialMessagesIfNeeded();
    // this.messages = (this.currentChatPinned ? this.pinnedChatsMap :
    // this.chatsMap).get(this.currentChatId)?.sortedMessages || [];
  }

  aboutToDisappear(): void {
  }

  /**
   * Check whether the username should be shown.
   * Hide the username when adjacent messages are from the same sender within 10 minutes.
   */
  private shouldShowUserName(currentMessage: Message, currentIndex: number): boolean {
    // Do not show usernames for private chats or outgoing messages.
    if (this.chatType === ChatType.User || currentMessage.outgoing) {
      return false;
    }

    // Always show the username for the first message.
    if (currentIndex === 0) return true;

    const previousMessage = this.messageDataSource?.get(currentIndex - 1);
    // does not exist || different senders
    if (!previousMessage || previousMessage.senderId !== currentMessage.senderId)
      return true;

    // 10 min gap
    const timeDiff = currentMessage.timestamp - previousMessage.timestamp;
    if (timeDiff > 600000) return true;

    // TODO: Should sticker's logic be handled here as well?
    return false;
  }

  private async loadHistoryMessagesIfNeeded(): Promise<void> {
    if (!this.initialMessagesLoaded) {
      Logger.debug('ChatDetail loadHistoryMessages: initial messages are not loaded');
      return;
    }

    if (this.isLoadingHistory) {
      Logger.debug('ChatDetail loadHistoryMessages: already loading, skip');
      return;
    }

    if (!this.messageDataSource || this.messageDataSource.totalCount() === 0) {
      Logger.debug('ChatDetail loadHistoryMessages: no messages in current chat');
      return;
    }

    const oldestMessage = this.messageDataSource.oldestMessage();
    const oldestMessageId = oldestMessage?.messageId;

    if (!oldestMessageId) {
      Logger.debug('ChatDetail loadHistoryMessages: cannot get oldest message id');
      return;
    }

    this.isLoadingHistory = true;
    Logger.debug('ChatDetail loadHistoryMessages: loading history before message ' + oldestMessageId);

    try {
      const chatId = parseInt(this.currentChatId);
      const historyMessages: NativeMessage[] = await loadHistoryMessages(chatId, oldestMessageId, 20);

      if (historyMessages.length > 0) {
        Logger.debug('ChatDetail loadHistoryMessages: loaded ' + historyMessages.length + ' history messages');

        // Convert NativeMessage values to Message and add them to the data source.
        const messages = historyMessages.map((nativeMsg: NativeMessage) => Message.fromNative(nativeMsg));
        this.messageDataSource.upsertMany(messages);

        // Update length.
        this.length = this.messageDataSource.totalCount();
        const anchorIndex = this.messageDataSource.indexOf(oldestMessageId);
        if (anchorIndex >= 0) {
          this.messageListScroller.scrollToIndex(anchorIndex, false, ScrollAlign.START);
        }
      } else {
        Logger.debug('ChatDetail loadHistoryMessages: no more history messages');
      }
    } catch (error) {
      Logger.error('ChatDetail loadHistoryMessages: failed to load history: ' + (error as Error).message);
    } finally {
      this.isLoadingHistory = false;
    }
  }

  private async loadInitialMessagesIfNeeded(): Promise<void> {
    if (this.isLoadingHistory) {
      return;
    }
    if (this.messageDataSource.totalCount() > 0) {
      this.initialMessagesLoaded = true;
      return;
    }

    this.isLoadingHistory = true;
    Logger.debug('ChatDetail loadInitialMessages: loading latest messages for chat ' + this.currentChatId);
    try {
      const chatId = parseInt(this.currentChatId);
      const nativeMessages: NativeMessage[] = await loadHistoryMessages(chatId, undefined, 50);
      const messages: Message[] = [];
      for (let i = 0; i < nativeMessages.length; i++) {
        messages.push(Message.fromNative(nativeMessages[i]));
      }
      this.messageDataSource.replaceSnapshot(messages);
      this.length = this.messageDataSource.totalCount();
      this.initialMessagesLoaded = true;
      Logger.debug('ChatDetail loadInitialMessages: loaded ' + this.length + ' messages');
      if (this.length > 0) {
        this.messageListScroller.scrollToIndex(this.length - 1, false, ScrollAlign.END);
      }
    } catch (error) {
      Logger.error('ChatDetail loadInitialMessages: failed to load latest messages: ' + (error as Error).message);
    } finally {
      this.isLoadingHistory = false;
    }
  }

}


