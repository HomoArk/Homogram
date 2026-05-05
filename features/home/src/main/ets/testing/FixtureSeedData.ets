import {
  ChatType,
  MessageEntityType,
  NativeChat,
  NativeMessage,
  NativeMessageEntity,
  NativeParticipant,
  NativeParticipantRole,
  NativePeer,
} from 'libhomogrape.so';
import peerFixtureJson from './fixtures/peers.json';
import messageFixtureJson from './fixtures/messages.json';
import {
  FixtureChat,
  FixtureEntity,
  FixtureMessage,
  FixtureParticipant,
  FixtureParticipantSet,
  FixturePeer,
  FixtureSeed,
} from './FixtureRecords';

interface FixturePeerJson {
  chatId: number;
  chatType: string;
  fullName: string;
  firstName: string;
  lastName?: string;
  username: string;
  isContact?: boolean;
  isMutualContact?: boolean;
  phone?: string;
  bio?: string;
  dateOfBirth?: number;
  forum?: boolean;
  pinned?: boolean;
  muted?: boolean;
  archived?: boolean;
  megagroup?: boolean;
  unreadCount?: number;
}

interface FixtureParticipantJson {
  userId: number;
  fullName: string;
  firstName: string;
  lastName?: string;
  username: string;
  role: string;
}

interface FixtureParticipantSetJson {
  chatId: number;
  members: FixtureParticipantJson[];
}

interface FixturePeersJson {
  me: FixturePeerJson;
  peers: FixturePeerJson[];
  participants: FixtureParticipantSetJson[];
}

interface FixtureMessageThreadJson {
  chatId: number;
  startId: number;
  startTimestamp: number;
  count: number;
  intervalSeconds?: number;
  senderIds: number[];
  seedTexts: string[];
  replyEvery?: number;
  entityEvery?: number;
  pinnedEvery?: number;
  viewBase?: number;
  forwardBase?: number;
}

interface FixtureMessagesJson {
  defaultIntervalSeconds: number;
  threads: FixtureMessageThreadJson[];
}

const PEER_FIXTURE = peerFixtureJson as FixturePeersJson;
const MESSAGE_FIXTURE = messageFixtureJson as FixtureMessagesJson;

export function buildFixtureSeed(): FixtureSeed {
  const me: NativePeer = peerFromJson(PEER_FIXTURE.me);
  const peers: NativePeer[] = [];
  const chats: NativeChat[] = [];
  const messageSets: NativeMessage[][] = [];
  const participantSets: FixtureParticipantSet[] = buildParticipantSets(PEER_FIXTURE.participants);
  let nextMessageId = 1;

  for (let i = 0; i < PEER_FIXTURE.peers.length; i++) {
    const peerJson = PEER_FIXTURE.peers[i];
    const peer = peerFromJson(peerJson);
    const thread = threadForChat(peer.chatId);
    const messages = thread ? buildMessages(thread, me, PEER_FIXTURE.peers, participantSets) :
      [new FixtureMessage(peer.chatId, peer.chatId * 1000, false, peer.chatId, peer.fullName,
        1714800000, 'Fixture chat has no message plan yet.')];

    for (let j = 0; j < messages.length; j++) {
      nextMessageId = Math.max(nextMessageId, messages[j].messageId + 1);
    }

    peers.push(peer);
    messageSets.push(messages);
    chats.push(chatFromJson(peerJson, messages[messages.length - 1]));
  }

  return new FixtureSeed(me, peers, chats, messageSets, participantSets, nextMessageId);
}

function peerFromJson(peerJson: FixturePeerJson): NativePeer {
  return new FixturePeer(
    peerJson.chatId,
    chatTypeFromText(peerJson.chatType),
    peerJson.fullName,
    peerJson.firstName,
    peerJson.username,
    peerJson.isContact ?? true,
    peerJson.forum ?? false,
    peerJson.lastName ?? '',
    peerJson.phone ?? '',
    peerJson.bio ?? 'Homogram UITest fixture profile',
    peerJson.dateOfBirth ?? 0,
    peerJson.isMutualContact,
  );
}

function chatFromJson(peerJson: FixturePeerJson, topMessage: NativeMessage): NativeChat {
  return new FixtureChat(
    peerJson.chatId,
    chatTypeFromText(peerJson.chatType),
    peerJson.fullName,
    peerJson.pinned ?? false,
    peerJson.megagroup ?? false,
    peerJson.forum ?? false,
    peerJson.unreadCount ?? 0,
    topMessage,
    peerJson.muted ?? false,
    peerJson.archived ?? false,
  );
}

