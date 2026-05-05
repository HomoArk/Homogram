import { BaseConstants, BreakpointConstants, DateHelper, Logger, NormalText } from '@ohos/base'
import {
  MediaType,
  downloadMediaFromMessage,
  // getProfilePhotoPathAndCount,
  NativeSeenChat,
  // downloadProfilePhoto,
  ChatType,
} from '../../api';
import { webview } from '@kit.ArkWeb';
import { util } from '@kit.ArkTS';
import { HomeConstants } from '../../constants/HomeConstants';
import { Message, MessageEntity } from '../../entities/Message';
import { fileIo as fs } from '@kit.CoreFileKit';
import { HashMap } from '@kit.ArkTS';
import { SeenChat } from '../../entities/SeenChat';
import { getOrDownloadProfilePhoto, getThumbProfilePhotoPixelMap } from '../../utils';
import { ReplyToPreview } from './ReplyToPreview'
import { MessageDataSource } from '../../viewmodel/Message/MessageDataSource';
import { MediaModel, MediaPreviewOptions } from '@lyb/media-preview';
import { BusinessError, zlib } from '@kit.BasicServicesKit';
import { filePreview } from '@kit.PreviewKit';
import { applyEntityStyle } from './FmtEntities';
import { LengthMetrics, LengthUnit } from '@ohos.arkui.node';
import { Lottie, LottieController } from '@jjr/lottie_component';

enum DefaultMediaType {
  IMAGE,
  VIDEO
}

class DefaultMediaModel extends MediaModel {
  /**
   * Type.
   */
  type: DefaultMediaType = DefaultMediaType.IMAGE
  /**
   * Source image.
   */
  sourceSrc?: ResourceStr
  /**
   * Thumbnail.
   */
  thumbSrc?: ResourceStr

  constructor(sourceSrc?: ResourceStr, thumbSrc?: ResourceStr, type: DefaultMediaType = DefaultMediaType.IMAGE) {
    super();
    this.sourceSrc = sourceSrc
    this.thumbSrc = thumbSrc
    this.type = type
  }
}

@Component
export struct MessageBubble {
  @StorageProp('currentBreakpoint') currentBreakpoint: string = BreakpointConstants.BREAKPOINT_SM;
  avatar1: Resource = $r('app.media.avatar1');
  avatar2: Resource = $r('app.media.avatar7');
  @Consume me: NativeSeenChat | undefined;
  @Consume seenChatsMap: HashMap<string, SeenChat>;
  @Consume messagesOfChatMap: HashMap<string, MessageDataSource>;
  @Consume('pageInfo') pageInfo: NavPathStack;
  @State mediaPath: string = "";
  @State decompressedMediaPath: string = ""; // Decompressed file path (TGS -> JSON).
  @State mediaLoaded: boolean = false;
  @State mediaLoadFailed: boolean = false;
  @State profilePhotoPath: string | undefined = undefined;
  @State profilePhotoLoaded: boolean = false;
  @State profilePhotoLoadFailed: boolean = false;
  @State profilePhotoPixelMap: PixelMap | undefined = undefined;
  @State mediaPreviewIndex: number = -1;
  @State mediaResources: DefaultMediaModel[] = [];
  @State styledString: StyledString | undefined = undefined;
  @Consume currentChatId: string;
  @Consume isScrollingDueToReplyToMessage: boolean;
  @Consume scrollToRepliedMessageIndex: number;
  @State lottieJson: string = "{}";
  @State videoBase64: string = ""; // Base64-encoded video data.
  @Prop showUserName: boolean = true;
  private lottieController: LottieController = new LottieController();
  private stickerWebviewController: webview.WebviewController = new webview.WebviewController();
  private incomingBorderRadius: LocalizedBorderRadiuses = {
    topStart: new LengthMetrics(0, LengthUnit.VP),
    topEnd: new LengthMetrics(HomeConstants.PATH_BORDER_RADIUS, LengthUnit.VP),
    bottomStart: new LengthMetrics(HomeConstants.PATH_BORDER_RADIUS, LengthUnit.VP),
    bottomEnd: new LengthMetrics(HomeConstants.PATH_BORDER_RADIUS, LengthUnit.VP),
  };
  private outgoingBorderRadius: LocalizedBorderRadiuses = {
    topEnd: new LengthMetrics(0, LengthUnit.VP),
    topStart: new LengthMetrics(HomeConstants.PATH_BORDER_RADIUS, LengthUnit.VP),
    bottomStart: new LengthMetrics(HomeConstants.PATH_BORDER_RADIUS, LengthUnit.VP),
    bottomEnd: new LengthMetrics(HomeConstants.PATH_BORDER_RADIUS, LengthUnit.VP),
  };
  messageListScroller?: ListScroller;
  chatType: ChatType = ChatType.User;
  private content: string = "";
  private isAppletMsg?: boolean = false;
  private isDocumentMsg?: boolean = false;
  textController: TextController = new TextController();
  message?= new Message(
    1,
    1,
    false,
    false,
    1,
    "John Doe",
    Date.now(),
    "Hello, World!",
    MediaType.None,
    0,
    0,
    0,
  );
  private mediaPreviewOptions: MediaPreviewOptions = new MediaPreviewOptions()
    .setBackgroundColor(Color.Black)
    .setPageChangedListener((_item, index) => {
      this.mediaPreviewIndex = index;
    })
    .setBackListener(() => {
      this.mediaPreviewIndex = -1;
    })
    .setLongPressListener((_item, index) => {
      console.log(`MessageBubble Media 长按了第${index + 1}个资源`);
    })// TODO: A custom id can be used here.
    .setIdBuilder((_item, index) => {
      return `media_${index}`
    })// TODO: Set thumb to improve the shared-element transition effect.
    .setThumbBuilder((item, index) => {
      this.Media(item as DefaultMediaModel, index)
    });

