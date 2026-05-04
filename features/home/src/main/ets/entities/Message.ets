import { MediaType, NativeMessage, NativeMessageEntity, MessageEntityType, NativeSendState } from 'libhomogrape.so'
import { IComparable } from '@ohos/base'

/**
 * Sticker 淇℃伅
 */
export class StickerInfo {
  emoji?: string;         // 鍏宠仈鐨?emoji
  isAnimated: boolean = false;    // 鏄惁涓哄姩鐢?sticker (TGS)
  isVideo: boolean = false;       // 鏄惁涓鸿棰?sticker (WEBM)
  mimeType?: string;      // MIME 绫诲瀷
  fileSize?: number;      // 鏂囦欢澶у皬
  width?: number;         // 瀹藉害
  height?: number;        // 楂樺害
}

/**
 * 閫氱敤濯掍綋淇℃伅锛圥hoto銆丏ocument銆乂ideo 绛夛級
 */
export class MediaInfo {
  mimeType?: string;      // MIME 绫诲瀷
  fileName?: string;      // 鍘熷鏂囦欢鍚?
  fileSize?: number;      // 鏂囦欢澶у皬锛堝瓧鑺傦級
  width?: number;         // 瀹藉害锛堝浘鐗?瑙嗛锛?
  height?: number;        // 楂樺害锛堝浘鐗?瑙嗛锛?
  duration?: number;      // 鏃堕暱锛堣棰?闊抽锛岀锛?
}

/**
 * 娑堟伅鏍煎紡鍖栧疄浣擄紙绮椾綋銆佹枩浣撱€侀摼鎺ョ瓑锛?
 */
export class MessageEntity implements NativeMessageEntity {
  entityType: MessageEntityType;
  offset: number;       // UTF-16 鍋忕Щ閲?
  length: number;       // UTF-16 闀垮害
  url?: string;         // TextUrl 鐨勯摼鎺?
  userId?: number;      // MentionName 鐨勭敤鎴?ID
  language?: string;    // Pre 鐨勮瑷€
  customEmojiId?: number; // CustomEmoji 鐨?ID

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
  /// 娑堟伅鏍煎紡鍖栧疄浣擄紙绮椾綋銆佹枩浣撱€侀摼鎺ョ瓑锛? 瀛樺偍涓?JSON 瀛楃涓?
  fmtEntitiesJson?: string
  /// 杩愯鏃朵娇鐢ㄧ殑鏍煎紡鍖栧疄浣撴暟缁?
  fmtEntities?: MessageEntity[]
  /// Sticker 淇℃伅 - 瀛樺偍涓?JSON 瀛楃涓?
  stickerInfoJson?: string
  /// 杩愯鏃朵娇鐢ㄧ殑 Sticker 淇℃伅
  stickerInfo?: StickerInfo
  /// 閫氱敤濯掍綋淇℃伅 - 瀛樺偍涓?JSON 瀛楃涓?
  mediaInfoJson?: string
  /// 杩愯鏃朵娇鐢ㄧ殑濯掍綋淇℃伅
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
    // Note: JSON 搴忓垪鍖栫敱 fromNative 缁熶竴澶勭悊锛岀洿鎺ュ簭鍒楀寲 NAPI 鍘熷瀵硅薄
    // 鏋勯€犲嚱鏁颁笉鍐嶅簭鍒楀寲锛岄伩鍏嶇被瀹炰緥搴忓垪鍖栭棶棰?
  }

  public static fromNative(nativeMessage: NativeMessage): Message {
    // 杞崲鏍煎紡鍖栧疄浣?
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

    // 鐩存帴搴忓垪鍖栧師濮?NAPI 瀵硅薄锛岄伩鍏嶇被瀹炰緥搴忓垪鍖栭棶棰?
    // 杩欐牱鍙互纭繚鏁版嵁鍦ㄦ暟鎹簱寰€杩旇繃绋嬩腑涓嶄涪澶?
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
   * 浠庢暟鎹簱鍔犺浇鍚庯紝鍙嶅簭鍒楀寲 fmtEntities銆乻tickerInfo 鍜?mediaInfo
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
   * 妫€鏌ユ秷鎭槸鍚﹀寘鍚牸寮忓寲鍐呭
   */
  public hasFormatting(): boolean {
    return this.fmtEntities !== undefined && this.fmtEntities.length > 0;
  }

  /**
   * 鑾峰彇鎸囧畾绫诲瀷鐨勬墍鏈夊疄浣?
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
