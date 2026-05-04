import { NativeChat, ChatType } from '../api';
import { IComparable } from '@ohos/base'

export class Chat implements NativeChat, IComparable<Chat> {
  chatId: number;
  chatType: ChatType;
  name: string;
  pinned: boolean;
  unreadCount: number;
  readInboxMaxId: number;
  readOutboxMaxId: number;
  muted: boolean;
  archived: boolean;
  lastMessageSenderName: string;
  lastMessageId: number;
  lastMessageText: string;
  lastMessageTimestamp: number;
  megagroup: boolean;
  forum: boolean;

  constructor(chatId: number, chatType: ChatType, name: string, pinned: boolean, lastMessageId: number,
    lastMessageSenderName: string, lastMessageText: string, lastMessageTimestamp: number, megagroup: boolean,
    forum: boolean, unreadCount: number = 0, readInboxMaxId: number = 0, readOutboxMaxId: number = 0,
    muted: boolean = false, archived: boolean = false) {
    this.chatId = chatId;
    this.chatType = chatType;
    this.name = name;
    this.pinned = pinned;
    this.unreadCount = unreadCount;
    this.readInboxMaxId = readInboxMaxId;
    this.readOutboxMaxId = readOutboxMaxId;
    this.muted = muted;
    this.archived = archived;
    this.lastMessageId = lastMessageId;
    this.lastMessageSenderName = lastMessageSenderName;
    this.lastMessageText = lastMessageText;
    this.lastMessageTimestamp = lastMessageTimestamp;
    this.megagroup = megagroup;
    this.forum = forum;
  }

  public static fromNative(nativeChat: NativeChat): Chat {
    return new Chat(nativeChat.chatId, nativeChat.chatType, nativeChat.name, nativeChat.pinned,
      nativeChat.lastMessageId, nativeChat.lastMessageSenderName, nativeChat.lastMessageText,
      nativeChat.lastMessageTimestamp, nativeChat.megagroup,
      nativeChat.forum, nativeChat.unreadCount ?? 0, nativeChat.readInboxMaxId ?? 0, nativeChat.readOutboxMaxId ?? 0,
      nativeChat.muted ?? false, nativeChat.archived ?? false);
  }

  public toNative(): NativeChat {
    return {
      chatId: this.chatId,
      chatType: this.chatType,
      name: this.name,
      pinned: this.pinned,
      unreadCount: this.unreadCount,
      readInboxMaxId: this.readInboxMaxId,
      readOutboxMaxId: this.readOutboxMaxId,
      muted: this.muted,
      archived: this.archived,
      lastMessageId: this.lastMessageId,
      lastMessageSenderName: this.lastMessageSenderName,
      lastMessageText: this.lastMessageText,
      lastMessageTimestamp: this.lastMessageTimestamp,
      megagroup: this.megagroup,
      forum: this.forum
    };
  }

  compareTo(other: Chat): number {
    if (this.lastMessageTimestamp !== other.lastMessageTimestamp) {
      return this.lastMessageTimestamp - other.lastMessageTimestamp;
    }
    return this.lastMessageId - other.lastMessageId;
  }
}


