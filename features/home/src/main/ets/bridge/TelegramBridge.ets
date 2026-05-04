import { Logger } from '@ohos/base';
import {
  ChatType,
  deleteMessages as nativeDeleteMessages,
  downloadMedia as nativeDownloadMedia,
  downloadProfilePhoto as nativeDownloadProfilePhoto,
  editMessage as nativeEditMessage,
  forwardMessages as nativeForwardMessages,
  getChatPhotoThumb as nativeGetChatPhotoThumb,
  getContacts as nativeGetContacts,
  getEventsSince as nativeGetEventsSince,
  getMe as nativeGetMe,
  getParticipants as nativeGetParticipants,
  getProfilePhotoPathAndCount as nativeGetProfilePhotoPathAndCount,
  initialize as nativeInitialize,
  isLoggedIn as nativeIsLoggedIn,
  loadDialogs as nativeLoadDialogs,
  loadMessages as nativeLoadMessages,
  LoginState,
  markChatRead as nativeMarkChatRead,
  MediaType,
  MessageEntityType,
  NativeActionResult,
  NativeAuthState,
  NativeChat,
  NativeDeletedMessages,
  NativeDialog,
  NativeDialogFlags,
  NativeDialogLoadRequest,
  NativeDialogLoadResult,
  NativeDialogPage,
  NativeEvent,
  NativeEventKind,
  NativeLoadSource,
  NativeMediaInput,
  NativeMediaResult,
  NativeMessage,
  NativeMessageEntity,
  NativeMessageLoadRequest,
  NativeMessageLoadResult,
  NativeMessageLoadType,
  NativeMessagePage,
  NativeParticipant,
  NativeParticipantRole,
  NativePeer,
  NativeProfilePhotoPathAndCount,
  NativeProgress,
  NativeReadState,
  NativeRuntimeOptions,
  NativeRuntimeState,
  NativeSearchPage,
  NativeSearchResult,
  NativeSearchResultKind,
  NativeSendRequest,
  NativeSendResult,
  NativeSendState,
  openChat as nativeOpenChat,
  reconnectRuntime as nativeReconnectRuntime,
  registerDevice as nativeRegisterDevice,
  registerPush as nativeRegisterPush,
  requestLoginCode as nativeRequestLoginCode,
  resolvePeerByUsername as nativeResolvePeerByUsername,
  searchMessages as nativeSearchMessages,
  searchPeers as nativeSearchPeers,
  sendMessage as nativeSendMessage,
  setDialogFlags as nativeSetDialogFlags,
  setEventCallback as nativeSetEventCallback,
  signOut as nativeSignOut,
  startRuntime as nativeStartRuntime,
  stopRuntime as nativeStopRuntime,
  submitLoginCode as nativeSubmitLoginCode,
  submitPassword as nativeSubmitPassword,
  unregisterPush as nativeUnregisterPush,
} from 'libhomogrape.so';

export {
  ChatType,
  LoginState,
  MediaType,
  MessageEntityType,
  NativeActionResult,
  NativeAuthState,
  NativeChat,
  NativeDeletedMessages,
  NativeDialog,
  NativeDialogFlags,
  NativeDialogLoadRequest,
  NativeDialogLoadResult,
  NativeDialogPage,
  NativeEvent,
  NativeEventKind,
  NativeLoadSource,
  NativeMediaInput,
  NativeMediaResult,
  NativeMessage,
  NativeMessageEntity,
  NativeMessageLoadRequest,
  NativeMessageLoadResult,
  NativeMessageLoadType,
  NativeMessagePage,
  NativeParticipant,
  NativeParticipantRole,
  NativePeer,
  NativeProfilePhotoPathAndCount,
  NativeProgress,
  NativeReadState,
  NativeRuntimeOptions,
  NativeRuntimeState,
  NativeSearchPage,
  NativeSearchResult,
  NativeSearchResultKind,
  NativeSendRequest,
  NativeSendResult,
  NativeSendState,
};

export type NativeSeenChat = NativePeer;
export type ChatActionResult = NativeActionResult;

