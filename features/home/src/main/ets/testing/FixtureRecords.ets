import {
  ChatType,
  MediaType,
  MessageEntityType,
  NativeActionResult,
  NativeChat,
  NativeDeletedMessages,
  NativeDialog,
  NativeDialogPage,
  NativeLoadSource,
  NativeMessage,
  NativeMessageEntity,
  NativeMessageLoadType,
  NativeMessagePage,
  NativeParticipant,
  NativeParticipantRole,
  NativePeer,
  NativeProfilePhotoPathAndCount,
  NativeReadState,
  NativeRuntimeState,
  NativeSearchResult,
  NativeSearchResultKind,
  NativeSendState,
} from 'libhomogrape.so';

export class TelegramFixtureEvents {
  onSeenChatCached?: (seenChat: NativePeer) => void | Promise<void>;
  onChatUpdated?: (seenChat: NativePeer | undefined, chat: NativeChat, messages: NativeMessage[]) => void | Promise<void>;
  onDialogsLoaded?: (dialogs: NativeDialog[], messages: NativeMessage[], source: NativeLoadSource | undefined) => void | Promise<void>;
  onMessagesLoaded?: (chat: NativeChat | undefined, messages: NativeMessage[], source: NativeLoadSource | undefined,
    loadType: NativeMessageLoadType | undefined) => void | Promise<void>;
  onIncomingMessage?: (chat: NativeChat | undefined, message: NativeMessage) => void | Promise<void>;
  onEditedMessage?: (message: NativeMessage) => void | Promise<void>;
  onDeletedMessages?: (deletedMessages: NativeDeletedMessages) => void | Promise<void>;
  onReadState?: (readState: NativeReadState) => void | Promise<void>;
}

export class FixtureRuntimeState implements NativeRuntimeState {
  authorized: boolean;
  running: boolean;
  lastEventSeq: number;

  constructor(authorized: boolean, running: boolean, lastEventSeq: number) {
    this.authorized = authorized;
    this.running = running;
    this.lastEventSeq = lastEventSeq;
  }
}

export class FixturePeer implements NativePeer {
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

  constructor(chatId: number, chatType: ChatType, fullName: string, firstName: string, username: string,
    isContact: boolean = true, forum: boolean = false, lastName: string = '', phone: string = '',
    bio: string = 'Homogram UITest fixture profile', dateOfBirth: number = 0, isMutualContact?: boolean) {
    this.chatId = chatId;
    this.chatType = chatType;
    this.packedChat = 'fixture-peer-' + chatId.toString();
    this.isContact = isContact;
    this.isMutualContact = isMutualContact ?? isContact;
    this.username = username;
    this.fullName = fullName;
    this.firstName = firstName;
    this.lastName = lastName;
    this.phone = phone;
    this.bio = bio;
    this.dateOfBirth = dateOfBirth;
    this.forum = forum;
  }
}

export class FixtureChat implements NativeChat {
  chatId: number;
  chatType: ChatType;
  name: string;
  pinned: boolean;
  unreadCount: number;
  readInboxMaxId: number;
  readOutboxMaxId: number;
  muted: boolean;
  archived: boolean;
  lastMessageId: number;
  lastMessageSenderName: string;
  lastMessageText: string;
  lastMessageTimestamp: number;
  megagroup: boolean;
  forum: boolean;

  constructor(chatId: number, chatType: ChatType, name: string, pinned: boolean, megagroup: boolean, forum: boolean,
    unreadCount: number, topMessage: NativeMessage, muted: boolean = false, archived: boolean = false) {
    this.chatId = chatId;
    this.chatType = chatType;
    this.name = name;
    this.pinned = pinned;
    this.unreadCount = unreadCount;
    this.readInboxMaxId = topMessage.messageId;
    this.readOutboxMaxId = topMessage.messageId;
    this.muted = muted;
    this.archived = archived;
    this.lastMessageId = topMessage.messageId;
    this.lastMessageSenderName = topMessage.senderName;
    this.lastMessageText = topMessage.text;
    this.lastMessageTimestamp = topMessage.timestamp;
    this.megagroup = megagroup;
    this.forum = forum;
  }
}

export class FixtureMessage implements NativeMessage {
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
  deleted: boolean;
  sendState: NativeSendState;

