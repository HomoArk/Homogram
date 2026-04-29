import {
  ChatType,
  downloadMediaFromMessage as nativeDownloadMediaFromMessage,
  downloadProfilePhoto as nativeDownloadProfilePhoto,
  forwardMessages as nativeForwardMessages,
  getChatPhotoThumb as nativeGetChatPhotoThumb,
  getMe as nativeGetMe,
  getParticipants as nativeGetParticipants,
  getProfilePhotoPathAndCount as nativeGetProfilePhotoPathAndCount,
  isLoggedIn as nativeIsLoggedIn,
  loadChatsWithOffset as nativeLoadChatsWithOffset,
  loadHistoryMessages as nativeLoadHistoryMessages,
  LoginState,
  login as nativeLogin,
  MediaType,
  NativeChat,
  NativeMessage,
  NativeMessageEntity,
  MessageEntityType,
  NativePackedChat,
  NativeParticipant,
  NativeParticipantRole,
  NativeRawMessage,
  NativeSeenChat,
  password as nativePassword,
  reconnect as nativeReconnect,
  registerCacheSeenChatCallback as nativeRegisterCacheSeenChatCallback,
  registerDevice as nativeRegisterDevice,
  registerIncomingMessageCallback as nativeRegisterIncomingMessageCallback,
  registerPush as nativeRegisterPush,
  registerUpdateChatCallback as nativeRegisterUpdateChatCallback,
  run as nativeRun,
  sendMessage as nativeSendMessage,
  signOut as nativeSignOut,
  stop as nativeStop,
  syncCachesFromLocalDb as nativeSyncCachesFromLocalDb,
  unregisterPush as nativeUnregisterPush,
  verifyCode as nativeVerifyCode,
} from 'libhomogrape.so';

export {
  ChatType,
  LoginState,
  MediaType,
  MessageEntityType,
  NativeChat,
  NativeMessage,
  NativeMessageEntity,
  NativePackedChat,
  NativeParticipant,
  NativeParticipantRole,
  NativeRawMessage,
  NativeSeenChat,
};

export type IncomingMessageCallback = (err: Error | null, chat: NativeChat | undefined, message: NativeMessage) => Promise<void>;
export type UpdateChatCallback = (err: Error | null, seenChat: NativeSeenChat, chat: NativeChat, messages: NativeMessage[]) => Promise<void>;

export interface ProfilePhotoPathAndCount {
  current?: string;
  count: number;
}

export interface TelegramBridgeEvents {
  onSeenChatCached?: (seenChat: NativeSeenChat) => void | Promise<void>;
  onChatUpdated?: (seenChat: NativeSeenChat, chat: NativeChat, messages: NativeMessage[]) => void | Promise<void>;
  onIncomingMessage?: (chat: NativeChat | undefined, message: NativeMessage) => void | Promise<void>;
}

class TelegramBridge {
  private started: boolean = false;
  private callbacksRegistered: boolean = false;
  private events: TelegramBridgeEvents = {};

  async initialize(events: TelegramBridgeEvents): Promise<void> {
    this.events = events;
    if (this.callbacksRegistered) {
      return;
    }

    const onSeenChatCached = this.toCacheSeenChatCallback();
    const onChatUpdated = this.toUpdateChatCallback();
    const onIncomingMessage = this.toIncomingMessageCallback();

    await nativeRegisterCacheSeenChatCallback(onSeenChatCached);
    await nativeRegisterUpdateChatCallback(onChatUpdated);
    await nativeRegisterIncomingMessageCallback(onIncomingMessage);
    this.callbacksRegistered = true;
  }

  async isLoggedIn(): Promise<boolean> {
    return nativeIsLoggedIn();
  }

  async registerDevice(token: string): Promise<boolean> {
    return nativeRegisterDevice(token);
  }

  async login(phoneNumber: string): Promise<LoginState> {
    return nativeLogin(phoneNumber);
  }

  async verifyCode(code: string): Promise<LoginState> {
    return nativeVerifyCode(code);
  }

  async password(password: string): Promise<LoginState> {
    return nativePassword(password);
  }

  async signOut(): Promise<boolean> {
    this.started = false;
    return nativeSignOut();
  }

  async startSync(): Promise<void> {
    if (this.started) {
      return;
    }
    await nativeRun();
    this.started = true;
  }

  async stopSync(): Promise<void> {
    if (!this.started) {
      return;
    }
    await nativeStop();
    this.started = false;
  }

  async reconnect(): Promise<boolean> {
    return nativeReconnect();
  }

  async getMe(): Promise<NativeSeenChat> {
    return nativeGetMe();
  }

  async loadChatsWithOffset(lastMessageIds: Record<string, number>): Promise<void> {
    await nativeLoadChatsWithOffset(lastMessageIds);
  }

  async loadHistoryMessages(chatId: number, beforeMessageId?: number, limit?: number): Promise<NativeMessage[]> {
    return nativeLoadHistoryMessages(chatId, beforeMessageId, limit);
  }

