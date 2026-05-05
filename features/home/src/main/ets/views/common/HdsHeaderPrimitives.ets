export class HdsHeaderMetrics {
  static readonly ROOT_HORIZONTAL_PADDING: number = 20;
  static readonly ROOT_TOP_BREATHING_ROOM: number = 20;
  static readonly ROOT_MINIMUM_TOP_PADDING: number = 40;
  static readonly ROOT_BOTTOM_PADDING: number = 12;
  static readonly ROOT_TITLE_FONT_SIZE: number = 20;
  static readonly ROOT_TITLE_LINE_HEIGHT: number = 28;
  static readonly ROOT_ACTION_SIZE: number = 42;
  static readonly ROOT_ACTION_GAP: number = 8;
  static readonly ROOT_SEARCH_HEIGHT: number = 42;
  static readonly ROOT_SEARCH_TOP_MARGIN: number = 12;
  static readonly ROOT_FOLDER_HEIGHT: number = 38;
  static readonly ROOT_FOLDER_TOP_MARGIN: number = 10;
  static readonly NAV_ACTION_SIZE: number = 42;
  static readonly NAV_TITLE_BASE_HEIGHT: number = 46;
  static readonly NAV_TITLE_TOP_PADDING: number = 36;
  static readonly NAV_HORIZONTAL_PADDING: number = 20;
}

export class HdsHeaderStyle {
  static readonly FLOATING_FILL: string = '#24FFFFFF';
  static readonly FLOATING_BORDER: string = '#84FFFFFF';
  static readonly SELECTED_FILL: string = '#F8FFFFFF';
  static readonly BADGE_FILL: string = '#22000000';
  static readonly HEADER_GRADIENT_START: string = '#F0FFFFFF';
  static readonly HEADER_GRADIENT_MIDDLE: string = '#D8FFFFFF';
  static readonly HEADER_GRADIENT_END: string = '#00FFFFFF';
  static readonly FLOATING_BLUR_STYLE: BlurStyle = BlurStyle.BACKGROUND_THIN;
}

export function rootHeaderTopPadding(topRectHeight: number): number {
  return Math.max(topRectHeight + HdsHeaderMetrics.ROOT_TOP_BREATHING_ROOM,
    HdsHeaderMetrics.ROOT_MINIMUM_TOP_PADDING);
}

export function navHeaderGradientHeight(): number {
  return HdsHeaderMetrics.NAV_TITLE_TOP_PADDING + HdsHeaderMetrics.NAV_TITLE_BASE_HEIGHT + 18;
}

@Component
export struct HeaderGradientBlur {
  @Prop materialHeight: Length = 96;

  build() {
    Row()
      .width('100%')
      .height(this.materialHeight)
      .linearGradient({
        colors: [
          [HdsHeaderStyle.HEADER_GRADIENT_START, 0],
          [HdsHeaderStyle.HEADER_GRADIENT_MIDDLE, 0.62],
          [HdsHeaderStyle.HEADER_GRADIENT_END, 1],
        ],
        direction: GradientDirection.Bottom,
      })
      .backgroundColor(Color.Transparent)
      .hitTestBehavior(HitTestMode.Transparent)
  }
}

@Component
export struct HeaderIconButton {
  @Prop icon: Resource = $r('sys.symbol.more');
  @Prop buttonSize: number = HdsHeaderMetrics.ROOT_ACTION_SIZE;
  @Prop iconSize: number = 22;

  build() {
    Row() {
      SymbolGlyph(this.icon)
        .fontSize(this.iconSize)
        .fontColor([$r('sys.color.font_primary')])
    }
    .width(this.buttonSize)
    .height(this.buttonSize)
    .borderRadius(this.buttonSize / 2)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundBlurStyle(HdsHeaderStyle.FLOATING_BLUR_STYLE)
    .backgroundColor(HdsHeaderStyle.FLOATING_FILL)
    .border({
      width: 1,
      color: HdsHeaderStyle.FLOATING_BORDER
    })
  }
}

@Component
export struct HeaderLoadingButton {
  @Prop buttonSize: number = HdsHeaderMetrics.ROOT_ACTION_SIZE;

