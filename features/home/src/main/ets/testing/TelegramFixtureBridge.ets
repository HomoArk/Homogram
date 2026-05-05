import { Logger } from '@ohos/base';
import {
  LoginState,
  NativeActionResult,
  NativeChat,
  NativeDialog,
  NativeDialogPage,
  NativeMediaInput,
  NativeMessage,
  NativeMessagePage,
  NativeParticipant,
  NativePeer,
  NativeProfilePhotoPathAndCount,
  NativeRuntimeOptions,
  NativeRuntimeState,
  NativeSearchResult,
  NativeSearchResultKind,
} from 'libhomogrape.so';
import { buildFixtureSeed } from './FixtureSeedData';
import {
  FixtureActionResult,
  FixtureDeletedMessages,
  FixtureDialog,
  FixtureDialogPage,
  FixtureMessage,
  FixtureMessagePage,
  FixtureParticipantSet,
  FixtureProfilePhotoPathAndCount,
  FixtureReadState,
  FixtureRuntimeState,
  FixtureSearchResult,
  FixtureSeed,
  TelegramFixtureEvents,
} from './FixtureRecords';

export type FixtureUploadProgressCallback = (mediaIndex: number, currentProgress: number) => void;

export class TelegramFixtureBridge {
  private readonly me: NativePeer;
  private readonly peers: NativePeer[] = [];
  private readonly chats: NativeChat[] = [];
  private readonly messageSets: NativeMessage[][] = [];
  private readonly participantSets: FixtureParticipantSet[] = [];
  private events: TelegramFixtureEvents = new TelegramFixtureEvents();
  private started: boolean = false;
  private nextMessageId: number = 1;

  constructor() {
    const seed: FixtureSeed = buildFixtureSeed();
    this.me = seed.me;
    this.peers.push(...seed.peers);
    this.chats.push(...seed.chats);
    this.messageSets.push(...seed.messageSets);
    this.participantSets.push(...seed.participantSets);
    this.nextMessageId = seed.nextMessageId;
  }

  async initialize(events: TelegramFixtureEvents, _options?: NativeRuntimeOptions): Promise<NativeRuntimeState> {
    this.events = events;
    Logger.info('TelegramFixtureBridge initialize');
    return new FixtureRuntimeState(true, this.started, 1);
  }

  async isLoggedIn(): Promise<boolean> {
    return true;
  }

  async registerDevice(_token: string): Promise<boolean> {
    return true;
  }

  async login(_phoneNumber: string): Promise<LoginState> {
    return LoginState.LoggedIn;
  }

  async verifyCode(_code: string): Promise<LoginState> {
    return LoginState.LoggedIn;
  }

  async password(_password: string): Promise<LoginState> {
    return LoginState.LoggedIn;
  }

  async signOut(): Promise<boolean> {
    this.started = false;
    return true;
  }

  async startSync(): Promise<void> {
    this.started = true;
  }

  async stopSync(): Promise<void> {
    this.started = false;
  }

  async reconnect(): Promise<boolean> {
    this.started = true;
    return true;
  }

  async getMe(): Promise<NativePeer> {
    return this.me;
  }

  async getDialogs(_offsetDate?: number, limit?: number): Promise<NativeDialogPage> {
    const dialogs: NativeDialog[] = [];
    const count = Math.min(limit ?? this.chats.length, this.chats.length);
    for (let i = 0; i < count; i++) {
      dialogs.push(new FixtureDialog(this.peers[i], this.chats[i]));
    }
    return new FixtureDialogPage(dialogs, false);
  }

  async getMessages(chatId: number, beforeMessageId?: number, limit?: number): Promise<FixtureMessagePage> {
    const messages = this.loadHistoryMessagesSync(chatId, beforeMessageId, limit);
    return new FixtureMessagePage(chatId, messages, false);
  }

  async loadHistoryMessages(chatId: number, beforeMessageId?: number, limit?: number): Promise<NativeMessage[]> {
    return this.loadHistoryMessagesSync(chatId, beforeMessageId, limit);
  }

  async sendMessage(
    chatId: number,
    text: string,
    replyTo?: number,
    _medias?: NativeMediaInput[],
    onUploadProgress?: FixtureUploadProgressCallback,
  ): Promise<NativeMessage[]> {
    if (onUploadProgress) {
      onUploadProgress(0, 100);
    }
    const messages = this.messagesForChat(chatId);
    const timestamp = this.latestTimestamp(messages) + 30;
    const message = new FixtureMessage(chatId, this.nextMessageId, true, this.me.chatId, this.me.fullName, timestamp,
      text, replyTo);
    this.nextMessageId++;
    messages.push(message);
    this.updateChatPreview(chatId, message);
    const chat = this.chatById(chatId);
    const peer = this.peerById(chatId);
    if (chat) {
      await this.events.onChatUpdated?.(peer, chat, [message]);
    }
    return [message];
  }

