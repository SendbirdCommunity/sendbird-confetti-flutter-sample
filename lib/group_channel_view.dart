import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:sendbird_sdk/sendbird_sdk.dart';
import 'dart:async';
import 'package:intl/intl.dart';

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
  @override
  void initState() {
    super.initState();
    getMessages(widget.groupChannel);
    SendbirdSdk().addChannelEventHandler(widget.groupChannel.channelUrl, this);
  }

  @override
  void dispose() {
    SendbirdSdk().removeChannelEventHandler(widget.groupChannel.channelUrl);
    super.dispose();
  }

  @override
  onMessageReceived(channel, message) {
    setState(() {
      _messages.add(message);
    });
  }

  Future<void> getMessages(GroupChannel channel) async {
    try {
      List<BaseMessage> messages = await channel.getMessagesByTimestamp(
          DateTime.now().millisecondsSinceEpoch * 1000, MessageListParams());
      setState(() {
        _messages = messages;
      });
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
    return Padding(
      // A little breathing room for devices with no home button.
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 40),
      child: DashChat(
        // showUserAvatar: true,
        key: Key(widget.groupChannel.channelUrl),
        onSend: (ChatMessage message) async {
          var sentMessage =
              widget.groupChannel.sendUserMessageWithText(message.text);
          setState(() {
            _messages.add(sentMessage);
          });
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
