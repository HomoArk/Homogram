import { BaseConstants, BreakpointConstants, Logger } from '@ohos/base';
import { ParticipantItem } from '../../../views/Chat/ParticipantItem';
import { ChatDataSource } from '../../../viewmodel/Chat/ChatDataSource';
import { getParticipants, NativeParticipant } from '../../../api';
import { deviceInfo } from '@kit.BasicServicesKit';
import { curves } from '@kit.ArkUI';
import {
  HeaderGradientBlur,
  HeaderIconButton,
  HeaderTitleCapsule,
  HdsHeaderMetrics,
  navHeaderGradientHeight
} from '../../../views/common/HdsHeaderPrimitives';

@Component
export struct ParticipantList {
  @StorageProp('currentBreakpoint') currentBreakpoint: string = BreakpointConstants.BREAKPOINT_SM;
  @Consume('pageInfo') pageInfo: NavPathStack;
  @Consume chatDataSource: ChatDataSource;
  @Consume currentChatId: string;
  @State participants: NativeParticipant[] = [];
  @State isLoading: boolean = true;
  @State errorMessage: string = '';
  @State chatName: string = '';
  @State participantCount: number = 0;
  private scroller: Scroller = new Scroller();

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
            this.pageInfo.pop();
          })

        HeaderTitleCapsule({
          title: this.chatName.length > 0 ? this.chatName : 'Members',
          subtitle: this.participantCount > 0 ? this.participantCount.toString() : '',
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
      .height(BaseConstants.FULL_HEIGHT)
      .width(BaseConstants.FULL_WIDTH)
      .padding({
        left: HdsHeaderMetrics.NAV_HORIZONTAL_PADDING,
        right: HdsHeaderMetrics.NAV_HORIZONTAL_PADDING,
        top: HdsHeaderMetrics.NAV_TITLE_TOP_PADDING,
      })
    }
    .height(BaseConstants.FULL_HEIGHT)
    .width(BaseConstants.FULL_WIDTH)
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(48)
              .height(48)
            Text($r('app.string.loading'))
              .fontSize(BaseConstants.FONT_SIZE_SIXTEEN)
              .fontColor(Color.Grey)
              .margin({ top: 16 })
          }
          .width(BaseConstants.FULL_WIDTH)
          .height(BaseConstants.FULL_HEIGHT)
          .justifyContent(FlexAlign.Center)
        } else if (this.errorMessage.length > 0) {
          Column() {
            SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
              .fontSize(48)
              .fontColor([$r('sys.color.ohos_id_color_warning')])
            Text(this.errorMessage)
              .fontSize(BaseConstants.FONT_SIZE_SIXTEEN)
              .fontColor($r('sys.color.font_secondary'))
              .margin({ top: 16 })
              .textAlign(TextAlign.Center)
            Button($r('app.string.retry'))
              .margin({ top: 24 })
              .onClick(() => {
                this.loadParticipants();
              })
          }
          .width(BaseConstants.FULL_WIDTH)
          .height(BaseConstants.FULL_HEIGHT)
          .justifyContent(FlexAlign.Center)
          .padding({ left: 24, right: 24 })
        } else {
          List({ scroller: this.scroller }) {
            ListItem() {
              Row()
                .height(this.getContentTopSpacerHeight())
                .width(BaseConstants.FULL_WIDTH)
            }

            ForEach(this.participants, (participant: NativeParticipant, index: number) => {
              ListItem() {
                ParticipantItem({
                  participant: participant
                })
                  .onClick(() => {
                    // TODO: Open the participant profile page when tapped.
                    Logger.debug('ParticipantList: clicked participant ' + participant.userId);
                  })
              }
            }, (participant: NativeParticipant, index: number) => index + '_' + participant.userId.toString())

            ListItem() {
              Row()
                .height((this.currentBreakpoint === BreakpointConstants.BREAKPOINT_LG ||
                  this.currentBreakpoint === BreakpointConstants.BREAKPOINT_XL) ?
                  BaseConstants.FULL_PERCENT :
                  (deviceInfo.deviceType === BaseConstants.DEVICE_TYPES[0] ? $r('app.float.tab_size_lg') :
                  $r('app.float.tab_size')))
                .width(BaseConstants.FULL_WIDTH)
            }
          }
          .height(BaseConstants.FULL_PERCENT)
          .cachedCount(BaseConstants.LAZY_FOR_EACH_CACHED_COUNT)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .scrollBar(BarState.Off)
          .animation({ curve: curves.springMotion(0.6, 0.8) })
        }
      }
      .expandSafeArea([SafeAreaType.SYSTEM])
      .height(BaseConstants.FULL_HEIGHT)
      .width(BaseConstants.FULL_WIDTH)
    }
    .title({
      builder: () => {
        this.TitleBuilder();
      },
      height: HdsHeaderMetrics.NAV_TITLE_BASE_HEIGHT + HdsHeaderMetrics.NAV_TITLE_TOP_PADDING,
    }, {
      backgroundColor: Color.Transparent,
      barStyle: BarStyle.STANDARD,
    })
    .hideBackButton(true)
    .expandSafeArea([SafeAreaType.SYSTEM])
  }

  aboutToAppear(): void {
    const chat = this.chatDataSource.get(this.currentChatId);
    this.chatName = chat?.name || '';
    this.loadParticipants();
  }

  private async loadParticipants(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';
    
    try {
      const chatId = parseInt(this.currentChatId);
      Logger.debug('ParticipantList: loading participants for chat ' + chatId);
      
      const participants = await getParticipants(chatId);
      
      Logger.debug('ParticipantList: loaded ' + participants.length + ' participants');
      this.participants = participants;
      this.participantCount = participants.length;
    } catch (error) {
      Logger.error('ParticipantList: failed to load participants: ' + (error as Error).message);
      this.errorMessage = (error as Error).message;
    } finally {
      this.isLoading = false;
    }
  }

  private getContentTopSpacerHeight(): Length {
    return HdsHeaderMetrics.NAV_TITLE_BASE_HEIGHT + HdsHeaderMetrics.NAV_TITLE_TOP_PADDING + 16;
  }
}