  async getContacts(): Promise<NativePeer[]> {
    const contacts: NativePeer[] = [];
    for (let i = 0; i < this.peers.length; i++) {
      if (this.peers[i].isContact) {
        contacts.push(this.peers[i]);
      }
    }
    return contacts;
  }

  async resolvePeerByUsername(username: string): Promise<NativeSearchResult | undefined> {
    const normalized = username.toLowerCase();
    for (let i = 0; i < this.peers.length; i++) {
      if ((this.peers[i].username ?? '').toLowerCase() === normalized) {
        return this.searchResultForPeer(this.peers[i]);
      }
    }
    return undefined;
  }

  async openChat(chatId: number): Promise<NativeSearchResult> {
    const peer = this.peerById(chatId);
    const chat = this.chatById(chatId);
    return new FixtureSearchResult(NativeSearchResultKind.Chat, chat, peer);
  }

  async searchKnownPeers(query: string, limit: number = 20): Promise<NativeSearchResult[]> {
    const results: NativeSearchResult[] = [];
    const normalized = query.toLowerCase();
    for (let i = 0; i < this.peers.length && results.length < limit; i++) {
      const peer = this.peers[i];
      if (peer.fullName.toLowerCase().indexOf(normalized) >= 0 || (peer.username ?? '').toLowerCase().indexOf(normalized) >= 0) {
        results.push(this.searchResultForPeer(peer));
      }
    }
    return results;
  }

  async searchMessages(chatId: number, query: string, limit: number = 20, _offsetId?: number): Promise<NativeSearchResult[]> {
    const results: NativeSearchResult[] = [];
    const normalized = query.toLowerCase();
    const messages = this.messagesForChat(chatId);
    const chat = this.chatById(chatId);
    const peer = this.peerById(chatId);
    for (let i = messages.length - 1; i >= 0 && results.length < limit; i--) {
      if (messages[i].text.toLowerCase().indexOf(normalized) >= 0) {
        results.push(new FixtureSearchResult(NativeSearchResultKind.Message, chat, peer, messages[i]));
      }
    }
    return results;
  }

  async searchAllMessages(query: string, limit: number = 20, _offsetId?: number): Promise<NativeSearchResult[]> {
    const results: NativeSearchResult[] = [];
    for (let i = 0; i < this.chats.length && results.length < limit; i++) {
      const chatResults = await this.searchMessages(this.chats[i].chatId, query, limit - results.length);
      results.push(...chatResults);
    }
    return results;
  }

  async editMessage(chatId: number, messageId: number, text: string): Promise<NativeMessage> {
    const message = this.messageById(chatId, messageId);
    if (!message) {
      throw new Error('Fixture message not found');
    }
    message.text = text;
    message.editTimestamp = message.timestamp + 1;
    this.updateChatPreview(chatId, message);
    await this.events.onEditedMessage?.(message);
    return message;
  }

  async deleteMessages(chatId: number, messageIds: number[]): Promise<NativeActionResult> {
    const messages = this.messagesForChat(chatId);
    const remaining: NativeMessage[] = [];
    for (let i = 0; i < messages.length; i++) {
      if (messageIds.indexOf(messages[i].messageId) < 0) {
        remaining.push(messages[i]);
      }
    }
    this.replaceMessagesForChat(chatId, remaining);
    await this.events.onDeletedMessages?.(new FixtureDeletedMessages(chatId, messageIds));
    return new FixtureActionResult('fixture messages deleted');
  }

  async markChatRead(chatId: number): Promise<NativeActionResult> {
    const chat = this.chatById(chatId);
    if (chat) {
      chat.unreadCount = 0;
      await this.events.onReadState?.(new FixtureReadState(chatId, chat.lastMessageId, 0, true));
    }
    return new FixtureActionResult('fixture chat marked read');
  }

  async setChatPinned(chatId: number, pinned: boolean): Promise<NativeActionResult> {
    const chat = this.chatById(chatId);
    if (chat) {
      chat.pinned = pinned;
    }
    return new FixtureActionResult('fixture pinned updated');
  }

  async setChatMuted(chatId: number, muted: boolean): Promise<NativeActionResult> {
    const chat = this.chatById(chatId);
    if (chat) {
      chat.muted = muted;
    }
    return new FixtureActionResult('fixture muted updated');
  }

  async setChatArchived(chatId: number, archived: boolean): Promise<NativeActionResult> {
    const chat = this.chatById(chatId);
    if (chat) {
      chat.archived = archived;
    }
    return new FixtureActionResult('fixture archived updated');
  }