  build() {
    Column() {
      Flex({
        justifyContent: !this.message?.outgoing ? FlexAlign.Start : FlexAlign.End,
        direction: FlexDirection.Row
      }) {
        if ((!this.message?.outgoing) && (this.chatType != ChatType.User)) {
          Image("file://" + this.profilePhotoPath)
            .alt("用户头像 / User avatar [i18n]")
            .width(HomeConstants.PROFILE_PHOTO_SIZE_SMALL)
            .height(HomeConstants.PROFILE_PHOTO_SIZE_SMALL)
            .flexShrink(BaseConstants.FLEX_SHRINK_ZERO)
            .clipShape(new Circle({
              width: HomeConstants.PROFILE_PHOTO_SIZE_SMALL,
              height: HomeConstants.PROFILE_PHOTO_SIZE_SMALL
            }))
            .onAppear(() => {
              getOrDownloadProfilePhoto(this.message?.senderId || 0)
                .then((path) => {
                  this.profilePhotoPath = path;
                  this.profilePhotoLoaded = true;
                });
            })
            .onClick(() => {
              const id = this.message?.senderId;
              if (!id) {
                return;
              }

              this.getUIContext().showActionSheet({
                title: this.message?.senderName ?? '用户',
                message: '',
                autoCancel: true,
                alignment: DialogAlignment.Bottom,
                sheets: [
                  {
                    title: $r('app.string.send_message'),
                    action: () => {
                      // Jump to the chat page with this user.
                      this.currentChatId = id.toString();
                      // Ensure the message data source exists for this chat.
                      if (!this.messagesOfChatMap.hasKey(id.toString())) {
                        this.messagesOfChatMap.set(id.toString(), new MessageDataSource());
                      }
                      // Ensure seenChatsMap has user information for the title.
                      if (!this.seenChatsMap.hasKey(id.toString())) {
                        // Create a temporary SeenChat object.
                        const tempSeenChat = new SeenChat(
                          id,
                          ChatType.User,
                          "", // packedChat
                          false, // isContact
                          false, // isMutualContact
                          this.message?.senderName || "User", // fullName
                          this.message?.senderName || "User", // firstName
                          false// forum
                        );
                        this.seenChatsMap.set(id.toString(), tempSeenChat);
                      }
                      this.pageInfo.pushPath({ name: 'ChatDetail' });
                    }
                  },
                  {
                    title: $r('app.string.view_profile'),
                    action: () => {
                      this.pageInfo.pushPath({ name: "ProfilePage", param: id });
                    }
                  }
                ],
              });
            })
        }
        Column() {
          Stack({ alignContent: !this.message?.outgoing ? Alignment.TopStart : Alignment.TopEnd }) {
            Column() {
              if (this.showUserName && (!this.message?.outgoing) && (this.chatType != ChatType.User) &&
                (this.message?.mediaType !== MediaType.Sticker)) {
                this.SenderName(this.message?.senderName ?? "")
              }

              Column() {
                // reply to message
                if (this.message?.replyToMessageId && this.message?.replyToMessageId != -1) {
                  ReplyToPreview({
                    replyToMessageId: this.message?.replyToMessageId
                  })
                    .alignSelf(!this.message?.outgoing ? ItemAlign.Start : ItemAlign.End)
                    .margin({
                      top: HomeConstants.MESSAGE_REPLY_TO_PREVIEW_TOP_MARGIN,
                    })
                    .onClick(() => {
                      Logger.debug("ReplyToPreview onClick: " + this.message?.replyToMessageId + " currentChatId: " +
                        this.currentChatId);
                      let target_index =
                        this.messagesOfChatMap.get(this.currentChatId)?.indexOf(this.message?.replyToMessageId || -1);
                      Logger.debug("ReplyToPreview onClick: target_index: " + target_index);
                      let current_index =
                        this.messagesOfChatMap.get(this.currentChatId)?.indexOf(this.message?.messageId || -1);
                      Logger.debug("ReplyToPreview onClick: current_index: " + current_index);

                      if (target_index === undefined || target_index < 0 || target_index === null) {
                        Logger.error("ReplyToPreview onClick: error, index is " + target_index);
                        return;
                      }
                      if (current_index - target_index > BaseConstants.LAZY_FOR_EACH_SCROLL_INDEX_LIMIT) {
                        Logger.debug("ReplyToPreview onClick: gap is too large, scroll to target in two steps");
                        this.isScrollingDueToReplyToMessage = true;
                        this.scrollToRepliedMessageIndex = target_index;
                        this.messageListScroller?.scrollToIndex(current_index -
                          BaseConstants.LAZY_FOR_EACH_SCROLL_INDEX_LIMIT +
                          BaseConstants.LAZY_FOR_EACH_SCROLL_SMOOTH_BUFFER,
                          true,
                          ScrollAlign.CENTER);
                        Logger.debug("ReplyToPreview onClick: scrollToIndex first step: " +
                          (current_index -
                            BaseConstants.LAZY_FOR_EACH_SCROLL_INDEX_LIMIT +
                            BaseConstants.LAZY_FOR_EACH_SCROLL_SMOOTH_BUFFER));
                      } else {
                        Logger.debug("ReplyToPreview onClick: scroll to target in one step");
                        this.messageListScroller?.scrollToIndex(target_index, true, ScrollAlign.CENTER);
                      }
                    })
                    .alignSelf(ItemAlign.Start)
                }
                if (this.message?.mediaType === MediaType.Photo) {
                  List({ space: 10 }) {
                    ForEach(this.mediaResources, (item: DefaultMediaModel, index: number) => {
                      ListItem() {
                        this.Media(item, index)
                      }
                      // TODO: Set an id, otherwise the shared-element transition will not appear.
                      .id(this.mediaPreviewOptions.idBuilder(item, index))
                        // TODO: Set this manually when list and media preview data models differ; keep it aligned with setIdBuilder above.
                        .id(`media_${index}`)
                        // .aspectRatio(1)
                        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
                        // TODO: Hide the original resource while previewing, similar to WeChat.
                        .visibility(index == this.mediaPreviewIndex ? Visibility.Hidden : Visibility.Visible)
                        .onClick(() => {
                          Logger.debug("MessageBubble Media onClick: " + index);
                          // this.mediaPreviewOptions
                          //   .setInitIndex(index)
                          //   .setMedias(this.mediaResources);
                          // MediaPreview.open(this.getUIContext(), this.mediaPreviewOptions);
                          let uiContext = getContext(this);
                          let displayInfo: filePreview.DisplayInfo = {
                            x: 100,
                            y: 100,
                            width: 800,
                            height: 800
                          };
                          let fileInfo: filePreview.PreviewInfo = {
                            uri: "file://" + uiContext.applicationInfo.name + this.mediaPath,
                            mimeType: 'image/jpeg'
                          };
                          filePreview.openPreview(uiContext, fileInfo, displayInfo).then(() => {
                            console.info('Succeeded in opening preview');
                          }).catch((err: BusinessError) => {
                            console.error(`Failed to open preview, err.code = ${err.code}, err.message = ${err.message}`);
                          });
                        })
                    }, (item: DefaultMediaModel, index: number) => JSON.stringify(item) + index)
                  }
                }

                // Show video for document messages with a video/* MIME type.
                if (this.message?.mediaType === MediaType.Document &&
                  this.message?.mediaInfo?.mimeType?.startsWith('video/')) {
                  this.VideoView()
                }

                // Show sticker.
                if (this.message?.mediaType === MediaType.Sticker) {
                  this.StickerView()
                }

                // Show other document types, such as audio and generic files.
                if (this.message?.mediaType === MediaType.Document &&
                  !this.message?.mediaInfo?.mimeType?.startsWith('video/')) {
                  this.DocumentView()
                }

                this.MessageContent()

                Row() {
                  Blank()
                  if (this.message?.viewCount && this.message.viewCount > 0) {
                    Text(`󰄠 ${this.message.viewCount}  `)
                      .fontSize(BaseConstants.FONT_SIZE_TWELVE)
                      .fontColor(HomeConstants.MESSAGE_TIME_COLOR)
                      .fontFamily("HarmonyOS Sans Condensed")
                  }
                  Text(DateHelper.getParsedDateString(this.message?.timestamp))
                    .fontSize(BaseConstants.FONT_SIZE_TWELVE)
                    .fontColor(HomeConstants.MESSAGE_TIME_COLOR)
                    .fontFamily("HarmonyOS Sans Condensed")
                  if (this.message?.outgoing) {
                    Text(' ')
                    Text() {
                      SymbolSpan($r('sys.symbol.checkmark_circle'))
                    }
                    // .fontColor(HomeConstants.MESSAGE_TIME_COLOR)
                    .fontSize(BaseConstants.FONT_SIZE_TWELVE)
                  }
                }
                .alignSelf(ItemAlign.End)
              }
              .alignSelf(ItemAlign.Start)
            }
            .padding({
              left: 8,
              right: 8,
              top: 8,
              bottom: 8
            })
              .backgroundColor(this.shouldHideBubble() ? Color.Transparent :
                (!this.message?.outgoing ? HomeConstants.MESSAGE_BACKGROUND_COLOR :
                  HomeConstants.MESSAGE_BACKGROUND_COLOR_OUTGOING))
              .borderRadius(this.message?.outgoing ? this.outgoingBorderRadius : this.incomingBorderRadius)
          }
          .padding({
            top: 5,
            bottom: 5
          })
            .width(BaseConstants.NINETY_WIDTH_PERCENT)
        }
        .width(BaseConstants.NINETY_WIDTH_PERCENT)

        // if (this.message?.outgoing) {
        // Image("file://" + this.profilePhotoPath)
        //   .width(HomeConstants.PROFILE_PHOTO_SIZE_SMALL)
        //   .height(HomeConstants.PROFILE_PHOTO_SIZE_SMALL)
        //   .flexShrink(BaseConstants.FLEX_SHRINK_ZERO)
        //   .clipShape(new Circle({
        //     width: HomeConstants.PROFILE_PHOTO_SIZE_SMALL,
        //     height: HomeConstants.PROFILE_PHOTO_SIZE_SMALL
        //   }))
        //   .onAppear(() => {
        //     // getThumbProfilePhotoPixelMap(this.me?.chatId.toString(), this.seenChatsMap)
        //     //   .then((pixelMap) => {
        //     //     this.profilePhotoPixelMap = pixelMap;
        //     //   })
        //     //   .catch((e: Error) => {
        //     //     Logger.error("ChatDetailItem: failed to create pixel map: " + e);
        //     //   });
        //     getOrDownloadProfilePhoto(this.me?.chatId || 0)
        //       .then((path) => {
        //         this.profilePhotoPath = path;
        //         this.profilePhotoLoaded = true;
        //       })
        //       .catch((error: Error) => {
        //         Logger.error("ChatDetailItem: failed to get or download profile photo: " + error);
        //         this.profilePhotoLoadFailed = true;
        //       });
        //   })
        // }
      }
      .flexShrink(BaseConstants.FLEX_SHRINK_ONE)
    }
    .margin({ left: 5, right: 5 })
  }

