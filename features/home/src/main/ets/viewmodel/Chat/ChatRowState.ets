import { IComparable } from '@ohos/base';
import { ChatType } from '../../api';
import { Chat } from '../../entities/Chat';

@Observed
export class ChatRowState implements IComparable<ChatRowState> {
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

  constructor(chat: Chat) {
    this.chatId = chat.chatId;
    this.chatType = chat.chatType;
    this.name = chat.name;
    this.pinned = chat.pinned;
    this.unreadCount = chat.unreadCount;
    this.readInboxMaxId = chat.readInboxMaxId;
    this.readOutboxMaxId = chat.readOutboxMaxId;
    this.muted = chat.muted;
    this.archived = chat.archived;
    this.lastMessageSenderName = chat.lastMessageSenderName;
    this.lastMessageId = chat.lastMessageId;
    this.lastMessageText = chat.lastMessageText;
    this.lastMessageTimestamp = chat.lastMessageTimestamp;
    this.megagroup = chat.megagroup;
    this.forum = chat.forum;
  }

  applyChat(chat: Chat): void {
    this.chatType = chat.chatType;
    this.name = chat.name;
    this.pinned = chat.pinned;
    this.unreadCount = chat.unreadCount;
    this.readInboxMaxId = chat.readInboxMaxId;
    this.readOutboxMaxId = chat.readOutboxMaxId;
    this.muted = chat.muted;
    this.archived = chat.archived;
    this.lastMessageSenderName = chat.lastMessageSenderName;
    this.lastMessageId = chat.lastMessageId;
    this.lastMessageText = chat.lastMessageText;
    this.lastMessageTimestamp = chat.lastMessageTimestamp;
    this.megagroup = chat.megagroup;
    this.forum = chat.forum;
  }

  toChat(): Chat {
    return new Chat(
      this.chatId,
      this.chatType,
      this.name,
      this.pinned,
      this.lastMessageId,
      this.lastMessageSenderName,
      this.lastMessageText,
      this.lastMessageTimestamp,
      this.megagroup,
      this.forum,
      this.unreadCount,
      this.readInboxMaxId,
      this.readOutboxMaxId,
      this.muted,
      this.archived
    );
  }

  compareTo(other: ChatRowState): number {
    if (this.lastMessageTimestamp !== other.lastMessageTimestamp) {
      return this.lastMessageTimestamp - other.lastMessageTimestamp;
    }
    return this.lastMessageId - other.lastMessageId;
  }
}