function buildParticipantSets(rawSets: FixtureParticipantSetJson[]): FixtureParticipantSet[] {
  const participantSets: FixtureParticipantSet[] = [];
  for (let i = 0; i < rawSets.length; i++) {
    const rawSet = rawSets[i];
    const participants: NativeParticipant[] = [];
    for (let j = 0; j < rawSet.members.length; j++) {
      const member = rawSet.members[j];
      participants.push(new FixtureParticipant(
        member.userId,
        member.fullName,
        member.firstName,
        member.username,
        roleFromText(member.role),
        member.lastName ?? '',
      ));
    }
    participantSets.push(new FixtureParticipantSet(rawSet.chatId, participants));
  }
  return participantSets;
}

function threadForChat(chatId: number): FixtureMessageThreadJson | undefined {
  for (let i = 0; i < MESSAGE_FIXTURE.threads.length; i++) {
    if (MESSAGE_FIXTURE.threads[i].chatId === chatId) {
      return MESSAGE_FIXTURE.threads[i];
    }
  }
  return undefined;
}

function buildMessages(thread: FixtureMessageThreadJson, me: NativePeer, peerSeeds: FixturePeerJson[],
  participantSets: FixtureParticipantSet[]): NativeMessage[] {
  const messages: NativeMessage[] = [];
  const interval = thread.intervalSeconds ?? MESSAGE_FIXTURE.defaultIntervalSeconds;
  const senderIds = thread.senderIds.length > 0 ? thread.senderIds : [thread.chatId];
  const seedTexts = thread.seedTexts.length > 0 ? thread.seedTexts : ['Fixture message'];

  for (let i = 0; i < thread.count; i++) {
    const messageId = thread.startId + i;
    const senderId = senderIds[i % senderIds.length];
    const textSeed = seedTexts[i % seedTexts.length];
    const text = textSeed + ' [' + thread.chatId.toString() + '#' + (i + 1).toString() + ']';
    const replyTo = replyTargetFor(thread, i, messageId);
    const fmtEntities = entitiesFor(thread, i, text);
    messages.push(new FixtureMessage(
      thread.chatId,
      messageId,
      senderId === me.chatId,
      senderId,
      senderNameFor(senderId, me, peerSeeds, participantSets),
      thread.startTimestamp + i * interval,
      text,
      replyTo,
      fmtEntities,
      isPinnedMessage(thread, i),
      viewCountFor(thread, i),
      forwardCountFor(thread, i),
      replyTo ? 1 : 0,
    ));
  }

  return messages;
}

function replyTargetFor(thread: FixtureMessageThreadJson, index: number, messageId: number): number | undefined {
  const replyEvery = thread.replyEvery ?? 0;
  if (replyEvery <= 0 || index === 0 || (index + 1) % replyEvery !== 0) {
    return undefined;
  }
  return messageId - 1;
}

function entitiesFor(thread: FixtureMessageThreadJson, index: number, text: string): NativeMessageEntity[] | undefined {
  const entityEvery = thread.entityEvery ?? 0;
  if (entityEvery <= 0 || (index + 1) % entityEvery !== 0) {
    return undefined;
  }
  const length = Math.min(8, text.length);
  return [new FixtureEntity(MessageEntityType.Bold, 0, length)];
}

function isPinnedMessage(thread: FixtureMessageThreadJson, index: number): boolean {
  const pinnedEvery = thread.pinnedEvery ?? 0;
  return pinnedEvery > 0 && (index + 1) % pinnedEvery === 0;
}

function viewCountFor(thread: FixtureMessageThreadJson, index: number): number {
  const viewBase = thread.viewBase ?? 0;
  if (viewBase <= 0) {
    return 0;
  }
  return viewBase + index * 3;
}

function forwardCountFor(thread: FixtureMessageThreadJson, index: number): number {
  const forwardBase = thread.forwardBase ?? 0;
  if (forwardBase <= 0) {
    return 0;
  }
  return forwardBase + Math.floor(index / 3);
}

function senderNameFor(senderId: number, me: NativePeer, peerSeeds: FixturePeerJson[],
  participantSets: FixtureParticipantSet[]): string {
  if (senderId === me.chatId) {
    return me.fullName;
  }
  for (let i = 0; i < peerSeeds.length; i++) {
    if (peerSeeds[i].chatId === senderId) {
      return peerSeeds[i].fullName;
    }
  }
  for (let i = 0; i < participantSets.length; i++) {
    const participants = participantSets[i].participants;
    for (let j = 0; j < participants.length; j++) {
      if (participants[j].userId === senderId) {
        return participants[j].fullName;
      }
    }
  }
  return 'Fixture Sender';
}

function chatTypeFromText(chatType: string): ChatType {
  switch (chatType) {
    case 'channel':
      return ChatType.Channel;
    case 'group':
      return ChatType.Group;
    case 'user':
    default:
      return ChatType.User;
  }
}

function roleFromText(role: string): NativeParticipantRole {
  switch (role) {
    case 'creator':
      return NativeParticipantRole.Creator;
    case 'admin':
      return NativeParticipantRole.Admin;
    case 'user':
    default:
      return NativeParticipantRole.User;
  }
}