  aboutToAppear(): void {
    if (this.mediaResources.length == 0) {
      this.loadMedia();
      this.mediaResources = [
        new DefaultMediaModel(this.mediaPath, this.mediaPath)
      ];
    }
    // Build StyledString for rich-text rendering.
    console.warn(`[FMTENTITIES] MessageBubble messageId=${this.message?.messageId} || count: ${this.message?.fmtEntities?.length ??
      0} || text: "${this.message?.text?.substring(0, 50)}"`);
    if (this.message?.fmtEntities && this.message.fmtEntities.length > 0) {
      console.warn(`[FMTENTITIES] MessageBubble fmtEntities: ${JSON.stringify(this.message.fmtEntities)}`);
    }
    this.buildStyledString();
  }

  /**
   * Build StyledString from fmtEntities for rich-text display.
   */
  private buildStyledString(): void {
    const text = this.message?.text ?? '';
    if (text.length === 0) {
      this.styledString = undefined;
      console.warn(`[FMTENTITIES] buildStyledString: empty text, skipping`);
      return;
    }

    const entities = this.message?.fmtEntities;
    if (!entities || entities.length === 0) {
      // No formatting entities: render regular text without StyledString.
      this.styledString = undefined;
      console.warn(`[FMTENTITIES] buildStyledString: no entities for message ${this.message?.messageId}`);
      return;
    }

    console.warn(`[FMTENTITIES] buildStyledString: creating StyledString for message ${this.message?.messageId}`);
    console.warn(`[FMTENTITIES] buildStyledString: entities count=${entities.length}, entities: ${JSON.stringify(entities)}`);

    // Create a mutable styled string.
    const mutableStyledString = new MutableStyledString(text);

    // Apply styles for all formatting entities.
    for (let i = 0; i < entities.length; i++) {
      const entity = entities[i];
      try {
        console.warn(`[FMTENTITIES] buildStyledString: applying entity ${i}: ${JSON.stringify(entity)}`);
        applyEntityStyle(this.message?.text ?? "", mutableStyledString, entity);
        console.warn(`[FMTENTITIES] buildStyledString: entity ${i} applied successfully`);
      } catch (e) {
        console.warn(`[FMTENTITIES] buildStyledString: failed to apply entity ${i}: ${JSON.stringify(entity)}, error: ${e}`);
      }
    }

    this.styledString = mutableStyledString;
    console.warn(`[FMTENTITIES] buildStyledString: StyledString created successfully for message ${this.message?.messageId}`);
  }

