import { BaseConstants, BreakpointConstants, Logger } from '@ohos/base';
import { deviceInfo } from '@kit.BasicServicesKit';
import { curves, promptAction } from '@kit.ArkUI';
import { SeenChat } from '../entities/SeenChat';
import { telegramSyncService } from '../api';
import { ContactsItem } from '../views/Contacts/ContactsItem';
import {
  HeaderFloatingSearchButton,
  HeaderIconButton,
  HeaderGradientBlur,
  HeaderLoadingButton,
  HeaderSearchBar,
  HeaderSearchInput,
  HeaderTitleCapsule,
  HeaderTextButton,
  HdsHeaderMetrics,
  rootHeaderTopPadding
} from '../views/common/HdsHeaderPrimitives';

@Component
export struct Contacts {
  @StorageProp('currentBreakpoint') currentBreakpoint: string = BreakpointConstants.BREAKPOINT_SM;
  @StorageProp('topRectHeight') topRectHeight: number = 0;
  @StorageProp('bottomRectHeight') bottomRectHeight: number = 0;
  @Consume('pageInfo') pageInfo: NavPathStack;
  @Consume currentChatId: string;
  @State contacts: SeenChat[] = [];
  @State loading: boolean = false;
  @State headerHeight: Length = 156;
  @State isSearchExpanded: boolean = false;
  @State searchValue: string = '';
  @State searchCollapseProgress: number = 0;
  @State isShowSearchIcon: boolean = false;
  private scroller: Scroller = new Scroller();
  private readonly floatingTabBarHeight: number = 56;
  private readonly floatingTabBarBottomMargin: number = 8;
  private readonly listBottomBreathingRoom: number = 16;
  private readonly listTopBreathingRoom: number = 20;
  private readonly searchCollapseDistance: number = 96;

  @Builder
  HeaderRow() {
    Row() {
      HeaderTextButton({ text: 'Sort' })
        .width(96)

      HeaderTitleCapsule({
        title: 'Contacts',
        capsuleWidth: BaseConstants.FULL_WIDTH,
        capsuleHeight: HdsHeaderMetrics.ROOT_ACTION_SIZE,
        titleFontSize: HdsHeaderMetrics.ROOT_TITLE_FONT_SIZE,
      })
        .layoutWeight(BaseConstants.LAYOUT_WEIGHT_ONE)
        .margin({ left: 8, right: 8 })

      Row() {
        if (this.loading) {
          HeaderLoadingButton()
        } else {
          HeaderIconButton({
            icon: $r('sys.symbol.plus_square'),
            buttonSize: HdsHeaderMetrics.ROOT_ACTION_SIZE,
            iconSize: 22,
          })
            .onClick(() => {
              this.loadContacts(true);
            })
        }
      }
      .width(96)
      .justifyContent(FlexAlign.End)
    }
    .alignItems(VerticalAlign.Center)
    .width(BaseConstants.FULL_WIDTH)
  }

  @Builder
  CollapsingSearchBar() {
    Column() {
      HeaderSearchBar({ placeholder: 'Search' })
        .onClick(() => {
          if (this.getSearchVisibleFraction() > 0.25) {
            this.isSearchExpanded = true;
          }
        })
    }
    .width(BaseConstants.FULL_WIDTH)
    .height(this.getCollapsedSearchHeight())
    .opacity(this.getSearchVisibleFraction())
    .scale({ x: 1, y: this.getSearchScaleY() })
    .clip(true)
    .margin({ top: this.getCollapsedSearchTopMargin() })
  }

  @Builder
  ExpandedSearchRow() {
    Row({ space: 10 }) {
      HeaderSearchInput({ searchValue: $searchValue })
      HeaderTextButton({ text: 'Cancel', fontSize: 16 })
        .onClick(() => {
          this.isSearchExpanded = false;
          this.searchValue = '';
        })
    }
    .alignItems(VerticalAlign.Center)
    .width(BaseConstants.FULL_WIDTH)
  }

