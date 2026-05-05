import { MediaType, NativeMessage, NativeMessageEntity, MessageEntityType, NativeSendState } from 'libhomogrape.so'
import { IComparable } from '@ohos/base'

/**
 * Sticker information.
 */
export class StickerInfo {
  emoji?: string;         // Associated emoji.
  isAnimated: boolean = false;    // Whether this is an animated sticker (TGS).
  isVideo: boolean = false;       // Whether this is a video sticker (WEBM).
  mimeType?: string;      // MIME type.
  fileSize?: number;      // File size.
  width?: number;         // Width.
  height?: number;        // Height.
}

/**
 * Generic media information, such as photos, documents, and videos.
 */
export class MediaInfo {
  mimeType?: string;      // MIME type.
  fileName?: string;      // Original file name.
  fileSize?: number;      // File size in bytes.
  width?: number;         // Width for images and videos.
  height?: number;        // Height for images and videos.
  duration?: number;      // Duration for videos and audio, in seconds.
}

/**
 * Message formatting entity, such as bold, italic, or links.
 */
export class MessageEntity implements NativeMessageEntity {
  entityType: MessageEntityType;
  offset: number;       // UTF-16 offset.
  length: number;       // UTF-16 length.
  url?: string;         // Link for TextUrl.
  userId?: number;      // User ID for MentionName.
  language?: string;    // Language for Pre.
  customEmojiId?: number; // ID for CustomEmoji.

  constructor(
    entityType: MessageEntityType,
    offset: number,
    length: number,
    url?: string,
    userId?: number,
    language?: string,
    customEmojiId?: number
  ) {
    this.entityType = entityType;
    this.offset = offset;
    this.length = length;
    this.url = url;
    this.userId = userId;
    this.language = language;
    this.customEmojiId = customEmojiId;
  }

  public static fromNative(native: NativeMessageEntity): MessageEntity {
    return new MessageEntity(
      native.entityType,
      native.offset,
      native.length,
      native.url,
      native.userId,
      native.language,
      native.customEmojiId
    );
  }
}

export class Message implements NativeMessage, IComparable<Message> {
  chatId: number;
  messageId: number;
  outgoing: boolean;
  pinned: boolean;
  senderId: number;
  senderName: string;
  timestamp: number;
  text: string;
  mediaType: MediaType
  deleted: boolean
  sendState: NativeSendState
  editTimestamp?: number
  groupedId?: number
  replyToMessageId?: number
  viewCount: number
  forwardCount: number
  replyCount: number
  /// Message formatting entities stored as a JSON string.
  fmtEntitiesJson?: string
  /// Formatting entities used at runtime.
  fmtEntities?: MessageEntity[]
  /// Sticker information stored as a JSON string.
  stickerInfoJson?: string
  /// Sticker information used at runtime.
  stickerInfo?: StickerInfo
  /// Generic media information stored as a JSON string.
  mediaInfoJson?: string
  /// Generic media information used at runtime.
  mediaInfo?: MediaInfo

  constructor(chatId: number, messageId: number, outgoing: boolean, pinned: boolean, senderId: number,
    senderName: string, timestamp: number, text: string, mediaType: MediaType, editTimestamp?: number,
    groupedId?: number, replyToMessageId?: number, fmtEntities?: MessageEntity[], stickerInfo?: StickerInfo,
    deleted: boolean = false, sendState: NativeSendState = NativeSendState.Sent) {
    this.chatId = chatId;
    this.messageId = messageId;
    this.outgoing = outgoing;
    this.pinned = pinned;
    this.senderId = senderId;
    this.senderName = senderName;
    this.timestamp = timestamp;
    this.text = text;
    this.mediaType = mediaType;
    this.deleted = deleted;
    this.sendState = sendState;
    this.editTimestamp = editTimestamp || -1;
    this.groupedId = groupedId || -1;
    this.replyToMessageId = replyToMessageId || -1;
    this.replyCount = 0;
    this.forwardCount = 0;
    this.viewCount = 0;
    this.fmtEntities = fmtEntities;
    this.stickerInfo = stickerInfo;
    // Note: fromNative handles JSON serialization by serializing the raw NAPI object directly.
    // The constructor no longer serializes class instances, avoiding class-instance serialization issues.
  }

