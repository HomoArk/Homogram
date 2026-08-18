export declare enum LoginState {
  WrongPhoneNumber,
  CodeRequired,
  WrongCode,
  PasswordRequired,
  WrongPassword,
  LoggedIn,
  LoginFailure,
}

export declare enum MediaType {
  None,
  Photo,
  Document,
  Sticker,
  Contact,
  Poll,
  Geo,
  Dice,
  Venue,
  GeoLive,
  WebPage,
}

export declare enum ChatType {
  User,
  Group,
  Channel,
}

export declare enum MessageEntityType {
  Unknown,
  Mention,
  Hashtag,
  BotCommand,
  Url,
  Email,
  Bold,
  Italic,
  Code,
  Pre,
  TextUrl,
  MentionName,
  Phone,
  Cashtag,
  Underline,
  Strike,
  Spoiler,
  CustomEmoji,
  Blockquote,
}

export declare enum NativeParticipantRole {
  User,
  Creator,
  Admin,
  Banned,
  Left,
}

export declare enum NativeSendState {
  Pending,
  Sent,
  Failed,
}

export interface StickerInfo {
  emoji?: string;
  isAnimated: boolean;
  isVideo: boolean;
  mimeType?: string;
  fileSize?: number;
  width?: number;
  height?: number;
}

export interface MediaInfo {
  mimeType?: string;
  fileName?: string;
  fileSize?: number;
  width?: number;
  height?: number;
  duration?: number;
}

export interface NativeMessageEntity {
  entityType: MessageEntityType;
  offset: number;
  length: number;
  url?: string;
  userId?: number;
  language?: string;
  customEmojiId?: number;
}

export interface NativeMessage {
  messageId: number;
  chatId: number;
  outgoing: boolean;
  pinned: boolean;
  senderId: number;
  senderName: string;
  timestamp: number;
  text: string;
  viewCount?: number;
  forwardCount?: number;
  replyCount?: number;
  mediaType: MediaType;
  editTimestamp?: number;
  groupedId?: number;
  replyToMessageId?: number;
  fmtEntities?: NativeMessageEntity[];
  stickerInfo?: StickerInfo;
  mediaInfo?: MediaInfo;
  deleted?: boolean;
  sendState?: NativeSendState;
}

export interface NativeChat {
  chatId: number;
  chatType: ChatType;
  name: string;
  pinned: boolean;
  unreadCount?: number;
  readInboxMaxId?: number;
  readOutboxMaxId?: number;
  muted?: boolean;
  archived?: boolean;
  lastMessageId: number;
  lastMessageSenderName: string;
  lastMessageText: string;
  lastMessageTimestamp: number;
  megagroup: boolean;
  forum: boolean;
}

export interface NativePackedChat {
  chatId: number;
  packedChat: string;
}

export interface NativeRawMessage {
  chatId: number;
  messageId: number;
  rawMessage: number[];
}

export interface NativeSeenChat {
  chatId: number;
  chatType: ChatType;
  packedChat: string;
  isContact: boolean;
  isMutualContact: boolean;
  phone?: string;
  username?: string;
  photoThumb?: number[];
  fullName: string;
  firstName: string;
  lastName?: string;
  bio?: string;
  dateOfBirth?: number;
  forum: boolean;
}

export interface NativeParticipant {
  userId: number;
  fullName: string;
  firstName: string;
  lastName?: string;
  username?: string;
  role: NativeParticipantRole;
  photoThumb?: number[];
}

export interface ProfilePhotoPathAndCount {
  current?: string;
  count: number;
}

export declare function isLoggedIn(): Promise<boolean>;
export declare function registerDevice(token: string): Promise<boolean>;
export declare function login(phoneNumber: string): Promise<LoginState>;
export declare function verifyCode(code: string): Promise<LoginState>;
export declare function password(password: string): Promise<LoginState>;
export declare function signOut(): Promise<boolean>;
export declare function run(): Promise<void>;
export declare function stop(): Promise<void>;
export declare function reconnect(): Promise<boolean>;
export declare function getMe(): Promise<NativeSeenChat>;
export declare function loadChats(): Promise<void>;
export declare function loadChatsWithOffset(lastMessageIds: Record<string, number>): Promise<void>;
export declare function loadHistoryMessages(
  chatId: number,
  lastMessageId?: number,
  limit?: number,
): Promise<NativeMessage[]>;
export declare function syncCachesFromLocalDb(
  packedChats: NativePackedChat[],
  chats: NativeChat[],
): Promise<void>;
export declare function sendMessage(
  chatId: number,
  text: string,
  replyTo?: number,
  medias?: string[],
  updateUploadProgressCallback?: (mediaIndex: number, currentProgress: number) => void,
): Promise<NativeMessage[]>;
export declare function forwardMessages(
  fromChatId: number,
  toChatId: number,
  messageIds: number[],
): Promise<Array<NativeMessage | undefined>>;
export declare function downloadMediaFromMessage(chatId: number, messageId: number): Promise<string>;
export declare function downloadProfilePhoto(chatId: number): Promise<string>;
export declare function getProfilePhotoPathAndCount(chatId: number): ProfilePhotoPathAndCount;
export declare function getChatPhotoThumb(chatId: number): Promise<number[] | undefined>;
export declare function getParticipants(chatId: number): Promise<NativeParticipant[]>;
export declare function registerPush(tokenType: number, token: string): Promise<string>;
export declare function unregisterPush(tokenType: number, token: string): Promise<string>;
export declare function registerCacheSeenChatCallback(
  cb: (seenChat: NativeSeenChat) => void | Promise<void>,
): Promise<void>;
export declare function registerUpdateChatCallback(
  cb: (err: Error | null, seenChat: NativeSeenChat, chat: NativeChat, messages: NativeMessage[]) => void | Promise<void>,
): Promise<void>;
export declare function registerIncomingMessageCallback(
  cb: (err: Error | null, chat: NativeChat | undefined, message: NativeMessage) => void | Promise<void>,
): Promise<void>;
export declare function registerLoadChatsCallback(cb: () => void | Promise<void>): Promise<void>;
