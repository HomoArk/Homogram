import { HashMap } from '@kit.ArkTS';
import { BaseConstants, Logger } from '@ohos/base';
import { downloadMediaFromMessage, MediaType, loadHistoryMessages, NativeMessage } from '../../api';
import { MessageDataSource } from '../../viewmodel/Message/MessageDataSource';
import { fileIo as fs, ReadOptions } from '@kit.CoreFileKit';
import { HomeConstants } from '../../constants/HomeConstants';
import { Message } from '../../entities/Message';

@Component
export struct ReplyToPreview {
  @Prop replyToMessageId: number;
  @Consume currentChatId: string;
  @Consume messagesOfChatMap: HashMap<string, MessageDataSource>;
  @State mediaPath: string = "";
  @State isLoadingMessage: boolean = false;
  @State loadFailed: boolean = false;
  @State message: Message | undefined = this.messagesOfChatMap.get(this.currentChatId)?.getMessageById(this.replyToMessageId);

  build() {
    Row() {
      Blank()
        .color(HomeConstants.MESSAGE_REPLY_TO_PREVIEW_DIVIDER_COLOR)
        .width(HomeConstants.MESSAGE_REPLY_TO_PREVIEW_DIVIDER_WIDTH)
        .margin({ left: -2, right: 4, })
      if (this.isLoadingMessage) {
        LoadingProgress()
          .width(20)
          .height(20)
          .margin({ right: 4 })
      } else if (this.loadFailed) {
        Text($r('app.string.load_failed'))
          .fontSize(BaseConstants.FONT_SIZE_FOURTEEN)
          .fontColor($r('sys.color.ohos_id_color_warning'))
          .margin({ right: 4 })
      } else if (this.message?.mediaType === MediaType.Photo) {
        Image("file://" + this.mediaPath)
          .width(30)
          .height(30)
          .objectFit(ImageFit.Auto)
          .borderRadius(4)
          .margin({ right: 4, })
          .onAppear(() => {
            this.mediaPath =
              BaseConstants.BASE_DIR + this.message?.chatId.toString() + "/" + this.message?.messageId.toString() +
                ".jpg";
            const chatId = this.message?.chatId;
            const messageId = this.message?.messageId;
            if (chatId === undefined || messageId === undefined) {
              this.loadFailed = true;
              return;
            }
            if (!fs.accessSync(this.mediaPath)) {
              Logger.debug("ReplyToPreview ImagePreview onAppear: media not exists, downloading media");
              downloadMediaFromMessage(chatId, messageId)
                .then((path) => {
                  Logger.debug("ReplyToPreview ImagePreview onAppear: media downloaded: " + path);
                  this.mediaPath = path;
                })
                .catch((error: Error) => {
                  Logger.debug("ReplyToPreview ImagePreview onAppear Failed to download media: " + error.message);
                });
            } else {
              Logger.debug("ReplyToPreview ImagePreview onAppear: media exists");
            }
          })
      }
      Column() {
        if (this.message) {
          Text(this.message.senderName)
            .fontSize(BaseConstants.FONT_SIZE_FOURTEEN)
            .fontWeight(FontWeight.Bold)
            .fontColor(HomeConstants.MESSAGE_REPLY_TO_PREVIEW_DIVIDER_COLOR)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.message.text === "" ? $r('app.string.photo') : this.message.text)
            .fontSize(BaseConstants.FONT_SIZE_SIXTEEN)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else if (this.isLoadingMessage) {
        } else if (this.loadFailed) {
          Text($r('app.string.reply_message_load_failed'))
            .fontSize(BaseConstants.FONT_SIZE_FOURTEEN)
            .fontColor($r('sys.color.ohos_id_color_warning'))
        } else {
          Text($r('app.string.message_not_found'))
            .fontSize(BaseConstants.FONT_SIZE_FOURTEEN)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
    }
    .alignItems(VerticalAlign.Center)
    .padding(8)
    .backgroundColor(HomeConstants.MESSAGE_REPLY_TO_PREVIEW_BACKGROUND_COLOR)
    .borderRadius(8)
    .width("90%")
    .onAppear(() => {
      this.checkAndLoadMessage();
    })
  }

  /**
   * Check whether the replied message exists, and load history if it does not.
   */
  private async checkAndLoadMessage(): Promise<void> {
    // Refresh the message because data may have changed after the component was created.
    this.message = this.messagesOfChatMap.get(this.currentChatId)?.getMessageById(this.replyToMessageId);
    
    if (this.message) {
      Logger.debug(`ReplyToPreview: message ${this.replyToMessageId} already exists`);
      return;
    }

    if (this.isLoadingMessage) {
      Logger.debug(`ReplyToPreview: already loading message ${this.replyToMessageId}`);
      return;
    }

    Logger.warn(`ReplyToPreview: message ${this.replyToMessageId} not found, loading history messages`);
    this.isLoadingMessage = true;
    this.loadFailed = false;

    try {
      const chatId = parseInt(this.currentChatId);
      
      // Load history that should include the replied message.
      // Load 50 messages before replyToMessageId.
      const historyMessages: NativeMessage[] = await loadHistoryMessages(
        chatId,
        this.replyToMessageId + 50, // Start loading from after the replied message.
        50
      );

      if (historyMessages.length > 0) {
        Logger.debug(`ReplyToPreview: loaded ${historyMessages.length} history messages`);
        
        // Add the loaded messages to the data source.
        const messageDataSource = this.messagesOfChatMap.get(this.currentChatId);
        if (messageDataSource) {
          const messages = historyMessages.map(nativeMsg => Message.fromNative(nativeMsg));
          messageDataSource.upsertMany(messages);
          
          // Fetch the replied message again.
          this.message = messageDataSource.getMessageById(this.replyToMessageId);
          
          if (this.message) {
            Logger.debug(`ReplyToPreview: successfully loaded reply-to message ${this.replyToMessageId}`);
          } else {
            Logger.warn(`ReplyToPreview: reply-to message ${this.replyToMessageId} still not found after loading history`);
            this.loadFailed = true;
          }
        }
      } else {
        Logger.warn(`ReplyToPreview: no history messages loaded for replyToMessageId ${this.replyToMessageId}`);
        this.loadFailed = true;
      }
    } catch (error) {
      Logger.error(`ReplyToPreview: failed to load history messages: ${(error as Error).message}`);
      this.loadFailed = true;
    } finally {
      this.isLoadingMessage = false;
    }
  }
}