  async syncCachesFromLocalDb(packedChats: NativePackedChat[], chats: NativeChat[]): Promise<void> {
    await nativeSyncCachesFromLocalDb(packedChats, chats);
  }

  async sendMessage(
    chatId: number,
    text: string,
    replyTo?: number,
    medias?: string[],
    onUploadProgress?: (mediaIndex: number, currentProgress: number) => void,
  ): Promise<NativeMessage[]> {
    const callback = (mediaIndex: number, currentProgress: number) => {
      onUploadProgress?.(mediaIndex, currentProgress);
    };
    return nativeSendMessage(chatId, text, replyTo, medias, callback);
  }

  async forwardMessages(fromChatId: number, toChatId: number, messageIds: number[]): Promise<Array<NativeMessage | undefined>> {
    const messages = await nativeForwardMessages(fromChatId, toChatId, messageIds);
    return messages.map((message: NativeMessage | null | undefined): NativeMessage | undefined => message ?? undefined);
  }

  async downloadMediaFromMessage(chatId: number, messageId: number): Promise<string> {
    return nativeDownloadMediaFromMessage(chatId, messageId);
  }

  async downloadProfilePhoto(chatId: number): Promise<string> {
    return nativeDownloadProfilePhoto(chatId);
  }

  getProfilePhotoPathAndCount(chatId: number): ProfilePhotoPathAndCount {
    return nativeGetProfilePhotoPathAndCount(chatId);
  }

  async getChatPhotoThumb(chatId: number): Promise<number[] | undefined> {
    const thumb = await nativeGetChatPhotoThumb(chatId);
    return thumb ?? undefined;
  }

  async getParticipants(chatId: number): Promise<NativeParticipant[]> {
    return nativeGetParticipants(chatId);
  }

  async registerPush(tokenType: number, token: string): Promise<string> {
    return nativeRegisterPush(tokenType, token);
  }

  async unregisterPush(tokenType: number, token: string): Promise<string> {
    return nativeUnregisterPush(tokenType, token);
  }

  private toCacheSeenChatCallback(): (seenChat: NativeSeenChat) => Promise<void> {
    return async (seenChat: NativeSeenChat) => {
      await this.events.onSeenChatCached?.(seenChat);
    };
  }

  private toUpdateChatCallback(): UpdateChatCallback {
    return async (err: Error | null, seenChat: NativeSeenChat, chat: NativeChat, messages: NativeMessage[]) => {
      await this.events.onChatUpdated?.(seenChat, chat, messages);
    };
  }

  private toIncomingMessageCallback(): IncomingMessageCallback {
    return async (err: Error | null, chat: NativeChat | undefined, message: NativeMessage) => {
      await this.events.onIncomingMessage?.(chat, message);
    };
  }
}

export const telegramBridge = new TelegramBridge();
export const isLoggedIn = () => telegramBridge.isLoggedIn();
export const registerDevice = (token: string) => telegramBridge.registerDevice(token);
export const login = (phoneNumber: string) => telegramBridge.login(phoneNumber);
export const verifyCode = (code: string) => telegramBridge.verifyCode(code);
export const password = (passwordText: string) => telegramBridge.password(passwordText);
export const signOut = () => telegramBridge.signOut();
export const run = () => telegramBridge.startSync();
export const stop = () => telegramBridge.stopSync();
export const reconnect = () => telegramBridge.reconnect();
export const getMe = () => telegramBridge.getMe();
export const loadChatsWithOffset = (lastMessageIds: Record<string, number>) => telegramBridge.loadChatsWithOffset(lastMessageIds);
export const loadHistoryMessages = (chatId: number, beforeMessageId?: number, limit?: number) =>
  telegramBridge.loadHistoryMessages(chatId, beforeMessageId, limit);
export const syncCachesFromLocalDb = (packedChats: NativePackedChat[], chats: NativeChat[]) =>
  telegramBridge.syncCachesFromLocalDb(packedChats, chats);
export const sendMessage = (
  chatId: number,
  text: string,
  replyTo?: number,
  medias?: string[],
  onUploadProgress?: (mediaIndex: number, currentProgress: number) => void,
) => telegramBridge.sendMessage(chatId, text, replyTo, medias, onUploadProgress);
export const forwardMessages = (fromChatId: number, toChatId: number, messageIds: number[]) =>
  telegramBridge.forwardMessages(fromChatId, toChatId, messageIds);
export const downloadMediaFromMessage = (chatId: number, messageId: number) =>
  telegramBridge.downloadMediaFromMessage(chatId, messageId);
export const downloadProfilePhoto = (chatId: number) => telegramBridge.downloadProfilePhoto(chatId);
export const getProfilePhotoPathAndCount = (chatId: number) => telegramBridge.getProfilePhotoPathAndCount(chatId);
export const getChatPhotoThumb = (chatId: number) => telegramBridge.getChatPhotoThumb(chatId);
export const getParticipants = (chatId: number) => telegramBridge.getParticipants(chatId);
export const registerPush = (tokenType: number, token: string) => telegramBridge.registerPush(tokenType, token);
export const unregisterPush = (tokenType: number, token: string) => telegramBridge.unregisterPush(tokenType, token);