  @Builder
  Header() {
    Stack({ alignContent: Alignment.Top }) {
      HeaderGradientBlur({ materialHeight: this.getTopGradientHeight() })

      Column() {
        if (this.isSearchExpanded) {
          this.ExpandedSearchRow()
        } else {
          this.HeaderRow()
          this.CollapsingSearchBar()
        }
      }
      .width(BaseConstants.FULL_WIDTH)
      .padding({
        left: HdsHeaderMetrics.ROOT_HORIZONTAL_PADDING,
        right: HdsHeaderMetrics.ROOT_HORIZONTAL_PADDING,
        top: rootHeaderTopPadding(this.topRectHeight),
        bottom: HdsHeaderMetrics.ROOT_BOTTOM_PADDING,
      })
    }
    .expandSafeArea([SafeAreaType.SYSTEM])
    .width(BaseConstants.FULL_WIDTH)
    .backgroundColor(Color.Transparent)
  }

  @Builder
  FloatingSearchButton() {
    HeaderFloatingSearchButton({ buttonSize: this.floatingTabBarHeight })
      .onClick(() => {
        this.isSearchExpanded = true;
      })
  }

  build(): void {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        this.Header()
      }
        .zIndex(1)
        .onAreaChange((oldValue: Area, newValue: Area) => {
          this.headerHeight = newValue.height;
        })
      List({ scroller: this.scroller }) {
        ListItem() {
          Row()
            .height(this.getTopSpacerHeight())
            .margin({ bottom: -20 })
            .width(BaseConstants.FULL_WIDTH)
        }

        ListItem() {
          Row({ space: 16 }) {
            SymbolGlyph($r('sys.symbol.person_2'))
              .fontSize(28)
              .fontColor([$r('sys.color.ohos_id_color_emphasize')])
              .width(42)

            Text('Invite Friends')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.ohos_id_color_emphasize'))
              .layoutWeight(BaseConstants.LAYOUT_WEIGHT_ONE)
          }
          .height(56)
          .alignItems(VerticalAlign.Center)
          .padding({
            left: HdsHeaderMetrics.ROOT_HORIZONTAL_PADDING,
            right: HdsHeaderMetrics.ROOT_HORIZONTAL_PADDING
          })
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
            .height(this.getBottomSpacerHeight())
            .width(BaseConstants.FULL_WIDTH)
        }
      }
      .height(BaseConstants.FULL_PERCENT)
      .width(BaseConstants.FULL_WIDTH)
      .onScrollFrameBegin((offset, state) => {
        const result = this.scroller.currentOffset();
        if (offset < 0 && result.yOffset <= 0) {
          this.resetSearchCollapse();
        } else {
          this.updateSearchCollapseProgress(Math.max(0, result.yOffset + offset));
        }
        return { offsetRemain: offset };
      })
      .onDidScroll((scrollOffset: number, scrollState: ScrollState) => {
        this.updateSearchCollapseProgress();
      })
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .animation({ curve: curves.springMotion(0.6, 0.8) })

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
    if (typeof this.headerHeight === 'number') {
      return this.headerHeight + this.listTopBreathingRoom;
    }

    return this.headerHeight;
  }

  private getTopGradientHeight(): number {
    return rootHeaderTopPadding(this.topRectHeight) + HdsHeaderMetrics.ROOT_ACTION_SIZE + 20;
  }

  private getNormalizedSearchProgress(): number {
    return Math.min(1, Math.max(0, this.searchCollapseProgress));
  }

  private getSearchVisibleFraction(): number {
    return 1 - this.getNormalizedSearchProgress();
  }

  private getCollapsedSearchHeight(): number {
    return HdsHeaderMetrics.ROOT_SEARCH_HEIGHT * this.getSearchVisibleFraction();
  }

  private getCollapsedSearchTopMargin(): number {
    return HdsHeaderMetrics.ROOT_SEARCH_TOP_MARGIN * this.getSearchVisibleFraction();
  }

  private getSearchScaleY(): number {
    return Math.max(0.12, this.getSearchVisibleFraction());
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
  }

  private resetSearchCollapse(): void {
    this.searchCollapseProgress = 0;
    this.isShowSearchIcon = false;
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