export type IncomingMessageCallback = (err: Error | null, chat: NativeChat | undefined, message: NativeMessage) => Promise<void>;
export type UpdateChatCallback = (err: Error | null, seenChat: NativeSeenChat | undefined, chat: NativeChat,
  messages: NativeMessage[]) => Promise<void>;
export type EditedMessageCallback = (message: NativeMessage) => Promise<void>;
export type DeletedMessagesCallback = (deletedMessages: NativeDeletedMessages) => Promise<void>;
export type ReadStateCallback = (readState: NativeReadState) => Promise<void>;
export type UploadProgressCallback = (mediaIndex: number, currentProgress: number) => void;

export interface ProfilePhotoPathAndCount {
  dir?: string;
  current?: string;
  next?: string;
  count: number;
}

export interface TelegramBridgeEvents {
  onSeenChatCached?: (seenChat: NativeSeenChat) => void | Promise<void>;
  onChatUpdated?: (seenChat: NativeSeenChat | undefined, chat: NativeChat, messages: NativeMessage[]) => void | Promise<void>;
  onDialogsLoaded?: (dialogs: NativeDialog[], messages: NativeMessage[], source: NativeLoadSource | undefined) => void | Promise<void>;
  onMessagesLoaded?: (chat: NativeChat | undefined, messages: NativeMessage[], source: NativeLoadSource | undefined,
    loadType: NativeMessageLoadType | undefined) => void | Promise<void>;
  onIncomingMessage?: (chat: NativeChat | undefined, message: NativeMessage) => void | Promise<void>;
  onEditedMessage?: (message: NativeMessage) => void | Promise<void>;
  onDeletedMessages?: (deletedMessages: NativeDeletedMessages) => void | Promise<void>;
  onReadState?: (readState: NativeReadState) => void | Promise<void>;
}

export class NativeRuntimeOptionsRecord implements NativeRuntimeOptions {
  eventReplayLimit?: number;

  constructor(eventReplayLimit?: number) {
    this.eventReplayLimit = eventReplayLimit;
  }
}

export class NativeMediaInputRecord implements NativeMediaInput {
  path: string;
  mediaType: MediaType;
  caption?: string;

  constructor(path: string, mediaType: MediaType = MediaType.None, caption?: string) {
    this.path = path;
    this.mediaType = mediaType;
    this.caption = caption;
  }
}

class NativeSendRequestRecord implements NativeSendRequest {
  chatId: number;
  text: string;
  replyToMessageId?: number;
  medias?: NativeMediaInput[];

  constructor(chatId: number, text: string, replyToMessageId?: number, medias?: NativeMediaInput[]) {
    this.chatId = chatId;
    this.text = text;
    this.replyToMessageId = replyToMessageId;
    this.medias = medias;
  }
}

class NativeDialogFlagsRecord implements NativeDialogFlags {
  pinned?: boolean;
  muted?: boolean;
  archived?: boolean;

  constructor(pinned?: boolean, muted?: boolean, archived?: boolean) {
    this.pinned = pinned;
    this.muted = muted;
    this.archived = archived;
  }
}

class NativeDialogLoadRequestRecord implements NativeDialogLoadRequest {
  folderId?: number;
  offset?: number;
  count?: number;
  source?: NativeLoadSource;

  constructor(folderId?: number, offset?: number, count?: number, source?: NativeLoadSource) {
    this.folderId = folderId;
    this.offset = offset;
    this.count = count;
    this.source = source;
  }
}

class NativeMessageLoadRequestRecord implements NativeMessageLoadRequest {
  chatId: number;
  threadId?: number;
  count?: number;
  maxId?: number;
  offsetDate?: number;
  loadType?: NativeMessageLoadType;
  source?: NativeLoadSource;
  lastMessageId?: number;
  firstUnreadId?: number;

