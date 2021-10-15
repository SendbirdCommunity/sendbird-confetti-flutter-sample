import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:sendbird_sdk/sendbird_sdk.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:confetti/confetti.dart';

class GroupChannelView extends StatefulWidget {
  final GroupChannel groupChannel;
  const GroupChannelView({Key? key, required this.groupChannel})
      : super(key: key);

  @override
  _GroupChannelViewState createState() => _GroupChannelViewState();
}

class _GroupChannelViewState extends State<GroupChannelView>
    with ChannelEventHandler {
  List<BaseMessage> _messages = [];
  late ConfettiController _confettiController =
      ConfettiController(duration: const Duration(seconds: 10));
  List<String> _caselessConfettiKeywords = ['congrats', 'congratulations'];
  static String _messageMetaConfettiKey = "shownConfetti";

  @override
  void initState() {
    super.initState();
    getMessages(widget.groupChannel);
    SendbirdSdk().addChannelEventHandler(widget.groupChannel.channelUrl, this);
  }

  @override
  void dispose() {
    SendbirdSdk().removeChannelEventHandler(widget.groupChannel.channelUrl);
    _confettiController.dispose();
    super.dispose();
  }

  @override
  onMessageReceived(channel, message) {
    processForConfetti(message, channel);

    if (mounted == true) {
      setState(() {
        // Add the message to this UI instance
        _messages.add(message);
      });
    }
  }

  Future<void> processForConfetti(
      BaseMessage message, BaseChannel channel) async {
    // See if this incoming message contains any confetti keywords
    if (shouldTriggerConfettiFor(message) == false) {
      return;
    }
    // It is worthy - Play confetti
    _confettiController.play();
    // Let's mark it as having triggered confetti action
    await markConfettiMessageRead(message, channel as GroupChannel,
        SendbirdSdk().currentUser?.userId ?? "");
    // Stop confetti action in near future
    Timer(Duration(seconds: 4), () {
      _confettiController.stop();
    });
  }

  bool shouldTriggerConfettiFor(BaseMessage message) {
    User? sbUser = SendbirdSdk().currentUser;
    if (sbUser == null) {
      print(
          'group_channel_view: shouldTriggerConfettiFor: no current sendbird user. Returning false.');
      return false;
    }
    // Ignore if sender is the current user
    if (message.sender == sbUser) {
      return false;
    }
    // Does message contain target word(s)
    bool containsConfettiKeywords =
        stringContainsOneOf(_caselessConfettiKeywords, message.message);
    if (containsConfettiKeywords == false) {
      return false;
    }
    // If confetti has already been displayed for this message - bail
    if (confettiMessageAlreadyDisplayedFor(message, sbUser.userId)) {
      print(
          'group_channel_view: shouldTriggerConfettiFor: Confetti already displayed to this user. Returning false.');
      return false;
    }
    return true;
  }

  bool confettiMessageAlreadyDisplayedFor(BaseMessage message, String userId) {
    List<MessageMetaArray> arrays =
        message.getMetaArrays([_messageMetaConfettiKey]);
    // Pre-existing meta record not recorded - message has
    if (arrays.isEmpty) {
      print(
          'group_channel_view: confettiMessageAlreadyDisplayedFor: No prior messageMetaArray info found for message: ${message.message}');
      return false;
    }
    MessageMetaArray array = arrays[0];
    if (array.value.contains(userId) == false) {
      print(
          'group_channel_view: confettiMessageAlreadyDisplayedFor: userId $userId not found in $_messageMetaConfettiKey key of messageMetaArray for message: ${message.message}');
      return false;
    }
    return true;
  }

  bool stringContainsOneOf(List<String> keywords, String string,
      {bool caseSensitive = false}) {
    for (String keyword in keywords) {
      // Is keyword in message
      RegExp exp = new RegExp(
        "\\b" + keyword + "\\b",
        caseSensitive: caseSensitive,
      );
      bool match = exp.hasMatch(string);
      // Return true if any of the target keywords are in the given string
      if (match == true) {
        return true;
      }
    }
    return false;
  }

  String stringifiedMetaArray(List<MessageMetaArray>? arrays) {
    if (arrays == null) {
      return "";
    }
    if (arrays.length == 0) {
      return "[]";
    }
    String result = "[\n";
    for (MessageMetaArray array in arrays) {
      result = result + "${array.key} : ${array.value}\n";
    }
    result = result + "]";
    return result;
  }

  Future<void> markConfettiMessageRead(
      BaseMessage message, GroupChannel channel, String userId) async {
    List<MessageMetaArray>? existingArrays = message.metaArrays;
    // No metaArray at all previously exists - create a new one
    if (existingArrays == null) {
      print(
          'group_channel_view: markConfettiMessageRead: No prior messageMetaArray found for message: ${message.message}. Creating a new one...');
      BaseMessage updatedMessage = await channel.addMessageMetaArray(message, [
        MessageMetaArray(key: _messageMetaConfettiKey, value: [userId])
      ]);
      print(
          'group_channel_view: markConfettiMessageRead: messageMetaArray added: ${stringifiedMetaArray(updatedMessage.metaArrays)} to ${message.message}');
      return;
    }
    // metaArrays exist, see if one has a matching confetti key
    for (MessageMetaArray array in existingArrays) {
      // Process any messageMetaArrays with target key
      if (array.key == _messageMetaConfettiKey) {
        List<String> existingList = array.value;
        // Check if userId already in existing list before continuing
        if (existingList.contains(userId) == false) {
          print(
              'group_channel_view: confettiMessageAlreadyDisplayedFor: adding $userId to $_messageMetaConfettiKey messageMetaArray for message: ${message.message}');
          existingList.add(userId);
          // No update API, so we'll remove and add a new messageMetaArray
          // await channel.removeMessageMetaArray(message, [array]);
          await channel.addMessageMetaArray(message, [
            MessageMetaArray(key: _messageMetaConfettiKey, value: [userId])
          ]);
        }
        return;
      }
    }
    // No prior messageMetaArray for confetti tracking found, add it
    await channel.addMessageMetaArray(message, [
      MessageMetaArray(key: _messageMetaConfettiKey, value: [userId])
    ]);
    return;
  }

  Future<void> getMessages(GroupChannel channel) async {
    try {
      List<BaseMessage> messages = await channel.getMessagesByTimestamp(
          DateTime.now().millisecondsSinceEpoch * 1000, MessageListParams());
      // See if any confetti worthy messages were received while we were offline
      for (BaseMessage message in messages) {
        processForConfetti(message, channel);
      }
      if (mounted == true) {
        setState(() {
          _messages = messages;
        });
      }
    } catch (e) {
      print('group_channel_view.dart: getMessages: ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: navigationBar(widget.groupChannel),
      body: body(context),
    );
  }

  PreferredSizeWidget navigationBar(GroupChannel channel) {
    return AppBar(
      automaticallyImplyLeading: true,
      backgroundColor: Colors.white,
      centerTitle: false,
      leading: BackButton(color: Theme.of(context).buttonColor),
      title: Container(
        width: 250,
        child: Text(
          [for (final member in channel.members) member.nickname].join(", "),
          style: TextStyle(
            color: Colors.black,
            fontSize: 18.0,
          ),
        ),
      ),
    );
  }

  Widget body(BuildContext context) {
    User? sbUser = SendbirdSdk().currentUser;
    if (sbUser == null) {
      return Container();
    }
    ChatUser user = asDashChatUser(sbUser);
    return SafeArea(
      // A little breathing room for devices with no home button.
      // padding: const EdgeInsets.fromLTRB(8, 8, 8, 40),
      child: Stack(children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality
                .explosive, // don't specify a direction, blast randomly
            shouldLoop:
                true, // start again as soon as the animation is finished
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple
            ], // manually specify the colors to be used
            // createParticlePath: drawStar, // define a custom shape/path.
          ),
        ),
        DashChat(
          // showUserAvatar: true,
          key: Key(widget.groupChannel.channelUrl),
          onSend: (ChatMessage message) async {
            var sentMessage =
                widget.groupChannel.sendUserMessageWithText(message.text);
            if (mounted == true) {
              setState(() {
                _messages.add(sentMessage);
              });
            }
          },
          // sendOnEnter: true,
          // textInputAction: TextInputAction.send,
          currentUser: user,
          messages: asDashChatMessages(_messages),
          inputOptions: const InputOptions(
            inputDecoration:
                InputDecoration.collapsed(hintText: "Type a message here..."),
          ),
          messageOptions: MessageOptions(
              // dateFormat: DateFormat("E, MMM d"),
              timeFormat: DateFormat.jm(),
              messageDecorationBuilder: (ChatMessage message,
                  ChatMessage? priorMessage, ChatMessage? nextMessage) {
                return BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(20.0)),
                  color: user.id == message.user.id
                      ? Theme.of(context).primaryColor
                      : Colors.grey[200], // example
                );
              }),
        ),
      ]),
    );
  }

  List<ChatMessage> asDashChatMessages(List<BaseMessage> messages) {
    // BaseMessage is a Sendbird class
    // ChatMessage is a DashChat class
    List<ChatMessage> result = [];
    if (messages.isNotEmpty) {
      messages.forEach((message) {
        User? user = message.sender;
        if (user == null) {
          return;
        }
        result.add(
          ChatMessage(
            createdAt: DateTime.fromMillisecondsSinceEpoch(message.createdAt),
            text: message.message,
            user: asDashChatUser(user),
          ),
        );
      });
    }
    return result;
  }

  ChatUser asDashChatUser(User user) {
    return ChatUser(
      id: user.userId,
      firstName: user.nickname,
      // uid: user.userId,
      // avatar: user.profileUrl,
    );
  }
}