  @Builder
  StickerOnlyView() {
    Flex({
      justifyContent: !this.message?.outgoing ? FlexAlign.Start : FlexAlign.End,
      direction: FlexDirection.Row
    }) {
      this.StickerView()
    }
    .margin({
      left: 5,
      right: 5,
      top: 2,
      bottom: 2
    })
  }

  @Builder
  VideoView() {
    Stack() {
      Video({
        src: "file://" + this.mediaPath
      })
        .width(300)
        .height(200)
        .autoPlay(false)
        .controls(true)
        .objectFit(ImageFit.Contain)
        .onError(() => {
          Logger.error(`Video load error: ${this.mediaPath}`);
          this.mediaLoadFailed = true;
        })
        .onStart(() => {
          Logger.debug(`Video started playing: ${this.mediaPath}`);
        })

      // Loading state.
      if (!this.mediaLoaded && !this.mediaLoadFailed) {
        Loading()
      }

      // Error state.
      if (this.mediaLoadFailed) {
        Column() {
          Text($r('app.string.load_failed'))
            .fontColor(Color.Red)
            .fontSize(BaseConstants.FONT_SIZE_TWELVE)
          Text($r('app.string.retry'))
            .fontSize(BaseConstants.FONT_SIZE_TEN)
            .fontColor(Color.Gray)
        }
        .onClick(() => this.loadMedia())
      }
    }
    .width(300)
      .height(200)
      .onAppear(() => {
        this.loadMedia();
      })
  }