  constructor(chatId: number, count?: number, maxId?: number, loadType?: NativeMessageLoadType,
    source?: NativeLoadSource, threadId?: number, offsetDate?: number, lastMessageId?: number,
    firstUnreadId?: number) {
    this.chatId = chatId;
    this.threadId = threadId;
    this.count = count;
    this.maxId = maxId;
    this.offsetDate = offsetDate;
    this.loadType = loadType;
    this.source = source;
    this.lastMessageId = lastMessageId;
    this.firstUnreadId = firstUnreadId;
  }
}

class NativeDialogPageRecord implements NativeDialogPage {
  dialogs: NativeDialog[];
  hasMore: boolean;

  constructor(dialogs: NativeDialog[], hasMore: boolean) {
    this.dialogs = dialogs;
    this.hasMore = hasMore;
  }
}

class NativeMessagePageRecord implements NativeMessagePage {
  chatId: number;
  messages: NativeMessage[];
  hasMore: boolean;

  constructor(chatId: number, messages: NativeMessage[], hasMore: boolean) {
    this.chatId = chatId;
    this.messages = messages;
    this.hasMore = hasMore;
  }
}

class TelegramBridge {
  private started: boolean = false;
  private callbacksRegistered: boolean = false;
  private events: TelegramBridgeEvents = {};
  private lastEventSeq: number = 0;
  private uploadProgressCallbacks: UploadProgressCallback[] = [];

  async initialize(events: TelegramBridgeEvents): Promise<void> {
    this.events = events;
    if (!this.callbacksRegistered) {
      Logger.info('TelegramBridge initialize: native runtime initialize');
      const state: NativeRuntimeState = await nativeInitialize(new NativeRuntimeOptionsRecord(256));
      Logger.info('TelegramBridge initialize: authorized=' + state.authorized + ' running=' + state.running +
        ' lastEventSeq=' + state.lastEventSeq);
      this.lastEventSeq = state.lastEventSeq;
      await nativeSetEventCallback(async (event: NativeEvent): Promise<void> => {
        await this.handleNativeEvent(event);
      });
      this.callbacksRegistered = true;
      await this.replayMissedEvents();
    }
  }

  async isLoggedIn(): Promise<boolean> {
    const authorized = await nativeIsLoggedIn();
    Logger.info('TelegramBridge isLoggedIn: ' + authorized);
    return authorized;
  }

  async registerDevice(token: string): Promise<boolean> {
    return nativeRegisterDevice(token);
  }

  async login(phoneNumber: string): Promise<LoginState> {
    const state: NativeAuthState = await nativeRequestLoginCode(phoneNumber);
    return state.loginState;
  }

  async verifyCode(code: string): Promise<LoginState> {
    const state: NativeAuthState = await nativeSubmitLoginCode(code);
    return state.loginState;
  }

  async password(password: string): Promise<LoginState> {
    const state: NativeAuthState = await nativeSubmitPassword(password);
    return state.loginState;
  }

  async signOut(): Promise<boolean> {
    this.started = false;
    return nativeSignOut();
  }

  async startSync(): Promise<void> {
    Logger.info('TelegramBridge startSync: start');
    await nativeStartRuntime();
    this.started = true;
    Logger.info('TelegramBridge startSync: done');
  }

  async stopSync(): Promise<void> {
    if (!this.started) {
      return;
    }
    await nativeStopRuntime();
    this.started = false;
  }

  async reconnect(): Promise<boolean> {
    Logger.info('TelegramBridge reconnect: start');
    const state: NativeRuntimeState = await nativeReconnectRuntime();
    this.started = state.running;
    Logger.info('TelegramBridge reconnect: authorized=' + state.authorized + ' running=' + state.running);
    return state.authorized;
  }

  async getMe(): Promise<NativeSeenChat> {
    return nativeGetMe();
  }

  async getDialogs(offsetDate?: number, limit?: number): Promise<NativeDialogPage> {
    const result: NativeDialogLoadResult =
      await nativeLoadDialogs(new NativeDialogLoadRequestRecord(0, undefined, limit, NativeLoadSource.Cache));
    const page: NativeDialogPage = new NativeDialogPageRecord(result.dialogs, result.hasMore);
    Logger.info('TelegramBridge getDialogs: dialogs=' + page.dialogs.length + ' offsetDate=' +
      (offsetDate ?? -1) + ' limit=' + (limit ?? -1));
    return page;
  }