  build() {
    Row() {
      LoadingProgress()
        .width(20)
        .height(20)
    }
    .width(this.buttonSize)
    .height(this.buttonSize)
    .borderRadius(this.buttonSize / 2)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundBlurStyle(HdsHeaderStyle.FLOATING_BLUR_STYLE)
    .backgroundColor(HdsHeaderStyle.FLOATING_FILL)
    .border({
      width: 1,
      color: HdsHeaderStyle.FLOATING_BORDER
    })
  }
}

@Component
export struct HeaderMediaButton {
  @Prop icon: Resource = $r('app.media.ic_public_refresh');
  @Prop buttonSize: number = HdsHeaderMetrics.ROOT_ACTION_SIZE;
  @Prop iconSize: number = 22;

  build() {
    Row() {
      Image(this.icon)
        .width(this.iconSize)
        .height(this.iconSize)
    }
    .width(this.buttonSize)
    .height(this.buttonSize)
    .borderRadius(this.buttonSize / 2)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundBlurStyle(HdsHeaderStyle.FLOATING_BLUR_STYLE)
    .backgroundColor(HdsHeaderStyle.FLOATING_FILL)
    .border({
      width: 1,
      color: HdsHeaderStyle.FLOATING_BORDER
    })
  }
}

@Component
export struct HeaderTextButton {
  @Prop text: ResourceStr = 'Edit';
  @Prop buttonHeight: number = HdsHeaderMetrics.ROOT_ACTION_SIZE;
  @Prop fontSize: number = 16;

  build() {
    Row() {
      Text(this.text)
        .fontSize(this.fontSize)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(this.buttonHeight)
    .borderRadius(this.buttonHeight / 2)
    .padding({
      left: 16,
      right: 16
    })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundBlurStyle(HdsHeaderStyle.FLOATING_BLUR_STYLE)
    .backgroundColor(HdsHeaderStyle.FLOATING_FILL)
    .border({
      width: 1,
      color: HdsHeaderStyle.FLOATING_BORDER
    })
  }
}

@Component
export struct HeaderSearchBar {
  @Prop placeholder: ResourceStr = 'Search';

  build() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(20)
        .fontColor([$r('sys.color.font_secondary')])
      Text(this.placeholder)
        .fontSize(17)
        .fontColor($r('sys.color.font_secondary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(HdsHeaderMetrics.ROOT_SEARCH_HEIGHT)
    .width('100%')
    .borderRadius(HdsHeaderMetrics.ROOT_SEARCH_HEIGHT / 2)
    .padding({
      left: 15,
      right: 15
    })
    .alignItems(VerticalAlign.Center)
    .backgroundBlurStyle(HdsHeaderStyle.FLOATING_BLUR_STYLE)
    .backgroundColor(HdsHeaderStyle.FLOATING_FILL)
    .border({
      width: 1,
      color: HdsHeaderStyle.FLOATING_BORDER
    })
  }
}

@Component
export struct HeaderSearchInput {
  @Link searchValue: string;
  @Prop placeholder: ResourceStr = 'Search';

  build() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(20)
        .fontColor([$r('sys.color.font_secondary')])

      TextInput({
        placeholder: this.placeholder,
        text: this.searchValue
      })
        .fontSize(17)
        .fontColor($r('sys.color.font_primary'))
        .placeholderColor($r('sys.color.font_secondary'))
        .backgroundColor(Color.Transparent)
        .layoutWeight(1)
        .onChange((value: string) => {
          this.searchValue = value;
        })

      if (this.searchValue.length > 0) {
        Row() {
          Text('X')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(24)
        .height(24)
        .borderRadius(12)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor('#66000000')
        .onClick(() => {
          this.searchValue = '';
        })
      }
    }
    .height(HdsHeaderMetrics.ROOT_SEARCH_HEIGHT)
    .layoutWeight(1)
    .borderRadius(HdsHeaderMetrics.ROOT_SEARCH_HEIGHT / 2)
    .padding({
      left: 16,
      right: 12
    })
    .alignItems(VerticalAlign.Center)
    .backgroundBlurStyle(HdsHeaderStyle.FLOATING_BLUR_STYLE)
    .backgroundColor(HdsHeaderStyle.FLOATING_FILL)
    .border({
      width: 1,
      color: HdsHeaderStyle.FLOATING_BORDER
    })
  }
}

@Component
export struct HeaderFloatingSearchButton {
  @Prop buttonSize: number = 56;
  @Prop iconSize: number = 26;