  @Builder
  StickerView() {
    Stack() {
      // Prefer stickerInfo when available, then infer from the file path.
      if ((this.message?.stickerInfo?.isAnimated || this.mediaPath.endsWith('.tgs')) && this.lottieJson.length > 7) {
        // Animated sticker (TGS format - Lottie).
        // The TGS file has been decompressed to JSON.
        Lottie({
          autoPlay: true,
          controller: this.lottieController,
          animationData: JSON.parse(this.lottieJson) as Object,
          loop: true,
        })
          .width(160)
          .height(160)
      } else if (this.message?.stickerInfo?.isVideo || this.mediaPath.endsWith('.webm')) {
        // Video sticker (WEBM), displayed with the Web component.
        Web({
          src: 'about:blank',
          controller: this.stickerWebviewController,
          renderMode: RenderMode.SYNC_RENDER
        })
          .width(160)
          .height(160)
          .backgroundColor(Color.Transparent)
          .domStorageAccess(false)
          .mixedMode(MixedMode.All)
          .cacheMode(CacheMode.None)
          .mediaPlayGestureAccess(true)
          .fileAccess(true)
          .onAppear(() => {
            try {
              // Load HTML that contains a video tag through the file:// protocol.
              if (this.mediaPath && this.mediaLoaded) {
                Logger.debug(`[ARKWEB] Loading video from: ${this.mediaPath}`);
                const html = this.generateStickerVideoHtml();
                // Load HTML with loadData and enable file access.
                this.stickerWebviewController.loadData(
                  html,
                  'text/html',
                  'UTF-8',
                  ' ',
                  ' '
                );
              }
            } catch (e) {
              Logger.error(`[ARKWEB] Failed to load sticker video: ${e}`);
            }
          })
      } else {
        // Static sticker (WEBP).
        Image("file://" + this.mediaPath)
          .width(150)
          .height(150)
          .objectFit(ImageFit.Contain)
          .interpolation(ImageInterpolation.High)
          .alt(this.message?.stickerInfo?.emoji ?? "Sticker")
      }

      // Loading state.
      if (!this.mediaLoaded && !this.mediaLoadFailed) {
        Loading()
      }

      // Error state.
      if (this.mediaLoadFailed) {
        Column() {
          Text($r('app.string.load_failed'))
            .fontColor($r('app.color.color_danger'))
            .fontSize(BaseConstants.FONT_SIZE_TWELVE)
          Text($r('app.string.retry'))
            .fontSize(BaseConstants.FONT_SIZE_TEN)
            .fontColor($r('sys.color.font_secondary'))
        }
        .onClick(() => this.loadMedia())
      }
    }
    .width(150)
      .height(150)
      .margin({ bottom: 8 })
      .onAppear(() => {
        this.loadMedia();
      })
  }