  async getMessages(chatId: number, beforeMessageId?: number, limit?: number): Promise<NativeMessagePage> {
    const result: NativeMessageLoadResult = await nativeLoadMessages(new NativeMessageLoadRequestRecord(
      chatId, limit, beforeMessageId, NativeMessageLoadType.Backward, NativeLoadSource.Cache));
    const page: NativeMessagePage = new NativeMessagePageRecord(result.chatId, result.messages, result.hasMore);
    Logger.info('TelegramBridge getMessages: chatId=' + chatId + ' messages=' + page.messages.length +
      ' beforeMessageId=' + (beforeMessageId ?? -1) + ' limit=' + (limit ?? -1));
    return page;
  }

  async loadChatsWithOffset(_lastMessageIds: Record<string, number>): Promise<void> {
    await nativeStartRuntime();
    this.started = true;
  }

  async loadHistoryMessages(chatId: number, beforeMessageId?: number, limit?: number): Promise<NativeMessage[]> {
    const result: NativeMessageLoadResult = await nativeLoadMessages(new NativeMessageLoadRequestRecord(
      chatId, limit, beforeMessageId, NativeMessageLoadType.Backward, NativeLoadSource.Cache));
    return result.messages;
  }

  async sendMessage(
    chatId: number,
    text: string,
    replyTo?: number,
    medias?: NativeMediaInput[],
    onUploadProgress?: UploadProgressCallback,
  ): Promise<NativeMessage[]> {
    if (onUploadProgress) {
      this.uploadProgressCallbacks.push(onUploadProgress);
    }
    try {
      const result: NativeSendResult =
        await nativeSendMessage(new NativeSendRequestRecord(chatId, text, replyTo, medias));
      return result.messages;
    } finally {
      if (onUploadProgress) {
        this.removeUploadProgressCallback(onUploadProgress);
      }
    }
  }

  async getContacts(): Promise<NativeSeenChat[]> {
    return nativeGetContacts();
  }

  async resolvePeerByUsername(username: string): Promise<NativeSearchResult | undefined> {
    const result: NativeSearchResult | null | undefined = await nativeResolvePeerByUsername(username);
    return result ?? undefined;
  }

  async openChat(chatId: number): Promise<NativeSearchResult> {
    return nativeOpenChat(chatId);
  }

  async searchKnownPeers(query: string, limit: number = 20): Promise<NativeSearchResult[]> {
    const page: NativeSearchPage = await nativeSearchPeers(query, limit);
    return page.results;
  }

  async searchMessages(chatId: number, query: string, limit: number = 20, offsetId?: number): Promise<NativeSearchResult[]> {
    const page: NativeSearchPage = await nativeSearchMessages(chatId, query, offsetId, limit);
    return page.results;
  }

  async searchAllMessages(query: string, limit: number = 20, offsetId?: number): Promise<NativeSearchResult[]> {
    const page: NativeSearchPage = await nativeSearchMessages(undefined, query, offsetId, limit);
    return page.results;
  }

  async editMessage(chatId: number, messageId: number, text: string): Promise<NativeMessage> {
    return nativeEditMessage(chatId, messageId, text);
  }

  async deleteMessages(chatId: number, messageIds: number[]): Promise<ChatActionResult> {
    return nativeDeleteMessages(chatId, messageIds);
  }

  async markChatRead(chatId: number): Promise<ChatActionResult> {
    return nativeMarkChatRead(chatId);
  }

  async setChatPinned(chatId: number, pinned: boolean): Promise<ChatActionResult> {
    return nativeSetDialogFlags(chatId, new NativeDialogFlagsRecord(pinned, undefined, undefined));
  }

  async setChatMuted(chatId: number, muted: boolean): Promise<ChatActionResult> {
    return nativeSetDialogFlags(chatId, new NativeDialogFlagsRecord(undefined, muted, undefined));
  }