  public static fromNative(nativeMessage: NativeMessage): Message {
    // Convert formatting entities.
    let fmtEntities: MessageEntity[] | undefined;
    if (nativeMessage.fmtEntities && nativeMessage.fmtEntities.length > 0) {
      console.warn(`[FMTENTITIES] fromNative: converting ${nativeMessage.fmtEntities.length} entities from NAPI, first entity raw: ${JSON.stringify(nativeMessage.fmtEntities[0])}`);
      fmtEntities = nativeMessage.fmtEntities.map((e: NativeMessageEntity): MessageEntity => MessageEntity.fromNative(e));
      console.warn(`[FMTENTITIES] fromNative: first entity converted: ${JSON.stringify(fmtEntities ? fmtEntities[0] : null)}`);
    }

    const msg = new Message(
      nativeMessage.chatId,
      nativeMessage.messageId,
      nativeMessage.outgoing,
      nativeMessage.pinned,
      nativeMessage.senderId,
      nativeMessage.senderName,
      nativeMessage.timestamp,
      nativeMessage.text,
      nativeMessage.mediaType,
      nativeMessage.editTimestamp,
      nativeMessage.groupedId,
      nativeMessage.replyToMessageId,
      fmtEntities,
      nativeMessage.stickerInfo as StickerInfo | undefined,
      nativeMessage.deleted ?? false,
      nativeMessage.sendState ?? NativeSendState.Sent
    );

    msg.viewCount = nativeMessage.viewCount ?? 0;
    msg.forwardCount = nativeMessage.forwardCount ?? 0;
    msg.replyCount = nativeMessage.replyCount ?? 0;

    // Serialize the raw NAPI object directly to avoid class-instance serialization issues.
    // This keeps data intact during database round trips.
    if (nativeMessage.fmtEntities && nativeMessage.fmtEntities.length > 0) {
      msg.fmtEntitiesJson = JSON.stringify(nativeMessage.fmtEntities);
      console.warn(`[FMTENTITIES] fromNative: serialized ${nativeMessage.fmtEntities.length} entities from NAPI`);
    }
    if (nativeMessage.stickerInfo) {
      msg.stickerInfoJson = JSON.stringify(nativeMessage.stickerInfo);
      console.warn(`[STICKER] fromNative: serialized stickerInfo for messageId=${msg.messageId}`);
    } else {
      console.warn(`[STICKER] fromNative: no stickerInfo for messageId=${msg.messageId}`);
    }
    if (nativeMessage.mediaInfo) {
      msg.mediaInfoJson = JSON.stringify(nativeMessage.mediaInfo);
      console.warn(`[MEDIA] fromNative: serialized mediaInfo for messageId=${msg.messageId}`);
    }

    return msg;
  }

  /**
   * Deserialize fmtEntities, stickerInfo, and mediaInfo after loading from the database.
   */
  public deserializeFmtEntities(): void {
    console.error(`============ [DESERIALIZE START] messageId=${this.messageId} ============`);
    console.error(`[DESERIALIZE] fmtEntitiesJson: type=${typeof this.fmtEntitiesJson}, length=${this.fmtEntitiesJson?.length ?? 'undefined'}`);
    if (this.fmtEntitiesJson) {
      console.error(`[DESERIALIZE] fmtEntitiesJson value: ${this.fmtEntitiesJson.substring(0, 150)}`);
    }
    console.error(`[DESERIALIZE] stickerInfoJson: type=${typeof this.stickerInfoJson}, length=${this.stickerInfoJson?.length ?? 'undefined'}`);
    console.error(`[DESERIALIZE] mediaInfoJson: type=${typeof this.mediaInfoJson}, length=${this.mediaInfoJson?.length ?? 'undefined'}`);
    if (this.mediaInfoJson) {
      console.error(`[DESERIALIZE] mediaInfoJson value: ${this.mediaInfoJson.substring(0, 150)}`);
    }

    if (this.fmtEntitiesJson && this.fmtEntitiesJson.length > 0) {
      try {
        this.fmtEntities = JSON.parse(this.fmtEntitiesJson) as MessageEntity[];
        console.error(`[DESERIALIZE] 鉁?Successfully parsed ${this.fmtEntities.length} fmtEntities`);
      } catch (e) {
        console.error(`[DESERIALIZE] 鉁?Failed to parse fmtEntitiesJson: ${e}`);
        this.fmtEntities = undefined;
      }
    } else {
      console.error(`[DESERIALIZE] 鉁?No fmtEntitiesJson to deserialize`);
    }

    if (this.stickerInfoJson && this.stickerInfoJson.length > 0) {
      try {
        this.stickerInfo = JSON.parse(this.stickerInfoJson) as StickerInfo;
        console.error(`[DESERIALIZE] 鉁?Successfully parsed stickerInfo`);
      } catch (e) {
        console.error(`[DESERIALIZE] 鉁?Failed to parse stickerInfoJson: ${e}`);
        this.stickerInfo = undefined;
      }
    }

    if (this.mediaInfoJson && this.mediaInfoJson.length > 0) {
      try {
        this.mediaInfo = JSON.parse(this.mediaInfoJson) as MediaInfo;
        console.error(`[DESERIALIZE] 鉁?Successfully parsed mediaInfo`);
      } catch (e) {
        console.error(`[DESERIALIZE] 鉁?Failed to parse mediaInfoJson: ${e}`);
        this.mediaInfo = undefined;
      }
    }
    console.error(`============ [DESERIALIZE END] messageId=${this.messageId} ============`);
  }

  /**
   * Check whether the message contains formatted content.
   */
  public hasFormatting(): boolean {
    return this.fmtEntities !== undefined && this.fmtEntities.length > 0;
  }

  /**
   * Get all entities of the specified type.
   */
  public getEntitiesByType(type: MessageEntityType): MessageEntity[] {
    if (!this.fmtEntities) return [];
    return this.fmtEntities.filter(e => e.entityType === type);
  }

  compareTo(other: Message): number {
    if (this.messageId > 0 && other.messageId > 0 && this.messageId !== other.messageId) {
      return this.messageId - other.messageId;
    }
    if (this.messageId < 0 && other.messageId < 0 && this.messageId !== other.messageId) {
      return other.messageId - this.messageId;
    }
    if (this.timestamp !== other.timestamp) {
      return this.timestamp - other.timestamp;
    }
    return this.messageId - other.messageId;
  }
}