  constructor(chatId: number, messageId: number, outgoing: boolean, senderId: number, senderName: string,
    timestamp: number, text: string, replyToMessageId?: number, fmtEntities?: NativeMessageEntity[],
    pinned: boolean = false, viewCount: number = 0, forwardCount: number = 0, replyCount: number = 0,
    deleted: boolean = false, sendState: NativeSendState = NativeSendState.Sent) {
    this.chatId = chatId;
    this.messageId = messageId;
    this.outgoing = outgoing;
    this.pinned = pinned;
    this.senderId = senderId;
    this.senderName = senderName;
    this.timestamp = timestamp;
    this.text = text;
    this.mediaType = MediaType.None;
    this.deleted = deleted;
    this.sendState = sendState;
    this.replyToMessageId = replyToMessageId;
    this.fmtEntities = fmtEntities;
    this.viewCount = viewCount;
    this.forwardCount = forwardCount;
    this.replyCount = replyCount;
  }
}

export class FixtureEntity implements NativeMessageEntity {
  entityType: MessageEntityType;
  offset: number;
  length: number;
  url?: string;

  constructor(entityType: MessageEntityType, offset: number, length: number, url?: string) {
    this.entityType = entityType;
    this.offset = offset;
    this.length = length;
    this.url = url;
  }
}

export class FixtureDialog implements NativeDialog {
  peer: NativePeer;
  chat: NativeChat;
  topMessage?: NativeMessage;

  constructor(peer: NativePeer, chat: NativeChat) {
    this.peer = peer;
    this.chat = chat;
  }
}

export class FixtureDialogPage implements NativeDialogPage {
  dialogs: NativeDialog[];
  hasMore: boolean;

  constructor(dialogs: NativeDialog[], hasMore: boolean) {
    this.dialogs = dialogs;
    this.hasMore = hasMore;
  }
}

export class FixtureMessagePage implements NativeMessagePage {
  chatId: number;
  messages: NativeMessage[];
  hasMore: boolean;

  constructor(chatId: number, messages: NativeMessage[], hasMore: boolean) {
    this.chatId = chatId;
    this.messages = messages;
    this.hasMore = hasMore;
  }
}

export class FixtureActionResult implements NativeActionResult {
  ok: boolean;
  message: string;

  constructor(message: string, ok: boolean = true) {
    this.ok = ok;
    this.message = message;
  }
}

export class FixtureDeletedMessages implements NativeDeletedMessages {
  chatId?: number;
  messageIds: number[];

  constructor(chatId: number, messageIds: number[]) {
    this.chatId = chatId;
    this.messageIds = messageIds;
  }
}

export class FixtureReadState implements NativeReadState {
  chatId: number;
  maxId: number;
  unreadCount: number;
  inbox: boolean;

  constructor(chatId: number, maxId: number, unreadCount: number, inbox: boolean) {
    this.chatId = chatId;
    this.maxId = maxId;
    this.unreadCount = unreadCount;
    this.inbox = inbox;
  }
}

export class FixtureSearchResult implements NativeSearchResult {
  kind: NativeSearchResultKind;
  chat?: NativeChat;
  peer?: NativePeer;
  seenChat?: NativePeer;
  message?: NativeMessage;

  constructor(kind: NativeSearchResultKind, chat?: NativeChat, peer?: NativePeer, message?: NativeMessage) {
    this.kind = kind;
    this.chat = chat;
    this.peer = peer;
    this.seenChat = peer;
    this.message = message;
  }
}

export class FixtureProfilePhotoPathAndCount implements NativeProfilePhotoPathAndCount {
  dir: string;
  current?: string;
  next: string;
  count: number;

  constructor() {
    this.dir = '';
    this.current = undefined;
    this.next = '';
    this.count = 1;
  }
}

export class FixtureParticipant implements NativeParticipant {
  userId: number;
  fullName: string;
  firstName: string;
  lastName?: string;
  username?: string;
  role: NativeParticipantRole;
  photoThumb?: number[];

  constructor(userId: number, fullName: string, firstName: string, username: string, role: NativeParticipantRole,
    lastName: string = '') {
    this.userId = userId;
    this.fullName = fullName;
    this.firstName = firstName;
    this.username = username;
    this.role = role;
    this.lastName = lastName;
  }
}

export class FixtureParticipantSet {
  chatId: number;
  participants: NativeParticipant[];

  constructor(chatId: number, participants: NativeParticipant[]) {
    this.chatId = chatId;
    this.participants = participants;
  }
}

export class FixtureSeed {
  me: NativePeer;
  peers: NativePeer[];
  chats: NativeChat[];
  messageSets: NativeMessage[][];
  participantSets: FixtureParticipantSet[];
  nextMessageId: number;

  constructor(me: NativePeer, peers: NativePeer[], chats: NativeChat[], messageSets: NativeMessage[][],
    participantSets: FixtureParticipantSet[], nextMessageId: number) {
    this.me = me;
    this.peers = peers;
    this.chats = chats;
    this.messageSets = messageSets;
    this.participantSets = participantSets;
    this.nextMessageId = nextMessageId;
  }
}