  async setChatArchived(chatId: number, archived: boolean): Promise<ChatActionResult> {
    return nativeSetDialogFlags(chatId, new NativeDialogFlagsRecord(undefined, undefined, archived));
  }

  async forwardMessages(fromChatId: number, toChatId: number, messageIds: number[]): Promise<Array<NativeMessage | undefined>> {
    const messages: NativeMessage[] = await nativeForwardMessages(fromChatId, toChatId, messageIds);
    return messages;
  }

  async downloadMediaFromMessage(chatId: number, messageId: number): Promise<string> {
    const result: NativeMediaResult = await nativeDownloadMedia(chatId, messageId);
    return result.localPath;
  }

  async downloadProfilePhoto(chatId: number): Promise<string> {
    const result: NativeMediaResult = await nativeDownloadProfilePhoto(chatId);
    return result.localPath;
  }

  getProfilePhotoPathAndCount(chatId: number): ProfilePhotoPathAndCount {
    return nativeGetProfilePhotoPathAndCount(chatId);
  }

  async getChatPhotoThumb(chatId: number): Promise<number[] | undefined> {
    const thumb: number[] | null | undefined = await nativeGetChatPhotoThumb(chatId);
    return thumb ?? undefined;
  }

  async getParticipants(chatId: number): Promise<NativeParticipant[]> {
    return nativeGetParticipants(chatId, undefined);
  }

  async registerPush(tokenType: number, token: string): Promise<string> {
    return nativeRegisterPush(tokenType, token);
  }

  async unregisterPush(tokenType: number, token: string): Promise<string> {
    return nativeUnregisterPush(tokenType, token);
  }

  private async replayMissedEvents(): Promise<void> {
    const events: NativeEvent[] = await nativeGetEventsSince(this.lastEventSeq, 256);
    Logger.info('TelegramBridge replayMissedEvents: count=' + events.length + ' since=' + this.lastEventSeq);
    for (let i = 0; i < events.length; i++) {
      await this.handleNativeEvent(events[i]);
    }
  }

  private async handleNativeEvent(event: NativeEvent): Promise<void> {
    Logger.debug('TelegramBridge native event kind=' + event.kind.toString() + ' seq=' + event.seq);
    if (event.seq > this.lastEventSeq) {
      this.lastEventSeq = event.seq;
    }
    if (event.peer) {
      await this.events.onSeenChatCached?.(event.peer);
    }
    switch (event.kind) {
      case NativeEventKind.DialogUpserted:
        await this.handleDialogEvent(event);
        break;
      case NativeEventKind.DialogsLoaded:
        await this.handleDialogsLoadedEvent(event);
        break;
      case NativeEventKind.MessagesUpserted:
        await this.handleMessagesEvent(event);
        break;
      case NativeEventKind.MessagesLoaded:
        await this.handleMessagesLoadedEvent(event);
        break;
      case NativeEventKind.MessageEdited:
        if (event.message) {
          await this.events.onEditedMessage?.(event.message);
        }
        break;
      case NativeEventKind.MessagesDeleted:
        if (event.deletedMessages) {
          await this.events.onDeletedMessages?.(event.deletedMessages);
        }
        break;
      case NativeEventKind.ReadStateChanged:
        if (event.readState) {
          await this.events.onReadState?.(event.readState);
        }
        break;
      case NativeEventKind.UploadProgress:
        if (event.progress) {
          this.handleUploadProgress(event.progress);
        }
        break;
      case NativeEventKind.ActionFailed:
      case NativeEventKind.UnknownUpdate:
        if (event.error) {
          Logger.warn('TelegramBridge native event ' + event.kind.toString() + ': ' + event.error.message);
        }
        break;
      case NativeEventKind.RuntimeState:
      case NativeEventKind.PeerUpserted:
      case NativeEventKind.DownloadProgress:
        break;
      default:
        break;
    }
  }

  private async handleDialogEvent(event: NativeEvent): Promise<void> {
    if (!event.chat) {
      return;
    }
    const messages: NativeMessage[] = event.messages ?? [];
    Logger.info('TelegramBridge handleDialogEvent chatId=' + event.chat.chatId + ' messages=' + messages.length);
    await this.events.onChatUpdated?.(event.peer ?? undefined, event.chat, messages);
  }