  @Builder
  DocumentView() {
    Column() {
      Row() {
        // File icon.
        Text() {
          if (this.message?.mediaInfo?.mimeType?.startsWith('audio/')) {
            SymbolSpan($r('sys.symbol.music_fill'))
          } else if (this.message?.mediaInfo?.mimeType?.includes('pdf')) {
            SymbolSpan($r('sys.symbol.doc_text_fill'))
          } else if (this.message?.mediaInfo?.mimeType?.includes('word') ||
            this.message?.mediaInfo?.mimeType?.includes('document')) {
            SymbolSpan($r('sys.symbol.doc_text_fill'))
          } else if (this.message?.mediaInfo?.mimeType?.includes('excel') ||
            this.message?.mediaInfo?.mimeType?.includes('spreadsheet')) {
            SymbolSpan($r('sys.symbol.square_grid_2x2'))
          } else if (this.message?.mediaInfo?.mimeType?.includes('zip') ||
            this.message?.mediaInfo?.mimeType?.includes('rar') ||
            this.message?.mediaInfo?.mimeType?.includes('compressed')) {
            SymbolSpan($r('sys.symbol.folder_fill'))
          } else {
            SymbolSpan($r('sys.symbol.doc_text'))
          }
        }
        .fontSize(40)
          .margin({ right: 12 })

        // File information.
        Column() {
          Text(this.message?.mediaInfo?.fileName ?? '未知文件')
            .fontSize(BaseConstants.FONT_SIZE_FOURTEEN)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.formatFileSize(this.message?.mediaInfo?.fileSize ?? 0))
            .fontSize(BaseConstants.FONT_SIZE_TWELVE)
            .fontColor($r('sys.color.font_secondary'))
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
      }
      .width('100%')
        .padding(12)
        .backgroundColor(Color.White)
        .borderRadius(8)
    }
    .width(280)
      .margin({ bottom: 8 })
  }

  @Builder
  MessageContent() {
    if (this.styledString && this.message?.text && this.message.text.length > 0) {
      // Render rich text with StyledString.
      // Show raw text first, then apply styles through the controller.
      Text(this.message.text, { controller: this.textController })
        .fontSize(BaseConstants.FONT_SIZE_SIXTEEN)
        .fontFamily(BaseConstants.FONT_FAMILY_NORMAL)
        .fontWeight(BaseConstants.FONT_WEIGHT_FOUR)
        .lineHeight($r('app.float.chat_default_text_line'))
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .copyOption(CopyOptions.LocalDevice)
        .alignSelf(ItemAlign.Start)
        .onAppear(() => {
          // Delay until layout is ready.
          setTimeout(() => {
            if (this.styledString) {
              try {
                this.textController.setStyledString(this.styledString);
              } catch (e) {
                Logger.error(`Failed to set styled string: ${e}`);
              }
            }
          }, 16); // Wait one frame.
        })
    } else {
      // Regular text rendering.
      Text(this.message?.text)
        .fontSize(BaseConstants.FONT_SIZE_SIXTEEN)
        .fontFamily(BaseConstants.FONT_FAMILY_NORMAL)
        .fontWeight(BaseConstants.FONT_WEIGHT_FOUR)
        .lineHeight($r('app.float.chat_default_text_line'))
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .copyOption(CopyOptions.LocalDevice)
        .alignSelf(ItemAlign.Start)
    }
  }

  @Builder
  Media(item: DefaultMediaModel, index: number) {
    Stack() {
      Image("file://" + item.thumbSrc)
        .objectFit(ImageFit.Auto)
        .margin({ bottom: $r('app.float.applet_image_bottom') })
        .borderRadius(5)
        .clip(true)
        .alt("媒体缩略图 / Media thumbnail [i18n]")
        .onError((e) => {
          this.mediaLoaded = false;
          this.mediaLoadFailed = true;
        })
        .draggable(true)
        .allowDrop(null)
      Image($r('app.media.play'))
        .width('30vp')
        .height('30vp')
        .fillColor(Color.White)
        .visibility(item.type == DefaultMediaType.VIDEO ? Visibility.Visible : Visibility.None)
      if (!this.mediaLoaded) {
        if (this.mediaLoadFailed) {
          Text("Retry")
            .fontColor($r('app.color.color_danger'))
            .fontSize(BaseConstants.FONT_SIZE_FOURTEEN)
            .fontWeight(FontWeight.Bold)
            .lineHeight(`21fp`)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .onClick(() => {
              this.loadMedia()
            })
        } else {
          Loading()
        }
      }
    }
    .alignSelf(ItemAlign.Start)
      .onAppear(() => {
        this.loadMedia();
      })
  }

