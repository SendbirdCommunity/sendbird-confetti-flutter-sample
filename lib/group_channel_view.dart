import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:sendbird_sdk/sendbird_sdk.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'sendbird_sfx_controller.dart';
import 'confetti_sfx.dart';

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
  final _sfxController = SendbirdSFXController([
    ConfettiSFX(
        metaKey: "shownConfetti",
        caselessKeywords: ["congrats", "congratulations"],
        debugCallback: (message) {
          print(message);
        })
  ]);

  @override
  void initState() {
    super.initState();
    getMessages(widget.groupChannel);
    SendbirdSdk().addChannelEventHandler(widget.groupChannel.channelUrl, this);
  }

  @override
  void dispose() {
    SendbirdSdk().removeChannelEventHandler(widget.groupChannel.channelUrl);
    _sfxController.dispose();
    super.dispose();
  }

  @override
  onMessageReceived(channel, message) {
    // For simplicity, just going to call Sendbird for all messages
    // so that we're sure we also get any metaArray data associated with it
    // rather than also checking the onMessageUpdated callback.
    getMessages(channel as GroupChannel);
  }

  Future<void> getMessages(GroupChannel channel) async {
    try {
      List<BaseMessage> messages = await channel.getMessagesByTimestamp(
          DateTime.now().millisecondsSinceEpoch * 1000,
          MessageListParams()
            ..includeMetaArray = true
            ..reverse = true);
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
      leading: BackButton(color: Theme.of(context).primaryColor),
      title: SizedBox(
        width: 250,
        child: Text(
          [for (final member in channel.members) member.nickname].join(", "),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18.0,
          ),
        ),
      ),
    );
  }

  Widget body(BuildContext context) {
    // If there is no current Sendbird user, we won't have
    // anything to display
    User? sbUser = SendbirdSdk().currentUser;
    if (sbUser == null) {
      return Container();
    }
    ChatUser user = asDashChatUser(sbUser);

    // Run all received messages through special effects check
    _sfxController.checkAndTriggerAll(widget.groupChannel, _messages);

    // Creating a list of widgets to feed into a Stack widget later
    List<Widget> stackUIs = [
      for (SendbirdSFX sfx in _sfxController.specialEffects) sfx.ui()
    ];

    // Add the Dashchat widget underneath all the effects, this is our
    // always present base UI Layer
    stackUIs.add(DashChat(
      key: Key(widget.groupChannel.channelUrl),
      onSend: (ChatMessage message) async {
        widget.groupChannel.sendUserMessageWithText(message.text);
        if (mounted == true) {
          getMessages(widget.groupChannel);
        }
      },
      currentUser: user,
      messages: asDashChatMessages(_messages),
      inputOptions: const InputOptions(
        inputDecoration:
            InputDecoration.collapsed(hintText: "Type a message here..."),
      ),
      messageOptions: MessageOptions(
          showCurrentUserAvatar: true,
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
    ));

    // A little breathing room for devices with no home button.
    return SafeArea(
      // Add our stack of UIs here
      child: Stack(
        children: stackUIs,
      ),
    );
  }

  // Converts a list of Sendbird messages to DashChat messages
  List<ChatMessage> asDashChatMessages(List<BaseMessage> messages) {
    List<ChatMessage> result = [];
    if (messages.isNotEmpty) {
      for (var message in messages) {
        User? user = message.sender;
        if (user == null) {
          continue;
        }
        result.add(
          ChatMessage(
            createdAt: DateTime.fromMillisecondsSinceEpoch(message.createdAt),
            text: message.message,
            user: asDashChatUser(user),
          ),
        );
      }
    }
    return result;
  }

  // Converts a Sendbird User to a DashChat user
  ChatUser asDashChatUser(User user) {
    return ChatUser(
      id: user.userId,
      firstName: user.nickname,
      profileImage: user.profileUrl ?? "",
    );
  }
}