  private async handleDialogsLoadedEvent(event: NativeEvent): Promise<void> {
    const dialogs: NativeDialog[] = event.dialogs ?? [];
    const messages: NativeMessage[] = event.messages ?? [];
    Logger.info('TelegramBridge handleDialogsLoadedEvent dialogs=' + dialogs.length + ' messages=' + messages.length);
    await this.events.onDialogsLoaded?.(dialogs, messages, event.source ?? undefined);
  }

  private async handleMessagesEvent(event: NativeEvent): Promise<void> {
    const messages: NativeMessage[] = event.messages ?? [];
    Logger.info('TelegramBridge handleMessagesEvent messages=' + messages.length +
      ' chatId=' + (event.chat ? event.chat.chatId : -1));
    if (event.chat) {
      await this.events.onChatUpdated?.(event.peer ?? undefined, event.chat, messages);
      return;
    }
    for (let i = 0; i < messages.length; i++) {
      await this.events.onIncomingMessage?.(undefined, messages[i]);
    }
  }

  private async handleMessagesLoadedEvent(event: NativeEvent): Promise<void> {
    const messages: NativeMessage[] = event.messages ?? [];
    Logger.info('TelegramBridge handleMessagesLoadedEvent messages=' + messages.length +
      ' chatId=' + (event.chat ? event.chat.chatId : -1));
    await this.events.onMessagesLoaded?.(event.chat ?? undefined, messages, event.source ?? undefined,
      event.loadType ?? undefined);
  }

  private handleUploadProgress(progress: NativeProgress): void {
    const mediaIndex = progress.mediaIndex ?? 0;
    for (let i = 0; i < this.uploadProgressCallbacks.length; i++) {
      this.uploadProgressCallbacks[i](mediaIndex, progress.currentProgress);
    }
  }

  private removeUploadProgressCallback(callback: UploadProgressCallback): void {
    const nextCallbacks: UploadProgressCallback[] = [];
    for (let i = 0; i < this.uploadProgressCallbacks.length; i++) {
      if (this.uploadProgressCallbacks[i] !== callback) {
        nextCallbacks.push(this.uploadProgressCallbacks[i]);
      }
    }
    this.uploadProgressCallbacks = nextCallbacks;
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
export const sendMessage = (
  chatId: number,
  text: string,
  replyTo?: number,
  medias?: NativeMediaInput[],
  onUploadProgress?: UploadProgressCallback,
) => telegramBridge.sendMessage(chatId, text, replyTo, medias, onUploadProgress);
export const getContacts = () => telegramBridge.getContacts();
export const resolvePeerByUsername = (username: string) => telegramBridge.resolvePeerByUsername(username);
export const openChat = (chatId: number) => telegramBridge.openChat(chatId);
export const searchKnownPeers = (query: string, limit?: number) => telegramBridge.searchKnownPeers(query, limit);
export const searchMessages = (chatId: number, query: string, limit?: number, offsetId?: number) =>
  telegramBridge.searchMessages(chatId, query, limit, offsetId);
export const searchAllMessages = (query: string, limit?: number, offsetId?: number) =>
  telegramBridge.searchAllMessages(query, limit, offsetId);
export const editMessage = (chatId: number, messageId: number, text: string) =>
  telegramBridge.editMessage(chatId, messageId, text);
export const deleteMessages = (chatId: number, messageIds: number[]) => telegramBridge.deleteMessages(chatId, messageIds);
export const markChatRead = (chatId: number) => telegramBridge.markChatRead(chatId);
export const setChatPinned = (chatId: number, pinned: boolean) => telegramBridge.setChatPinned(chatId, pinned);
export const setChatMuted = (chatId: number, muted: boolean) => telegramBridge.setChatMuted(chatId, muted);
export const setChatArchived = (chatId: number, archived: boolean) => telegramBridge.setChatArchived(chatId, archived);
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