  async loadMedia(): Promise<void> {
    this.mediaLoaded = false;
    this.mediaLoadFailed = false;

    // Determine the file extension from mediaInfo or stickerInfo.
    let extension = ".jpg"; // Default extension.

    // Prefer stickerInfo for sticker media.
    if (this.message?.mediaType === MediaType.Sticker) {
      if (this.message?.stickerInfo) {
        if (this.message.stickerInfo.isVideo) {
          extension = ".webm";
        } else if (this.message.stickerInfo.isAnimated) {
          extension = ".tgs";
        } else {
          extension = ".webp";
        }
      } else if (this.message?.mediaInfo?.mimeType) {
        // Fallback: infer from mediaInfo.mimeType.
        const mime = this.message.mediaInfo.mimeType;
        if (mime === 'video/webm' || mime.startsWith('video/')) {
          extension = ".webm";
        } else if (mime === 'application/x-tgsticker') {
          extension = ".tgs";
        } else {
          extension = ".webp";
        }
      } else {
        extension = ".webp";
      }
    } else if (this.message?.mediaInfo?.mimeType) {
      // Use the MIME type from mediaInfo.
      extension = this.getExtensionFromMimeType(this.message.mediaInfo.mimeType);
    } else if (this.message?.mediaInfo?.fileName) {
      // Use the extension from the file name.
      extension = this.getExtensionFromFileName(this.message.mediaInfo.fileName);
    }

    this.mediaPath =
      BaseConstants.BASE_DIR + this.message?.chatId.toString() + "/" + this.message?.messageId.toString() + extension;

    // download the media if not exists
    try {
      // For stickers, try alternative extensions when the file does not exist.
      if (!fs.accessSync(this.mediaPath) && this.message?.mediaType === MediaType.Sticker) {
        const basePath = BaseConstants.BASE_DIR + this.message?.chatId.toString() + "/" + this.message?.messageId.toString();
        const alternatives = ['.webm', '.tgs', '.webp'];
        let found = false;

        for (const alt of alternatives) {
          if (alt !== extension) {
            const altPath = basePath + alt;
            if (fs.accessSync(altPath)) {
              this.mediaPath = altPath;
              extension = alt;
              found = true;
              break;
            }
          }
        }

        if (found) {
          // Update lottieJson when a .tgs file is found.
          if (extension === '.tgs') {
            const jsonPath = this.mediaPath.replace(".tgs", ".json");
            if (fs.accessSync(jsonPath)) {
              try {
                const file = fs.openSync(jsonPath, fs.OpenMode.READ_ONLY);
                const stat = fs.statSync(jsonPath);
                const buffer = new ArrayBuffer(stat.size);
                fs.readSync(file.fd, buffer);
                fs.closeSync(file);

                const bytes = new Uint8Array(buffer);
                let jsonContent = '';
                for (let i = 0; i < bytes.length; i++) {
                  jsonContent += String.fromCharCode(bytes[i]);
                }

                this.lottieJson = jsonContent;
                this.mediaLoaded = true;
                Logger.info(`[MEDIA] Loaded existing TGS JSON from alternative path`);
                return;
              } catch (e) {
                Logger.error(`[MEDIA] Failed to load TGS JSON: ${e}`);
              }
            }
          }
          // For other types, mark the media as loaded directly.
          this.mediaLoaded = true;
          return;
        }
      }

      if (!fs.accessSync(this.mediaPath)) {
        try {
          const chatId = this.message?.chatId;
          const messageId = this.message?.messageId;
          if (chatId === undefined || messageId === undefined) {
            throw new Error('MessageBubble media download requires chatId and messageId');
          }
          Logger.info(`[MEDIA] Downloading media: chatId=${chatId}, messageId=${messageId}`);
          const path = await downloadMediaFromMessage(chatId, messageId);
          this.mediaPath = path;
          // Verify that the file exists.
          if (fs.accessSync(path)) {
            const stat = fs.statSync(path);
            Logger.warn(`[MEDIA] File downloaded successfully, size: ${stat.size} bytes`);
          } else {
            Logger.error(`[MEDIA] Downloaded file not found: ${path}`);
          }
          // TGS files need to be decompressed to JSON.
          if (extension === ".tgs") {
            await this.decompressTgsFile(path);
          } else {
            this.mediaLoaded = true;
          }
        } catch (error) {
          Logger.error(`[MEDIA] Download failed: ${error}`);
          this.mediaLoadFailed = true;
          throw new Error(`Download failed: ${error}`); // Throw an Error object.
        }
      } else {
        // For TGS files, check whether they have already been decompressed.
        if (extension === ".tgs") {
          const jsonPath = this.mediaPath.replace(".tgs", ".json");
          if (fs.accessSync(jsonPath)) {
            this.decompressedMediaPath = jsonPath;

            // Read JSON file content.
            try {
              const file = fs.openSync(jsonPath, fs.OpenMode.READ_ONLY);
              const stat = fs.statSync(jsonPath);
              const buffer = new ArrayBuffer(stat.size);
              fs.readSync(file.fd, buffer);
              fs.closeSync(file);

              // Convert to string.
              const bytes = new Uint8Array(buffer);
              let jsonContent = '';
              for (let i = 0; i < bytes.length; i++) {
                jsonContent += String.fromCharCode(bytes[i]);
              }

              this.lottieJson = jsonContent;
              this.mediaLoaded = true;
            } catch (readErr) {
              Logger.error(`[TGSJSON] Failed to read TGS JSON: ${readErr}`);
              this.decompressTgsFile(this.mediaPath);
            }
          } else {
            this.decompressTgsFile(this.mediaPath);
          }
        } else {
          this.mediaLoaded = true;
        }
      }
    } catch (error) {
      console.error(error);
    }
  }