  async forwardMessages(fromChatId: number, toChatId: number, messageIds: number[]): Promise<Array<NativeMessage | undefined>> {
    const forwarded: Array<NativeMessage | undefined> = [];
    for (let i = 0; i < messageIds.length; i++) {
      const source = this.messageById(fromChatId, messageIds[i]);
      if (!source) {
        forwarded.push(undefined);
        continue;
      }
      const created = await this.sendMessage(toChatId, source.text);
      forwarded.push(created[0]);
    }
    return forwarded;
  }

  async downloadMediaFromMessage(chatId: number, messageId: number): Promise<string> {
    return '/data/storage/el2/base/haps/entry/files/fixtures/' + chatId.toString() + '/' + messageId.toString();
  }

  async downloadProfilePhoto(chatId: number): Promise<string> {
    return '/data/storage/el2/base/haps/entry/files/fixtures/profile-' + chatId.toString() + '.jpg';
  }

  getProfilePhotoPathAndCount(_chatId: number): NativeProfilePhotoPathAndCount {
    return new FixtureProfilePhotoPathAndCount();
  }

  async getChatPhotoThumb(_chatId: number): Promise<number[] | undefined> {
    return undefined;
  }

  async getParticipants(chatId: number): Promise<NativeParticipant[]> {
    for (let i = 0; i < this.participantSets.length; i++) {
      if (this.participantSets[i].chatId === chatId) {
        return this.participantSets[i].participants;
      }
    }
    return [];
  }

  async registerPush(_tokenType: number, _token: string): Promise<string> {
    return 'fixture-push-registered';
  }

  async unregisterPush(_tokenType: number, _token: string): Promise<string> {
    return 'fixture-push-unregistered';
  }

  private loadHistoryMessagesSync(chatId: number, beforeMessageId?: number, limit?: number): NativeMessage[] {
    const source = this.messagesForChat(chatId);
    const selected: NativeMessage[] = [];
    for (let i = 0; i < source.length; i++) {
      if (beforeMessageId !== undefined && source[i].messageId >= beforeMessageId) {
        continue;
      }
      selected.push(source[i]);
    }
    const maxCount = limit ?? selected.length;
    if (selected.length <= maxCount) {
      return selected;
    }
    return selected.slice(selected.length - maxCount);
  }

  private searchResultForPeer(peer: NativePeer): NativeSearchResult {
    return new FixtureSearchResult(NativeSearchResultKind.Chat, this.chatById(peer.chatId), peer);
  }

  private messagesForChat(chatId: number): NativeMessage[] {
    for (let i = 0; i < this.chats.length; i++) {
      if (this.chats[i].chatId === chatId) {
        return this.messageSets[i];
      }
    }
    return [];
  }

  private replaceMessagesForChat(chatId: number, messages: NativeMessage[]): void {
    for (let i = 0; i < this.chats.length; i++) {
      if (this.chats[i].chatId === chatId) {
        this.messageSets[i] = messages;
        if (messages.length > 0) {
          this.updateChatPreview(chatId, messages[messages.length - 1]);
        }
      }
    }
  }

  private chatById(chatId: number): NativeChat | undefined {
    for (let i = 0; i < this.chats.length; i++) {
      if (this.chats[i].chatId === chatId) {
        return this.chats[i];
      }
    }
    return undefined;
  }

  private peerById(chatId: number): NativePeer | undefined {
    for (let i = 0; i < this.peers.length; i++) {
      if (this.peers[i].chatId === chatId) {
        return this.peers[i];
      }
    }
    return undefined;
  }

  private messageById(chatId: number, messageId: number): NativeMessage | undefined {
    const messages = this.messagesForChat(chatId);
    for (let i = 0; i < messages.length; i++) {
      if (messages[i].messageId === messageId) {
        return messages[i];
      }
    }
    return undefined;
  }

  private updateChatPreview(chatId: number, message: NativeMessage): void {
    const chat = this.chatById(chatId);
    if (!chat) {
      return;
    }
    chat.lastMessageId = message.messageId;
    chat.lastMessageSenderName = message.senderName;
    chat.lastMessageText = message.text;
    chat.lastMessageTimestamp = message.timestamp;
    chat.readInboxMaxId = Math.max(chat.readInboxMaxId, message.messageId);
    chat.readOutboxMaxId = Math.max(chat.readOutboxMaxId, message.messageId);
  }

  private latestTimestamp(messages: NativeMessage[]): number {
    if (messages.length === 0) {
      return 1714800200;
    }
    return messages[messages.length - 1].timestamp;
  }
}