  build() {
    Row() {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(this.iconSize)
        .fontColor([$r('sys.color.font_primary')])
    }
    .width(this.buttonSize)
    .height(this.buttonSize)
    .borderRadius(this.buttonSize / 2)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundBlurStyle(HdsHeaderStyle.FLOATING_BLUR_STYLE)
    .backgroundColor(HdsHeaderStyle.FLOATING_FILL)
    .border({
      width: 1,
      color: HdsHeaderStyle.FLOATING_BORDER
    })
  }
}

@Component
export struct HeaderAvatar {
  @Prop source: Resource = $r('app.media.avatar1');
  @Prop avatarSize: number = 42;

  build() {
    Image(this.source)
      .width(this.avatarSize)
      .height(this.avatarSize)
      .borderRadius(this.avatarSize / 2)
      .backgroundColor($r('app.color.background_color_grey_two'))
  }
}

@Component
export struct HeaderTitleCapsule {
  @Prop title: ResourceStr = '';
  @Prop subtitle: string = '';
  @Prop capsuleWidth: Length = 230;
  @Prop capsuleHeight: number = HdsHeaderMetrics.NAV_TITLE_BASE_HEIGHT;
  @Prop titleFontSize: number = 17;
  @Prop subtitleFontSize: number = 12;

  build() {
    Column() {
      Text(this.title)
        .fontSize(this.titleFontSize)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textAlign(TextAlign.Center)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.subtitle.length > 0) {
        Text(this.subtitle)
          .fontSize(this.subtitleFontSize)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textAlign(TextAlign.Center)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 1 })
      }
    }
    .width(this.capsuleWidth)
    .height(this.capsuleHeight)
    .borderRadius(this.capsuleHeight / 2)
    .padding({ left: 18, right: 18 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundBlurStyle(HdsHeaderStyle.FLOATING_BLUR_STYLE)
    .backgroundColor(HdsHeaderStyle.FLOATING_FILL)
    .border({
      width: 1,
      color: HdsHeaderStyle.FLOATING_BORDER
    })
  }
}

class ChatFolderModel {
  label: string;
  badge: string;

  constructor(label: string, badge: string = '') {
    this.label = label;
    this.badge = badge;
  }
}

@Component
export struct ChatFolderBar {
  @State selectedIndex: number = 0;
  private readonly folders: ChatFolderModel[] = [
    new ChatFolderModel('All'),
    new ChatFolderModel('Personal'),
    new ChatFolderModel('Groups'),
    new ChatFolderModel('Channels'),
    new ChatFolderModel('Bots'),
  ];

  @Builder
  FolderChip(folder: ChatFolderModel, index: number) {
    Row({ space: 6 }) {
      Text(folder.label)
        .fontSize(15)
        .fontWeight(this.selectedIndex === index ? FontWeight.Bold : FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
      if (folder.badge.length > 0) {
        Text(folder.badge)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_secondary'))
          .padding({ left: 6, right: 6 })
          .height(22)
          .borderRadius(11)
          .backgroundColor(HdsHeaderStyle.BADGE_FILL)
      }
    }
    .height(32)
    .padding({ left: 14, right: 14 })
    .borderRadius(16)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundBlurStyle(this.selectedIndex === index ? HdsHeaderStyle.FLOATING_BLUR_STYLE : BlurStyle.NONE)
    .backgroundColor(this.selectedIndex === index ? HdsHeaderStyle.SELECTED_FILL : Color.Transparent)
    .onClick(() => {
      this.selectedIndex = index;
    })
  }

  build() {
    Scroll() {
      Row({ space: 6 }) {
        ForEach(this.folders, (folder: ChatFolderModel, index: number) => {
          this.FolderChip(folder, index);
        }, (folder: ChatFolderModel) => folder.label)
      }
      .height(HdsHeaderMetrics.ROOT_FOLDER_HEIGHT)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 4, right: 4 })
    }
    .height(HdsHeaderMetrics.ROOT_FOLDER_HEIGHT)
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .backgroundBlurStyle(HdsHeaderStyle.FLOATING_BLUR_STYLE)
    .backgroundColor(HdsHeaderStyle.FLOATING_FILL)
    .borderRadius(HdsHeaderMetrics.ROOT_FOLDER_HEIGHT / 2)
    .border({
      width: 1,
      color: HdsHeaderStyle.FLOATING_BORDER
    })
  }
}