  /**
   * Decompress a TGS file to JSON.
   * TGS files are gzip-compressed Lottie JSON animations.
   */
  private async decompressTgsFile(tgsPath: string): Promise<void> {
    const jsonPath = tgsPath.replace(".tgs", ".json");

    try {
      const checksum = await zlib.createGZip();
      await checksum.gzopen(tgsPath, "rb");

      // Preallocate a large enough buffer. TGS files are usually smaller than 1 MB.
      const bufferSize = 1024 * 1024; // 1MB
      const buffer = new ArrayBuffer(bufferSize);
      const bytesRead = await checksum.gzread(buffer);
      await checksum.gzcloser();

      if (bytesRead > 0) {
        const bytes = new Uint8Array(buffer, 0, bytesRead);
        let jsonContent = '';
        for (let i = 0; i < bytes.length; i++) {
          jsonContent += String.fromCharCode(bytes[i]);
        }

        const file = await fs.open(jsonPath, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.WRITE_ONLY);
        await fs.write(file.fd, jsonContent);
        await fs.close(file);

        Logger.debug(`[TGSJSON] JSON written to file: ${jsonPath}`);

        this.lottieJson = jsonContent;
        this.decompressedMediaPath = jsonPath;
        this.mediaLoaded = true;
      } else {
        this.mediaLoadFailed = true;
      }
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(`[TGSJSON] Exception during gzip decompression: code=${error.code}, msg=${error.message}`);
      this.mediaLoadFailed = true;
    }
  }

  /**
   * Check whether the bubble background should be hidden.
   * Stickers and videos without text do not show bubbles.
   */
  private shouldHideBubble(): boolean {
    // Stickers never show bubbles.
    if (this.message?.mediaType === MediaType.Sticker) {
      return true;
    }

    // Videos without text do not show bubbles.
    if (this.message?.mediaType === MediaType.Document &&
      this.message?.mediaInfo?.mimeType?.startsWith('video/')) {
      const hasText = this.message?.text && this.message.text.trim().length > 0;
      return !hasText;
    }

    return false;
  }

  /**
   * Infer the file extension from the MIME type.
   */
  private getExtensionFromMimeType(mimeType: string): string {
    const mimeMap: Record<string, string> = {
      'image/jpeg': '.jpg',
      'image/jpg': '.jpg',
      'image/png': '.png',
      'image/gif': '.gif',
      'image/webp': '.webp',
      'video/mp4': '.mp4',
      'video/webm': '.webm',
      'video/quicktime': '.mov',
      'video/x-matroska': '.mkv',
      'audio/mpeg': '.mp3',
      'audio/mp3': '.mp3',
      'audio/ogg': '.ogg',
      'audio/wav': '.wav',
      'audio/aac': '.aac',
      'application/pdf': '.pdf',
      'application/x-tgsticker': '.tgs',
      'application/zip': '.zip',
      'application/x-rar-compressed': '.rar',
    };

    // Direct match.
    if (mimeMap[mimeType]) {
      return mimeMap[mimeType];
    }

    // Prefix match.
    if (mimeType.startsWith('video/')) {
      return '.mp4';
    }
    if (mimeType.startsWith('audio/')) {
      return '.mp3';
    }
    if (mimeType.startsWith('image/')) {
      return '.jpg';
    }

    return '.bin'; // Unknown type.
  }

  /**
   * Extract the extension from a file name.
   */
  private getExtensionFromFileName(fileName: string): string {
    const parts = fileName.split('.');
    if (parts.length > 1) {
      const ext = parts[parts.length - 1];
      // Validate that the extension length is reasonable.
      if (ext.length > 0 && ext.length < 10) {
        return '.' + ext;
      }
    }
    return '.bin';
  }

  /**
   * Format the file size.
   */
  private formatFileSize(bytes: number): string {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }



  /**
   * Generate HTML used to display video stickers.
   * Optimized for 512x512 WebM stickers.
   * Load local video through the file:// protocol.
   */
  private generateStickerVideoHtml(): string {
    const videoPath = this.mediaPath;
    const html = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        html, body {
            width: 100%;
            height: 100%;
            overflow: hidden;
            background: transparent;
        }
        video {
            width: 100%;
            height: 100%;
            object-fit: contain;
            display: block;
        }
    </style>
</head>
<body>
    <video autoplay loop muted playsinline>
        <source src="file://${videoPath}" type="video/webm">
        Your browser does not support WebM video.
    </video>
</body>
</html>
`;
    return html;
  }

  @Builder
  SenderName(senderName: string) {
    Row() {
      Text(senderName)
        .fontSize(BaseConstants.FONT_SIZE_FOURTEEN)
        .fontWeight(FontWeight.Bold)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Start)
      Blank()
    }
    .padding({ bottom: 2 })
      .alignSelf(ItemAlign.Start)
  }
}

@Builder
  function Loading() {
  LoadingProgress()
    .color(Color.Blue)
    .layoutWeight(1)
    .size({
      width: "18vp",
      height: "18vp"
    })
}
